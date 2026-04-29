import Foundation
import simd

// MARK: - Tipos de operacion CAD

enum CADOperationType: String, Codable, CaseIterable {
    case createShape = "Crear Primitiva"
    case extrude = "Extruir"
    case revolve = "Revolucionar"
    case sweep = "Barrer"
    case loft = "Loft"
    case booleanUnion = "Union Booleana"
    case booleanSubtract = "Diferencia Booleana"
    case booleanIntersect = "Interseccion Booleana"
    case fillet = "Redondeo"
    case chamfer = "Chaflan"
    case shell = "Shell"
    case move = "Mover"
    case rotate = "Rotar"
    case scale = "Escalar"
    case delete = "Eliminar"
    case sketchExtrude = "Extrusion de Sketch"
    case unknown = "Desconocido"
}

// MARK: - Operacion CAD

struct CADOperation: Identifiable {
    let id: UUID
    let type: CADOperationType
    let timestamp: Date
    var affectedModelIDs: [UUID]
    var description: String
    var parameters: [String: Double]
    
    init(id: UUID = UUID(), type: CADOperationType, affectedModelIDs: [UUID] = [],
         description: String, parameters: [String: Double] = [:]) {
        self.id = id
        self.type = type
        self.timestamp = Date()
        self.affectedModelIDs = affectedModelIDs
        self.description = description
        self.parameters = parameters
    }
}

// MARK: - Nodo del arbol de historial

class CADNode: Identifiable {
    let id: UUID
    weak var parent: CADNode?
    var operation: CADOperation
    var children: [CADNode]
    var isExpanded: Bool
    
    init(id: UUID = UUID(), operation: CADOperation, parent: CADNode? = nil) {
        self.id = id
        self.operation = operation
        self.parent = parent
        self.children = []
        self.isExpanded = true
    }
    
    func addChild(_ child: CADNode) {
        child.parent = self
        children.append(child)
    }
    
    func allNodeIDs() -> [UUID] {
        var ids = [id]
        for child in children { ids.append(contentsOf: child.allNodeIDs()) }
        return ids
    }
}

// MARK: - Arbol de historial CAD

class CADHistoryTree: ObservableObject {
    @Published var rootNodes: [CADNode] = []
    @Published var currentNode: CADNode? = nil
    @Published var selectedNodeID: UUID? = nil
    private var undoStack: [CADNode] = []
    private var redoStack: [CADNode] = []
    @Published var isDirty: Bool = false
    @Published var lastOperationDescription: String = ""
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var operationCount: Int { undoStack.count }
    
    // MARK: - Push operation
    
    @discardableResult
    func pushOperation(_ op: CADOperation, parentID: UUID? = nil) -> CADNode {
        let node = CADNode(operation: op)
        if let parentID = parentID, let parent = findNode(with: parentID, in: rootNodes) {
            parent.addChild(node)
            redoStack.removeAll()
        } else {
            rootNodes.append(node)
            redoStack.removeAll()
        }
        currentNode = node
        selectedNodeID = node.id
        undoStack.append(node)
        isDirty = true
        lastOperationDescription = op.description
        return node
    }
    
    // MARK: - Undo
    
    func undo() -> CADOperation? {
        guard canUndo else { return nil }
        let node = undoStack.removeLast()
        redoStack.append(node)
        if let parent = node.parent {
            currentNode = parent
            selectedNodeID = parent.id
        } else if let prev = undoStack.last {
            currentNode = prev
            selectedNodeID = prev.id
        } else {
            currentNode = nil
            selectedNodeID = nil
        }
        isDirty = true
        return node.operation
    }
    
    // MARK: - Redo
    
    func redo() -> CADOperation? {
        guard canRedo else { return nil }
        let node = redoStack.removeLast()
        undoStack.append(node)
        currentNode = node
        selectedNodeID = node.id
        isDirty = true
        return node.operation
    }
    
    // MARK: - Rebuild chain
    
    func getActiveOperationChain() -> [CADOperation] {
        return undoStack.map { $0.operation }
    }
    
    func rebuildSceneFromOperations(initialModels: [Model], operations: [CADOperation]) -> [Model] {
        var models = initialModels
        for op in operations {
            switch op.type {
            case .createShape:
                let model = Model(name: op.description, meshes: [], transform: matrix_identity_float4x4)
                models.append(model)
            case .delete:
                models.removeAll { op.affectedModelIDs.contains($0.id) }
            case .move:
                for i in models.indices where op.affectedModelIDs.contains(models[i].id) {
                    let tx = Float(op.parameters["tx"] ?? 0)
                    let ty = Float(op.parameters["ty"] ?? 0)
                    let tz = Float(op.parameters["tz"] ?? 0)
                    let translation = simd_float4x4.translate(tx, ty, tz)
                    models[i].transform = simd_mul(translation, models[i].transform)
                }
            default:
                break
            }
        }
        return models
    }
    
    // MARK: - Helpers
    
    private func findNode(with id: UUID, in nodes: [CADNode]) -> CADNode? {
        for node in nodes {
            if node.id == id { return node }
            if let found = findNode(with: id, in: node.children) { return found }
        }
        return nil
    }
    
    func clear() {
        rootNodes.removeAll()
        undoStack.removeAll()
        redoStack.removeAll()
        currentNode = nil
        selectedNodeID = nil
        isDirty = false
        lastOperationDescription = ""
    }
}

// MARK: - Matrix helpers

extension simd_float4x4 {
    static func translate(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
        var m = matrix_identity_float4x4
        m.columns.3 = SIMD4<Float>(x, y, z, 1)
        return m
    }
}
