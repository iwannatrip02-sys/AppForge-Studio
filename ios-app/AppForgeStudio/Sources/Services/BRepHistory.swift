import Foundation
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "BRepHistory")

/// Undo/redo a nivel B-rep: snapshots de (cadShape, meshes) POR MODELO.
///
/// Necesario porque el undo de escena (CanvasViewModel) guarda Scene3D por valor,
/// pero Model es clase: los snapshots comparten referencias y las mutaciones de
/// B-rep/malla atraviesan el stack. Este historial captura el estado real.
@MainActor
final class BRepHistory: ObservableObject {
    static let shared = BRepHistory()

    struct Entry {
        weak var model: Model?
        let shape: CADShape?
        let meshes: [Mesh]
    }

    @Published private(set) var undoCount: Int = 0
    @Published private(set) var redoCount: Int = 0

    private var undoStack: [Entry] = []
    private var redoStack: [Entry] = []
    private let maxDepth = 50

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Llamar ANTES de mutar el B-rep/malla de un modelo (feature, push/pull, booleano in-place).
    func recordChange(of model: Model) {
        undoStack.append(Entry(model: model, shape: model.cadShape, meshes: model.meshes))
        if undoStack.count > maxDepth { undoStack.removeFirst() }
        redoStack.removeAll()
        syncCounts()
    }

    /// Descarta el último snapshot sin restaurar (para operaciones que fallaron sin mutar).
    func discardLast() {
        _ = undoStack.popLast()
        syncCounts()
    }

    @discardableResult
    func undo() -> Bool { swapTop(from: &undoStack, to: &redoStack) }

    @discardableResult
    func redo() -> Bool { swapTop(from: &redoStack, to: &undoStack) }

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        syncCounts()
    }

    /// Restaura el tope de `from` (saltando modelos ya liberados) y guarda el estado
    /// actual del modelo en `to` para poder revertir la reversión.
    private func swapTop(from: inout [Entry], to: inout [Entry]) -> Bool {
        defer { syncCounts() }
        while let entry = from.popLast() {
            guard let model = entry.model else { continue }  // modelo borrado: descartar
            to.append(Entry(model: model, shape: model.cadShape, meshes: model.meshes))
            model.cadShape = entry.shape
            model.meshes = entry.meshes
            logger.info("[BRepHistory] restaurado \(model.name)")
            return true
        }
        return false
    }

    private func syncCounts() {
        undoCount = undoStack.count
        redoCount = redoStack.count
    }
}
