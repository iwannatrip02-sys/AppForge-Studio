import Foundation
import simd
import OCCTSwift
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "AssemblyMates")

// MARK: - Tipos de Mate

enum AssemblyMateType: String, CaseIterable, Codable {
    case coincident       // Dos caras coinciden
    case concentric       // Dos ejes cilíndricos alineados
    case parallel         // Dos caras paralelas (offset opcional)
    case perpendicular    // Dos caras perpendiculares
    case distance         // Distancia fija entre caras/puntos
    case angle            // Ángulo fijo entre caras
    case tangent          // Cara tangente a cilindro/esfera
    case lock             // Bloqueo total (0 DOF relativos)

    var icon: String {
        switch self {
        case .coincident: "equal.square"; case .concentric: "circle.circle"
        case .parallel: "square.split.2x1"; case .perpendicular: "square.split.diagonal.2x2"
        case .distance: "arrow.left.and.right"; case .angle: "angle"
        case .tangent: "circle.dotted.circle"; case .lock: "lock"
        }
    }
    var constrainedDOFs: Int {
        switch self {
        case .coincident: 3; case .concentric: 4; case .parallel: 1
        case .perpendicular: 1; case .distance: 1; case .angle: 1
        case .tangent: 1; case .lock: 6
        }
    }
}

// MARK: - Entidad de referencia

enum MateEntity {
    case face(modelIndex: Int, faceIndex: Int)
    case edge(modelIndex: Int, edgeIndex: Int)
    case point(modelIndex: Int, position: SIMD3<Float>)
    var modelIndex: Int {
        switch self {
        case .face(let m, _), .edge(let m, _), .point(let m, _): return m
        }
    }
}

// MARK: - Mate

struct AssemblyMate: Identifiable {
    let id: UUID
    var type: AssemblyMateType
    var entityA: MateEntity
    var entityB: MateEntity
    var value: Double = 0
    var name: String
    var isActive: Bool = true

    init(id: UUID = UUID(), type: AssemblyMateType,
         entityA: MateEntity, entityB: MateEntity,
         value: Double = 0, name: String? = nil) {
        self.id = id; self.type = type
        self.entityA = entityA; self.entityB = entityB
        self.value = value; self.name = name ?? type.rawValue
    }
}

// MARK: - Solver de Mates

/// Resuelve restricciones de ensamblaje posicionando cuerpos para satisfacer mates.
/// Secuencial iterativo: cada mate empuja bodyB hacia la posición que satisface la restricción.
@MainActor
final class AssemblyMatesEngine: ObservableObject {
    @Published var mates: [AssemblyMate] = []
    @Published var isSolving: Bool = false
    @Published var solverStatus: String = ""

    private let maxIterations = 20
    private let tolerance: Float = 1e-5

    func addMate(_ mate: AssemblyMate) { mates.append(mate) }
    func removeMate(id: UUID) { mates.removeAll { $0.id == id } }
    func toggleMate(id: UUID) {
        guard let idx = mates.firstIndex(where: { $0.id == id }) else { return }
        mates[idx].isActive.toggle()
    }
    func clearAll() { mates.removeAll(); solverStatus = "" }

    @discardableResult
    func solve(models: inout [Model]) -> Bool {
        isSolving = true; defer { isSolving = false }
        let activeMates = mates.filter { $0.isActive }
        guard !activeMates.isEmpty else { solverStatus = "Sin restricciones"; return true }

        for mate in activeMates {
            guard mate.entityA.modelIndex < models.count,
                  mate.entityB.modelIndex < models.count else {
                solverStatus = "Índice inválido"; return false
            }
        }

        for iteration in 0..<maxIterations {
            var maxResidual: Float = 0
            for mate in activeMates {
                guard models[mate.entityA.modelIndex].cadShape != nil,
                      models[mate.entityB.modelIndex].cadShape != nil else { continue }
                let residual = applyMate(mate, models: &models)
                maxResidual = max(maxResidual, residual)
            }
            if maxResidual < tolerance {
                solverStatus = "Convergió en \(iteration + 1) iteraciones"
                return true
            }
        }
        solverStatus = "No convergió — posible sobre-restricción"
        return false
    }

    private func applyMate(_ mate: AssemblyMate, models: inout [Model]) -> Float {
        guard let shapeA = models[mate.entityA.modelIndex].cadShape,
              let shapeB = models[mate.entityB.modelIndex].cadShape else { return 1e6 }

        let centerA = shapeA.center; let centerB = shapeB.center

        switch mate.type {
        case .coincident:
            let delta = centerA - centerB
            let dF = SIMD3<Float>(Float(delta.x), Float(delta.y), Float(delta.z))
            if simd_length(dF) > tolerance { models[mate.entityB.modelIndex].position += dF }
            return simd_length(dF)
        case .concentric:
            let delta = SIMD3<Float>(Float(centerA.x - centerB.x), Float(centerA.y - centerB.y), 0)
            if simd_length(delta) > tolerance { models[mate.entityB.modelIndex].position += delta }
            return simd_length(delta)
        case .parallel:
            let offset = SIMD3<Double>(0, 0, mate.value)
            let target = centerA + offset; let delta = target - centerB
            let dF = SIMD3<Float>(Float(delta.x), Float(delta.y), Float(delta.z))
            if simd_length(dF) > tolerance { models[mate.entityB.modelIndex].position += dF }
            return simd_length(dF)
        case .distance:
            let dir = simd_normalize(centerB - centerA)
            let target = centerA + dir * mate.value; let delta = target - centerB
            let dF = SIMD3<Float>(Float(delta.x), Float(delta.y), Float(delta.z))
            if simd_length(dF) > tolerance { models[mate.entityB.modelIndex].position += dF }
            return abs(simd_distance(centerA, centerB) - mate.value)
        case .perpendicular:
            let q = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 1, 0))
            models[mate.entityB.modelIndex].rotation = simd_mul(q, models[mate.entityB.modelIndex].rotation)
            return 0
        case .angle:
            let diff = Float(mate.value) - models[mate.entityB.modelIndex].rotation.angle
            if abs(diff) > tolerance {
                let q = simd_quatf(angle: diff, axis: SIMD3<Float>(0, 1, 0))
                models[mate.entityB.modelIndex].rotation = simd_mul(q, models[mate.entityB.modelIndex].rotation)
            }
            return abs(diff)
        case .tangent:
            let sizeA = shapeA.size; let sizeB = shapeB.size
            let rA = (sizeA.x + sizeA.y) / 4; let rB = (sizeB.x + sizeB.y) / 4
            let tanDist = rA + rB + mate.value
            let dir = simd_normalize(centerB - centerA)
            let target = centerA + dir * tanDist; let delta = target - centerB
            let dF = SIMD3<Float>(Float(delta.x), Float(delta.y), Float(delta.z))
            if simd_length(dF) > tolerance { models[mate.entityB.modelIndex].position += dF }
            return abs(simd_distance(centerA, centerB) - tanDist)
        case .lock: return 0
        }
    }

    var uniqueBodyCount: Int {
        var bodies = Set<Int>()
        for mate in mates {
            bodies.insert(mate.entityA.modelIndex)
            bodies.insert(mate.entityB.modelIndex)
        }
        return max(bodies.count, 1)
    }

    func matesInvolving(modelIndex: Int) -> [AssemblyMate] {
        mates.filter { $0.entityA.modelIndex == modelIndex || $0.entityB.modelIndex == modelIndex }
    }
}
