import Foundation
import simd
import QuartzCore
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "GeometryConstraintManager")

// MARK: - Solver Metrics

struct SolverMetrics {
    var iterationCount: Int
    var residual: Float
    var duration: TimeInterval
    var converged: Bool

    static let empty = SolverMetrics(iterationCount: 0, residual: 0, duration: 0, converged: false)
}

// MARK: - Tipo de constraint geometrico

enum ConstraintType: String, Codable, CaseIterable {
    case horizontal = "Horizontal"
    case vertical = "Vertical"
    case perpendicular = "Perpendicular"
    case tangent = "Tangente"
    case concentric = "Concentrico"
    case equal = "Igual"
    case distance = "Distancia"
    case angle = "Angulo"
    case midpoint = "Punto Medio"
    case collinear = "Colineal"
}

// MARK: - Entidad de constraint

struct GeometryConstraint: Identifiable, Codable {
    let id: UUID
    var type: ConstraintType
    var entityIDs: [UUID]
    var value: Float?
    var isActive: Bool
    var label: String

    init(id: UUID = UUID(), type: ConstraintType, entityIDs: [UUID],
         value: Float? = nil, isActive: Bool = true, label: String = "") {
        self.id = id
        self.type = type
        self.entityIDs = entityIDs
        self.value = value
        self.isActive = isActive
        self.label = label.isEmpty ? type.rawValue : label
    }

    var requiredEntityCount: Int {
        switch type {
        case .horizontal, .vertical: return 1
        case .distance, .equal, .concentric, .tangent: return 2
        case .midpoint, .collinear: return 3
        case .angle: return 3
        case .perpendicular: return 4
        }
    }

    var isValid: Bool {
        entityIDs.count >= requiredEntityCount
            && (type != .distance || value != nil)
            && (type != .angle || value != nil)
    }
}

// MARK: - Geometry Constraint Manager

class GeometryConstraintManager: ObservableObject {
    @Published var constraints: [GeometryConstraint] = []
    @Published var isSolving: Bool = false
    @Published var lastSolve: SolverMetrics = .empty
    @Published var lastSolveDuration: TimeInterval = 0

    // Closures para que Scene3D/CanvasViewModel inyecten acceso a posiciones de entidades 3D
    var entityPositionProvider: ((UUID) -> SIMD3<Float>?)?
    var entityPositionUpdater: ((UUID, SIMD3<Float>) -> Void)?

    // 2D Solver (from Sources/CADCore)
    private var solver = SolverSwift()

    func addConstraint(_ constraint: GeometryConstraint) {
        constraints.append(constraint)
    }

    func removeConstraint(at id: UUID) {
        constraints.removeAll { $0.id == id }
    }

    func removeConstraint(at index: Int) {
        guard index >= 0, index < constraints.count else { return }
        constraints.remove(at: index)
    }

    func updateConstraint(_ constraint: GeometryConstraint) {
        guard let idx = constraints.firstIndex(where: { $0.id == constraint.id }) else { return }
        constraints[idx] = constraint
    }

    func toggleConstraint(_ id: UUID) {
        guard let idx = constraints.firstIndex(where: { $0.id == id }) else { return }
        constraints[idx].isActive.toggle()
    }

    func clearAll() {
        constraints.removeAll()
        solver.clear()
    }

    var constraintCount: Int { constraints.count }
    var activeConstraintCount: Int { constraints.filter { $0.isActive }.count }

    func getActiveConstraints() -> [GeometryConstraint] {
        return constraints.filter { $0.isActive }
    }

    // MARK: - 3D Constraint Solving Engine (delegado a SolverSwift)

    /// Resuelve constraints 3D usando el solver Newton-Raphson unificado.
    /// Proyecta puntos 3D → 2D, resuelve con SolverSwift, restaura a 3D.
    func resolveConstraints() {
        isSolving = true
        let start = CFAbsoluteTimeGetCurrent()

        guard let provider = entityPositionProvider else {
            isSolving = false
            return
        }

        solver.clear()
        // Guardar z original para restaurar tras solve 2D
        var originalZ: [UUID: Float] = [:]

        for constraint in constraints where constraint.isActive {
            for eid in constraint.entityIDs {
                guard let pos = provider(eid) else { continue }
                originalZ[eid] = pos.z
                let sp = SolverPoint(id: eid,
                                     x: Double(pos.x), y: Double(pos.y),
                                     isFixed: false)
                solver.addPoint(sp)
            }

            if let sc = bridgeToSolverConstraint(constraint) {
                solver.addConstraint(sc)
            }
        }

        let result = solver.solve()
        if result.converged, let updater = entityPositionUpdater {
            for sp in result.points {
                let z = originalZ[sp.id] ?? 0
                updater(sp.id, SIMD3<Float>(Float(sp.x), Float(sp.y), z))
            }
        }

        lastSolveDuration = CFAbsoluteTimeGetCurrent() - start
        isSolving = false
    }

    /// Puente GeometryConstraint → SolverConstraint (reusa lógica de SketchController).
    private func bridgeToSolverConstraint(_ gc: GeometryConstraint) -> SolverConstraint? {
        let ids = gc.entityIDs
        switch gc.type {
        case .horizontal:
            guard let id = ids.first else { return nil }
            return SolverConstraint(id: gc.id, type: .horizontal(pointID: id), weight: 1.0)
        case .vertical:
            guard let id = ids.first else { return nil }
            return SolverConstraint(id: gc.id, type: .vertical(pointID: id), weight: 1.0)
        case .distance:
            guard ids.count >= 2 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .distance(pointA: ids[0], pointB: ids[1], value: Double(gc.value ?? 10)),
                weight: 1.0)
        case .perpendicular:
            guard ids.count >= 4 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .perpendicular(lineAStart: ids[0], lineAEnd: ids[1],
                                    lineBStart: ids[2], lineBEnd: ids[3]), weight: 1.0)
        case .equal:
            guard ids.count >= 4 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .equal(pointA: ids[0], pointB: ids[1], pointC: ids[2], pointD: ids[3]),
                weight: 1.0)
        case .angle:
            guard ids.count >= 3 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .angle(pointA: ids[0], pointB: ids[1], pointC: ids[2],
                            value: Double(gc.value ?? 45)), weight: 1.0)
        case .midpoint:
            guard ids.count >= 3 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .midpoint(pointA: ids[0], pointB: ids[1], pointMid: ids[2]), weight: 1.0)
        case .collinear:
            guard ids.count >= 3 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .collinear(pointA: ids[0], pointB: ids[1], pointC: ids[2]), weight: 1.0)
        case .tangent:
            guard ids.count >= 2 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .tangent(center: ids[0], point: ids[1], radius: Double(gc.value ?? 1)),
                weight: 1.0)
        case .concentric:
            guard ids.count >= 2 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .coincident(pointA: ids[0], pointB: ids[1]), weight: 1.0)
        }
    }

    // MARK: - 2D Sketch Constraint Solving (from Sources/CADCore)

    func resolveConstraints(with points: inout [SketchPoint]) -> SolverMetrics {
        let startTime = CACurrentMediaTime()
        guard !constraints.isEmpty else {
            return SolverMetrics(iterationCount: 0, residual: 0, duration: 0, converged: true)
        }

        solver.clear()

        for (i, pt) in points.enumerated() {
            let p = SolverPoint(id: pt.id, x: Double(pt.position.x), y: Double(pt.position.y), isFixed: i < 2)
            solver.addPoint(p)
        }

        for c in constraints where c.isActive {
            guard c.entityIDs.count >= c.requiredEntityCount else { continue }
            let ids = c.entityIDs
            let type: SolverConstraintType
            switch c.type {
            case .horizontal:
                type = .horizontal(pointID: ids[0])
            case .vertical:
                type = .vertical(pointID: ids[0])
            case .concentric:
                type = .coincident(pointA: ids[0], pointB: ids[1])
            case .distance:
                type = .distance(pointA: ids[0], pointB: ids[1], value: Double(c.value ?? 10.0))
            case .equal:
                guard ids.count >= 4 else { continue }
                type = .equal(pointA: ids[0], pointB: ids[1], pointC: ids[2], pointD: ids[3])
            case .perpendicular:
                guard ids.count >= 4 else { continue }
                type = .perpendicular(lineAStart: ids[0], lineAEnd: ids[1], lineBStart: ids[2], lineBEnd: ids[3])
            case .angle:
                guard ids.count >= 3 else { continue }
                type = .angle(pointA: ids[0], pointB: ids[1], pointC: ids[2], value: Double(c.value ?? 45.0))
            case .midpoint:
                guard ids.count >= 3 else { continue }
                type = .midpoint(pointA: ids[0], pointB: ids[1], pointMid: ids[2])
            case .collinear:
                guard ids.count >= 3 else { continue }
                type = .collinear(pointA: ids[0], pointB: ids[1], pointC: ids[2])
            case .tangent:
                let radius = c.value != nil ? Double(c.value!) : 1.0
                type = .tangent(center: ids[0], point: ids[1], radius: radius)
            }
            let sc = SolverConstraint(id: c.id, type: type, weight: 1.0)
            solver.addConstraint(sc)
        }

        let result = solver.solve()

        if result.converged {
            for p in result.points {
                if let idx = points.firstIndex(where: { $0.id == p.id }) {
                    points[idx].position.x = Float(p.x)
                    points[idx].position.y = Float(p.y)
                }
            }
        }

        let duration = CACurrentMediaTime() - startTime
        let error = result.converged ? 1e-7 : result.residual

        let metrics = SolverMetrics(
            iterationCount: result.iterations,
            residual: Float(error),
            duration: duration,
            converged: result.converged
        )
        lastSolve = metrics
        return metrics
    }

    func clear() {
        constraints.removeAll()
        solver.clear()
    }
}
