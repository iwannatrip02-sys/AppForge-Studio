import Foundation
import simd

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
}

// MARK: - Geometry Constraint Manager

class GeometryConstraintManager: ObservableObject {
    @Published var constraints: [GeometryConstraint] = []
    @Published var isSolving: Bool = false
    @Published var lastSolveDuration: TimeInterval = 0
    
    // Closures para que Scene3D/CanvasViewModel inyecten acceso a posiciones de entidades 3D
    var entityPositionProvider: ((UUID) -> SIMD3<Float>?)?
    var entityPositionUpdater: ((UUID, SIMD3<Float>) -> Void)?
    
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
    }
    
    var constraintCount: Int { constraints.count }
    var activeConstraintCount: Int { constraints.filter { $0.isActive }.count }
    
    // MARK: - Constraint Solving Engine
    
    func resolveConstraints() {
        isSolving = true
        let start = CFAbsoluteTimeGetCurrent()
        for constraint in constraints where constraint.isActive {
            guard let provider = entityPositionProvider,
                  let updater = entityPositionUpdater else { continue }
            applyConstraint(constraint, provider: provider, updater: updater)
        }
        lastSolveDuration = CFAbsoluteTimeGetCurrent() - start
        isSolving = false
    }
    
    private func applyConstraint(_ constraint: GeometryConstraint, provider: (UUID) -> SIMD3<Float>?, updater: (UUID, SIMD3<Float>) -> Void) {
        guard constraint.entityIDs.count >= 2 else { return }
        let positions = constraint.entityIDs.compactMap { provider($0) }
        guard positions.count >= 2 else { return }
        switch constraint.type {
        case .horizontal:
            if let id = constraint.entityIDs.first, var pos = provider(id) {
                pos.y = 0
                updater(id, pos)
            }
        case .vertical:
            if let id = constraint.entityIDs.first, var pos = provider(id) {
                pos.x = 0
                updater(id, pos)
            }
        case .tangent, .concentric:
            if constraint.entityIDs.count >= 2 {
                let center = positions[0]
                for i in 1..<constraint.entityIDs.count {
                    updater(constraint.entityIDs[i], center)
                }
            }
        case .collinear:
            if constraint.entityIDs.count >= 2 {
                let avg = positions.reduce(SIMD3<Float>(0,0,0), +) / Float(positions.count)
                for id in constraint.entityIDs { updater(id, avg) }
            }
        default:
            break
        }
    }

    // MARK: - Solver Helpers
    
    private func applyHorizontal(_ constraint: GeometryConstraint) {
        guard constraint.entityIDs.count == 1,
              let pos = entityPositionProvider?(constraint.entityIDs[0]) else { return }
        // Proyectar a Y=0 (plano XZ horizontal)
        let newPos = SIMD3<Float>(pos.x, 0, pos.z)
        entityPositionUpdater?(constraint.entityIDs[0], newPos)
    }
    
    private func applyVertical(_ constraint: GeometryConstraint) {
        guard constraint.entityIDs.count == 1,
              let pos = entityPositionProvider?(constraint.entityIDs[0]) else { return }
        // Proyectar a X=0, Z=0 (eje Y vertical)
        let newPos = SIMD3<Float>(0, pos.y, 0)
        entityPositionUpdater?(constraint.entityIDs[0], newPos)
    }
    
    private func applyDistance(_ constraint: GeometryConstraint) {
        guard constraint.entityIDs.count == 2,
              let pos1 = entityPositionProvider?(constraint.entityIDs[0]),
              let pos2 = entityPositionProvider?(constraint.entityIDs[1]),
              let targetDist = constraint.value else { return }
        let direction = normalize(pos2 - pos1)
        let newPos2 = pos1 + direction * targetDist
        entityPositionUpdater?(constraint.entityIDs[1], newPos2)
    }
    
    private func applyAngle(_ constraint: GeometryConstraint) {
        // Stub: No implementado aun
    }
    
    private func applyEqual(_ constraint: GeometryConstraint) {
        guard constraint.entityIDs.count == 2,
              let pos1 = entityPositionProvider?(constraint.entityIDs[0]),
              let _ = entityPositionProvider?(constraint.entityIDs[1]) else { return }
        // Igualar posiciones (copiar pos1 a pos2)
        entityPositionUpdater?(constraint.entityIDs[1], pos1)
    }
    
    private func applyMidpoint(_ constraint: GeometryConstraint) {
        guard constraint.entityIDs.count == 3,
              let pos1 = entityPositionProvider?(constraint.entityIDs[0]),
              let pos2 = entityPositionProvider?(constraint.entityIDs[1]) else { return }
        let midpoint = (pos1 + pos2) * 0.5
        entityPositionUpdater?(constraint.entityIDs[2], midpoint)
    }
}

import QuartzCore // for CACurrentMediaTime