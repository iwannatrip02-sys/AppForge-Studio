import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "AssemblyEngine")

struct AssemblyNode: Identifiable {
    let id: UUID
    var name: String
    var modelIDs: [UUID]
    var children: [AssemblyNode]
    var position: SIMD3<Float>
    var rotation: simd_quatf
    var scale: SIMD3<Float>

    init(id: UUID = UUID(), name: String, modelIDs: [UUID] = [],
         children: [AssemblyNode] = [],
         position: SIMD3<Float> = .zero,
         rotation: simd_quatf = simd_quaternion(0, SIMD3<Float>(0, 0, 1)),
         scale: SIMD3<Float> = SIMD3<Float>(1, 1, 1)) {
        self.id = id
        self.name = name
        self.modelIDs = modelIDs
        self.children = children
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }

    var localTransform: simd_float4x4 {
        let T = simd_float4x4(columns: (
            SIMD4<Float>(scale.x, 0, 0, 0),
            SIMD4<Float>(0, scale.y, 0, 0),
            SIMD4<Float>(0, 0, scale.z, 0),
            SIMD4<Float>(position.x, position.y, position.z, 1)
        ))
        let R = simd_float4x4(rotation)
        return simd_mul(T, R)
    }

    func worldTransform(parentTransform: simd_float4x4 = matrix_identity_float4x4, visited: inout Set<UUID>) -> simd_float4x4? {
        guard !visited.contains(id) else { return nil }
        visited.insert(id)
        return simd_mul(parentTransform, localTransform)
    }

    func worldTransform(parentTransform: simd_float4x4 = matrix_identity_float4x4) -> simd_float4x4 {
        var visited = Set<UUID>()
        return worldTransform(parentTransform: parentTransform, visited: &visited) ?? matrix_identity_float4x4
    }

    func allModelIDs(visited: inout Set<UUID>) -> [UUID] {
        guard !visited.contains(id) else { return [] }
        visited.insert(id)
        var ids = modelIDs
        for child in children {
            ids.append(contentsOf: child.allModelIDs(visited: &visited))
        }
        return ids
    }

    func allModelIDs() -> [UUID] {
        var visited = Set<UUID>()
        return allModelIDs(visited: &visited)
    }

    func allNodeIDs(visited: inout Set<UUID>) -> [UUID] {
        guard !visited.contains(id) else { return [] }
        visited.insert(id)
        var ids = [id]
        for child in children {
            ids.append(contentsOf: child.allNodeIDs(visited: &visited))
        }
        return ids
    }

    func allNodeIDs() -> [UUID] {
        var visited = Set<UUID>()
        return allNodeIDs(visited: &visited)
    }

    mutating func addChild(_ child: AssemblyNode) {
        children.append(child)
    }

    mutating func removeChild(_ childID: UUID) {
        children.removeAll { $0.id == childID }
    }
}

class AssemblyEngine: ObservableObject {
    @Published var assemblies: [AssemblyNode] = []
    @Published var selectedAssemblyID: UUID?

    func createAssembly(name: String, modelIDs: [UUID] = [], position: SIMD3<Float> = .zero) -> AssemblyNode {
        let node = AssemblyNode(name: name, modelIDs: modelIDs, position: position)
        assemblies.append(node)
        selectedAssemblyID = node.id
        logger.info("AssemblyEngine: Created assembly '\(name)' with \(modelIDs.count) models")
        return node
    }

    func addChild(_ child: AssemblyNode, to parentID: UUID) {
        guard let idx = assemblies.firstIndex(where: { $0.id == parentID }) else { return }
        assemblies[idx].addChild(child)
        assemblies.removeAll { $0.id == child.id }
        logger.info("AssemblyEngine: Added child '\(child.name)' to parent")
    }

    func removeAssembly(_ id: UUID) {
        assemblies.removeAll { $0.id == id }
        if selectedAssemblyID == id { selectedAssemblyID = nil }
    }

    func addModel(to assemblyID: UUID, modelID: UUID) {
        guard let idx = assemblies.firstIndex(where: { $0.id == assemblyID }) else { return }
        if !assemblies[idx].modelIDs.contains(modelID) {
            assemblies[idx].modelIDs.append(modelID)
        }
    }

    func removeModel(from assemblyID: UUID, modelID: UUID) {
        guard let idx = assemblies.firstIndex(where: { $0.id == assemblyID }) else { return }
        assemblies[idx].modelIDs.removeAll { $0 == modelID }
    }

    func worldTransform(for assemblyID: UUID) -> simd_float4x4 {
        guard let assembly = assemblies.first(where: { $0.id == assemblyID }) else {
            return matrix_identity_float4x4
        }
        return assembly.worldTransform()
    }

    func boundingBox(for assemblyID: UUID, models: [Model]) -> (min: SIMD3<Float>, max: SIMD3<Float>)? {
        guard let assembly = assemblies.first(where: { $0.id == assemblyID }) else { return nil }
        let allIDs = assembly.allModelIDs()
        let relevantModels = models.filter { allIDs.contains($0.id) }
        guard !relevantModels.isEmpty else { return nil }

        var minBounds = SIMD3<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxBounds = SIMD3<Float>(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)

        let wt = worldTransform(for: assemblyID)

        for model in relevantModels {
            for mesh in model.meshes {
                for vertex in mesh.vertices {
                    let wp = simd_mul(wt, SIMD4<Float>(vertex.position.x, vertex.position.y, vertex.position.z, 1))
                    let wPos = SIMD3<Float>(wp.x, wp.y, wp.z)
                    minBounds = simd_min(minBounds, wPos)
                    maxBounds = simd_max(maxBounds, wPos)
                }
            }
        }

        return (minBounds, maxBounds)
    }

    func clear() {
        assemblies.removeAll()
        selectedAssemblyID = nil
    }

    func validateNoCycles(from nodeID: UUID) -> Bool {
        guard let root = assemblies.first(where: { $0.id == nodeID }) else { return true }
        var visited = Set<UUID>()
        return validateNoCyclesRecursive(node: root, visited: &visited)
    }

    private func validateNoCyclesRecursive(node: AssemblyNode, visited: inout Set<UUID>) -> Bool {
        guard !visited.contains(node.id) else {
            logger.warning("AssemblyEngine: cycle detected at node \(node.name)")
            return false
        }
        visited.insert(node.id)
        for child in node.children {
            if !validateNoCyclesRecursive(node: child, visited: &visited) {
                return false
            }
        }
        return true
    }
}
