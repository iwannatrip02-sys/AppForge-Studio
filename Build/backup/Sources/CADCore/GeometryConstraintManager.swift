import Foundation
import simd
import QuartzCore
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "GeometryConstraintManager")

enum ConstraintType: String, Codable, CaseIterable {
    case horizontal, vertical, perpendicular, tangent, concentric
    case equal, distance, angle, midpoint, collinear
}

struct SolverMetrics {
    var iterationCount: Int
    var residual: Float
    var duration: TimeInterval
    var converged: Bool
    
    static let empty = SolverMetrics(iterationCount: 0, residual: 0, duration: 0, converged: false)
}

struct GeometryConstraint: Identifiable, Codable {
    let id: UUID
    var type: ConstraintType
    var entityIDs: [UUID]
    var value: Float?
    var isActive: Bool
    var label: String
    
    init(id: UUID = UUID(), type: ConstraintType, entityIDs: [UUID], value: Float? = nil, isActive: Bool = true, label: String = "") {
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

class GeometryConstraintManager {
    private var solver = SolverSwift()
    private(set) var constraints: [GeometryConstraint] = []
    
    func addConstraint(_ constraint: GeometryConstraint) {
        constraints.append(constraint)
    }
    
    func removeConstraint(at index: Int) {
        guard index < constraints.count else { return }
        constraints.remove(at: index)
    }
    
    func removeConstraint(id: UUID) {
        constraints.removeAll { $0.id == id }
    }
    
    func resolveConstraints(with points: inout [SketchPoint]) -> SolverMetrics {
        let startTime = CACurrentMediaTime()
        guard !constraints.isEmpty else {
            return SolverMetrics(iterationCount: 0, residual: 0, duration: 0, converged: true)
        }
        
        solver.clear()
        
        // Traducir SketchPoint a SolverPoint. Fijar primeros 2 como ancla.
        for (i, pt) in points.enumerated() {
            let p = SolverPoint(id: pt.id, x: Double(pt.position.x), y: Double(pt.position.y), isFixed: i < 2)
            solver.addPoint(p)
        }
        
        // Traducir GeometryConstraint a SolverConstraint
        for c in constraints where c.isActive {
            guard c.entityIDs.count >= c.requiredEntityCount else { continue }
            let ids = c.entityIDs
            let type: SolverConstraintType
            switch c.type {
            case .horizontal:
                type = .horizontal(pointID: ids[0])
            case .vertical:
                type = .vertical(pointID: ids[0])
            case .coincident:
                type = .coincident(pointA: ids[0], pointB: ids[1])
            case .distance:
                type = .distance(pointA: ids[0], pointB: ids[1], value: Double(c.value ?? 10.0))
            case .concentric:
                type = .concentric(circleCenterA: ids[0], circleCenterB: ids[1])
            case .equal:
                guard ids.count >= 4 else { continue }
                type = .equal(pointA: ids[0], pointB: ids[1], pointC: ids[2], pointD: ids[3])
            case .parallel:
                guard ids.count >= 4 else { continue }
                type = .parallel(lineAStart: ids[0], lineAEnd: ids[1], lineBStart: ids[2], lineBEnd: ids[3])
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
                type = .coincident(pointA: ids[0], pointB: ids[1])
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
        
        return SolverMetrics(
            iterationCount: result.iterations,
            residual: Float(error),
            duration: duration,
            converged: result.converged
        )
    }
    
    func clear() {
        constraints.removeAll()
        solver.clear()
    }
}
