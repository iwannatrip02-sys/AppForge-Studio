import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "EdgeFillet")

/// Máquina de estados del fillet contextual por arista (menú adaptativo,
/// BLUEPRINT S2): tocar cerca de una arista la selecciona; se ajusta el radio;
/// aplicar redondea SOLO esa arista (fillet B-rep selectivo) y limpia.
/// Mismo patrón que PushPullController: testeable sin UI.
@MainActor
final class EdgeFilletController: ObservableObject {

    struct Selection {
        let model: Model
        let edgeIndex: Int
    }

    @Published private(set) var selection: Selection?
    @Published var radius: Double = 0.1
    @Published private(set) var statusMessage: String = ""
    /// Tubo de resaltado de la arista seleccionada (overlay; nil = sin selección).
    @Published private(set) var highlightMesh: Mesh?

    var hasSelection: Bool { selection != nil }

    /// Intenta resolver el hit a una arista B-rep. Devuelve false si el toque
    /// no es claramente sobre una arista (→ el llamador puede tratarlo como cara).
    @discardableResult
    func selectEdge(from hit: SurfaceHit, in models: [Model]) -> Bool {
        guard hit.modelIndex >= 0, hit.modelIndex < models.count else { return false }
        let model = models[hit.modelIndex]
        guard let shape = model.cadShape else {
            clear()
            return false
        }
        guard let edgeIndex = BRepEdgePicker.edgeIndex(of: shape, nearest: hit.position) else {
            clear()
            return false
        }
        selection = Selection(model: model, edgeIndex: edgeIndex)
        highlightMesh = BRepEdgePicker.highlightTube(shape: shape, edgeIndex: edgeIndex)
        statusMessage = String(format: "Arista seleccionada · radio %.2f", radius)
        return true
    }

    /// Redondea la arista seleccionada (fillet B-rep selectivo).
    @discardableResult
    func applyFillet() -> Bool {
        guard let sel = selection else { return false }
        guard radius > 1e-9 else {
            statusMessage = "Radio cero — nada que aplicar"
            return false
        }
        BRepHistory.shared.recordChange(of: sel.model)
        let applied = BRepModeling.filletEdge(sel.model, edgeIndex: sel.edgeIndex,
                                              radius: radius)
        if applied {
            logger.info("[EdgeFillet] arista \(sel.edgeIndex) radio \(self.radius) aplicado")
            selection = nil
            highlightMesh = nil
            statusMessage = "Arista redondeada"
        } else {
            BRepHistory.shared.discardLast()  // falló sin mutar: descartar snapshot
            statusMessage = "El radio no cabe en esta arista"
        }
        return applied
    }

    func clear() {
        selection = nil
        highlightMesh = nil
        statusMessage = ""
    }
}
