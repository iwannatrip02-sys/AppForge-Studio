import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "CADHistoryTree")

// MARK: - Tipos de operación CAD (completo, 20 tipos)

enum CADOperationType: String, Codable, CaseIterable {
    case createPrimitive = "Primitiva"
    case sketchExtrude = "Extrusión Sketch"
    case sketchRevolve = "Revolución Sketch"
    case sketchSweep = "Barrido Sketch"
    case sketchLoft = "Loft Sketch"
    case extrude = "Extruir"
    case revolve = "Revolucionar"
    case sweep = "Barrer"
    case loft = "Loft"
    case booleanUnion = "Unión Booleana"
    case booleanSubtract = "Diferencia Booleana"
    case booleanIntersect = "Intersección Booleana"
    case fillet = "Redondeo"
    case chamfer = "Chaflán"
    case shell = "Vaciado"
    case hole = "Agujero"
    case pushPull = "Push/Pull"
    case move = "Mover"
    case rotate = "Rotar"
    case scale = "Escalar"
    case delete = "Eliminar"
    case mirror = "Reflejar"
    case pattern = "Patrón"

    var icon: String {
        switch self {
        case .createPrimitive: return "cube"
        case .sketchExtrude, .extrude: return "cube.transparent"
        case .sketchRevolve, .revolve: return "rotate.3d"
        case .sketchSweep, .sweep: return "arrow.triangle.swap"
        case .sketchLoft, .loft: return "rectangle.stack"
        case .booleanUnion: return "square.on.square"
        case .booleanSubtract: return "square.slash"
        case .booleanIntersect: return "square.on.circle"
        case .fillet: return "circle.dotted.circle"
        case .chamfer: return "rectangle.and.pencil.and.ellipsis"
        case .shell: return "square.dashed"
        case .hole: return "circle.circle"
        case .pushPull: return "square.stack.3d.up"
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .rotate: return "rotate.3d"
        case .scale: return "arrow.up.backward.and.arrow.down.forward"
        case .delete: return "trash"
        case .mirror: return "arrow.left.and.right"
        case .pattern: return "square.grid.3x3"
        }
    }

    /// ¿Esta operación modifica la geometría del cuerpo? (vs solo transformación)
    var modifiesGeometry: Bool {
        switch self {
        case .move, .rotate, .scale, .delete: return false
        default: return true
        }
    }
}

// MARK: - Operación CAD (valor completo, no solo descripción)

struct CADOperation: Identifiable, Codable {
    let id: UUID
    let type: CADOperationType
    let timestamp: Date
    var affectedModelIDs: [UUID]
    var description: String
    /// Parámetros de la operación (ej: ["distance": 1.5, "radius": 0.3])
    var parameters: [String: Double]
    /// IDs de entidades de referencia (caras, aristas, sketches)
    var referencedEntityIDs: [UUID]

    init(id: UUID = UUID(),
         type: CADOperationType,
         affectedModelIDs: [UUID] = [],
         description: String,
         parameters: [String: Double] = [:],
         referencedEntityIDs: [UUID] = []) {
        self.id = id
        self.type = type
        self.timestamp = Date()
        self.affectedModelIDs = affectedModelIDs
        self.description = description
        self.parameters = parameters
        self.referencedEntityIDs = referencedEntityIDs
    }

    /// Representación legible de los parámetros para la UI del timeline
    var parameterSummary: String {
        guard !parameters.isEmpty else { return "" }
        return parameters
            .sorted { $0.key < $1.key }
            .map { key, value in
                if key == "angle" || key == "ángulo" {
                    return "\(key): \(String(format: "%.1f°", value))"
                }
                return "\(key): \(String(format: "%.2f", value))"
            }
            .joined(separator: ", ")
    }
}

// MARK: - Nodo del árbol de features paramétrico

final class CADFeatureNode: Identifiable {
    let id: UUID
    var operation: CADOperation
    weak var parent: CADFeatureNode?
    var children: [CADFeatureNode]
    var isSuppressed: Bool
    /// Snapshot del B-rep DESPUÉS de aplicar esta operación (nil = no cacheado)
    var brepSnapshot: Data?
    /// ID del modelo resultante de esta operación
    var resultingModelID: UUID?

    init(id: UUID = UUID(),
         operation: CADOperation,
         parent: CADFeatureNode? = nil,
         brepSnapshot: Data? = nil,
         resultingModelID: UUID? = nil) {
        self.id = id
        self.operation = operation
        self.parent = parent
        self.children = []
        self.isSuppressed = false
        self.brepSnapshot = brepSnapshot
        self.resultingModelID = resultingModelID
    }

    /// Agrega un hijo (próxima operación en la cadena)
    func addChild(_ child: CADFeatureNode) {
        child.parent = self
        children.append(child)
    }

    /// Elimina un hijo
    func removeChild(_ child: CADFeatureNode) {
        children.removeAll { $0.id == child.id }
    }

    /// Camino desde la raíz hasta este nodo (orden de aplicación)
    func pathFromRoot() -> [CADFeatureNode] {
        var path: [CADFeatureNode] = []
        var current: CADFeatureNode? = self
        while let node = current {
            path.insert(node, at: 0)
            current = node.parent
        }
        return path
    }

    /// Todos los nodos en este subárbol (recorrido en profundidad)
    func allNodes() -> [CADFeatureNode] {
        var result = [self]
        for child in children {
            result.append(contentsOf: child.allNodes())
        }
        return result
    }
}

// MARK: - Árbol de features paramétrico

/// El corazón del CAD paramétrico: almacena la secuencia de operaciones,
/// soporta edición de parámetros con recompute, y se conecta a OCCT/BRepHistory
/// para producir geometría real.
///
/// Anatomía:
/// - `rootNodes`: cuerpos independientes (sin padre común)
/// - `currentNode`: donde se insertará la próxima operación
/// - `selectedNodeID`: nodo seleccionado en el timeline UI
/// - `undoStack` / `redoStack`: navegación lineal
///
/// Flujo paramétrico real:
/// 1. Usuario hace operación → `recordOperation()` guarda params + snapshot B-rep
/// 2. Usuario edita parámetro → `updateOperationParameter()` modifica el nodo
/// 3. `requestRecompute` notifica a los observers que re-ejecuten desde ese punto
///
/// La reconstrucción real de geometría la hace CADModeView vía OCCT;
/// el árbol es el REGISTRO de qué hacer, no el ejecutor.
@MainActor
final class CADHistoryTree: ObservableObject {
    @Published var rootNodes: [CADFeatureNode] = []
    @Published var currentNode: CADFeatureNode?
    @Published var selectedNodeID: UUID?
    @Published var isDirty: Bool = false
    @Published var lastOperationDescription: String = ""

    /// Se emite cuando un parámetro cambia y la geometría debe reconstruirse.
    /// El subscriber (CADModeView) re-ejecuta las operaciones desde el índice dado.
    @Published var recomputeRequested: (fromNodeID: UUID, changedParameter: String)? = nil

    private var undoStack: [CADFeatureNode] = []
    private var redoStack: [CADFeatureNode] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var operationCount: Int { undoStack.count }
    /// Cadena lineal de operaciones activas (para el timeline UI)
    var activeChain: [CADOperation] {
        undoStack.map { $0.operation }
    }

    // MARK: - Registrar operación

    /// Registra una nueva operación en el historial.
    /// - Parameters:
    ///   - op: descripción completa de la operación
    ///   - brepSnapshot: B-rep resultante serializado (.brep Data), para recompute
    ///   - resultingModelID: UUID del modelo creado/modificado
    /// - Returns: el nodo creado
    @discardableResult
    func recordOperation(_ op: CADOperation,
                         brepSnapshot: Data? = nil,
                         resultingModelID: UUID? = nil) -> CADFeatureNode {
        let node = CADFeatureNode(
            operation: op,
            parent: currentNode,
            brepSnapshot: brepSnapshot,
            resultingModelID: resultingModelID
        )

        if let parent = currentNode {
            parent.addChild(node)
        } else {
            rootNodes.append(node)
        }

        redoStack.removeAll()
        currentNode = node
        selectedNodeID = node.id
        undoStack.append(node)
        isDirty = true
        lastOperationDescription = op.description

        logger.debug("CADHistoryTree: recorded '\(op.description)' type=\(op.type.rawValue) params=\(op.parameters)")

        return node
    }

    /// Conveniencia: registra operación solo con descripción (legacy)
    @discardableResult
    func pushOperation(_ op: CADOperation,
                       parentID: UUID? = nil) -> CADFeatureNode {
        if let parentID = parentID,
           let parent = findNode(with: parentID, in: rootNodes) {
            let node = CADFeatureNode(operation: op, parent: parent)
            parent.addChild(node)
            redoStack.removeAll()
            currentNode = node
            selectedNodeID = node.id
            undoStack.append(node)
            isDirty = true
            lastOperationDescription = op.description
            return node
        }
        return recordOperation(op)
    }

    /// Registro rápido: crea la CADOperation internamente
    @discardableResult
    func beginOperation(_ name: String,
                        type: CADOperationType = .sketchExtrude,
                        params: [String: Double] = [:],
                        affectedIDs: [UUID] = []) -> CADFeatureNode {
        let op = CADOperation(
            type: type,
            affectedModelIDs: affectedIDs,
            description: name,
            parameters: params
        )
        return recordOperation(op)
    }

    // MARK: - Edición paramétrica

    /// Actualiza un parámetro de una operación y solicita recompute.
    /// - Parameters:
    ///   - nodeID: el nodo cuya operación se edita
    ///   - key: nombre del parámetro (ej: "distance", "radius")
    ///   - value: nuevo valor
    func updateParameter(nodeID: UUID, key: String, value: Double) {
        guard let node = findNode(with: nodeID, in: rootNodes) else {
            logger.warning("CADHistoryTree: node \(nodeID) not found for parameter update")
            return
        }
        node.operation.parameters[key] = value
        node.brepSnapshot = nil  // invalidar cache downstream
        invalidateDownstream(from: node)
        isDirty = true
        recomputeRequested = (nodeID, key)
        logger.info("CADHistoryTree: parameter '\(key)' = \(value) in '\(node.operation.description)' → recompute requested")
    }

    /// Suprime o reactiva una feature (no se aplica pero se conserva en el árbol)
    func toggleSuppress(nodeID: UUID) {
        guard let node = findNode(with: nodeID, in: rootNodes) else { return }
        node.isSuppressed.toggle()
        invalidateDownstream(from: node)
        isDirty = true
        recomputeRequested = (nodeID, "suppress")
    }

    /// Reordena: mueve un nodo después de otro (cambia dependencia)
    func reparent(nodeID: UUID, newParentID: UUID?) {
        guard let node = findNode(with: nodeID, in: rootNodes) else { return }
        node.parent?.removeChild(node)
        if let newParentID = newParentID,
           let newParent = findNode(with: newParentID, in: rootNodes) {
            newParent.addChild(node)
        } else {
            rootNodes.append(node)
        }
        invalidateDownstream(from: node)
        isDirty = true
        recomputeRequested = (nodeID, "reparent")
    }

    /// Invalida los snapshots B-rep de este nodo y todos sus descendientes
    private func invalidateDownstream(from node: CADFeatureNode) {
        node.brepSnapshot = nil
        for child in node.children {
            invalidateDownstream(from: child)
        }
    }

    // MARK: - Undo / Redo

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
        recomputeRequested = (node.id, "undo")
        return node.operation
    }

    func redo() -> CADOperation? {
        guard canRedo else { return nil }
        let node = redoStack.removeLast()
        undoStack.append(node)
        currentNode = node
        selectedNodeID = node.id
        isDirty = true
        recomputeRequested = (node.id, "redo")
        return node.operation
    }

    // MARK: - Reconstrucción

    /// Obtiene la cadena lineal de operaciones activas (no suprimidas)
    func getActiveOperationChain() -> [CADOperation] {
        undoStack
            .filter { !$0.isSuppressed }
            .map { $0.operation }
    }

    /// Encuentra el índice de un nodo en la cadena activa
    func indexOf(nodeID: UUID) -> Int? {
        undoStack.firstIndex { $0.id == nodeID }
    }

    /// Nodo anterior a `nodeID` en la cadena (para restaurar snapshot pre-operación)
    func nodeBefore(_ nodeID: UUID) -> CADFeatureNode? {
        guard let idx = indexOf(nodeID: nodeID), idx > 0 else { return nil }
        return undoStack[idx - 1]
    }

    /// Reconstruye la escena aplicando operaciones en orden sobre modelos iniciales.
    /// Solo maneja operaciones de estructura de escena (crear, eliminar, transformar).
    /// Las operaciones de geometría (extrude, fillet, etc.) las reconstruye OCCT.
    func rebuildSceneFromOperations(initialModels: [Model],
                                    operations: [CADOperation]) -> [Model] {
        var models = initialModels
        for op in operations {
            guard !op.type.modifiesGeometry else { continue }
            switch op.type {
            case .createPrimitive:
                let model = Model(name: op.description)
                model.meshes = []
                models.append(model)

            case .delete:
                models.removeAll { op.affectedModelIDs.contains($0.id) }

            case .move:
                let tx = Float(op.parameters["tx"] ?? 0)
                let ty = Float(op.parameters["ty"] ?? 0)
                let tz = Float(op.parameters["tz"] ?? 0)
                for i in models.indices where op.affectedModelIDs.contains(models[i].id) {
                    let translation = simd_float4x4(
                        SIMD4<Float>(1, 0, 0, 0),
                        SIMD4<Float>(0, 1, 0, 0),
                        SIMD4<Float>(0, 0, 1, 0),
                        SIMD4<Float>(tx, ty, tz, 1)
                    )
                    models[i].transform = simd_mul(translation, models[i].transform)
                }

            case .rotate:
                let angle = Float(op.parameters["angle"] ?? 0)
                let ax = Float(op.parameters["axisX"] ?? 0)
                let ay = Float(op.parameters["axisY"] ?? 1)
                let az = Float(op.parameters["axisZ"] ?? 0)
                let axis = SIMD3<Float>(ax, ay, az)
                for i in models.indices where op.affectedModelIDs.contains(models[i].id) {
                    let q = simd_quatf(angle: angle, axis: axis)
                    let R = simd_float4x4(q)
                    models[i].transform = simd_mul(R, models[i].transform)
                }

            case .scale:
                let sx = Float(op.parameters["sx"] ?? 1)
                let sy = Float(op.parameters["sy"] ?? 1)
                let sz = Float(op.parameters["sz"] ?? 1)
                for i in models.indices where op.affectedModelIDs.contains(models[i].id) {
                    let S = simd_float4x4(
                        SIMD4<Float>(sx, 0, 0, 0),
                        SIMD4<Float>(0, sy, 0, 0),
                        SIMD4<Float>(0, 0, sz, 0),
                        SIMD4<Float>(0, 0, 0, 1)
                    )
                    models[i].transform = simd_mul(S, models[i].transform)
                }

            case .mirror:
                let mx = Float(op.parameters["mirrorX"] ?? 1)
                let my = Float(op.parameters["mirrorY"] ?? 1)
                let mz = Float(op.parameters["mirrorZ"] ?? 1)
                for i in models.indices where op.affectedModelIDs.contains(models[i].id) {
                    let M = simd_float4x4(
                        SIMD4<Float>(mx, 0, 0, 0),
                        SIMD4<Float>(0, my, 0, 0),
                        SIMD4<Float>(0, 0, mz, 0),
                        SIMD4<Float>(0, 0, 0, 1)
                    )
                    models[i].transform = simd_mul(M, models[i].transform)
                }

            default:
                break
            }
        }
        return models
    }

    // MARK: - Búsqueda

    func findNode(with id: UUID, in nodes: [CADFeatureNode]) -> CADFeatureNode? {
        for node in nodes {
            if node.id == id { return node }
            if let found = findNode(with: id, in: node.children) { return found }
        }
        return nil
    }

    func findNode(with id: UUID) -> CADFeatureNode? {
        findNode(with: id, in: rootNodes)
    }

    // MARK: - Limpieza

    func clear() {
        rootNodes.removeAll()
        undoStack.removeAll()
        redoStack.removeAll()
        currentNode = nil
        selectedNodeID = nil
        recomputeRequested = nil
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
