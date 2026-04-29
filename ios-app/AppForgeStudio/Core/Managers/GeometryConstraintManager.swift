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
}
