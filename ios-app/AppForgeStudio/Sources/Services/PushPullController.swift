import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "PushPull")

/// Máquina de estados del push/pull interactivo (manipulación directa estilo Shapr3D):
/// tap sobre una cara la selecciona; se ajusta la distancia; aplicar ejecuta el
/// boss/pocket B-rep real vía BRepModeling y limpia la selección.
@MainActor
final class PushPullController: ObservableObject {

    struct Selection {
        let model: Model
        let faceIndex: Int
        let faceNormal: SIMD3<Float>
    }

    @Published private(set) var selection: Selection?
    @Published var distance: Double = 0.5
    @Published private(set) var statusMessage: String = "Toca una cara para empezar"

    var hasSelection: Bool { selection != nil }

    /// Resuelve el hit de pantalla a una cara B-rep del modelo tocado.
    func selectFace(from hit: SurfaceHit, in models: [Model]) {
        guard hit.modelIndex >= 0, hit.modelIndex < models.count else { return }
        let model = models[hit.modelIndex]
        guard let shape = model.cadShape else {
            selection = nil
            statusMessage = "Este modelo no tiene B-rep (esculpido/importado) — push/pull no disponible"
            return
        }
        guard let faceIndex = BRepFacePicker.faceIndex(of: shape, nearest: hit.position) else {
            selection = nil
            statusMessage = "No se encontró una cara bajo el toque"
            return
        }
        selection = Selection(model: model, faceIndex: faceIndex, faceNormal: hit.normal)
        statusMessage = "Cara seleccionada — ajusta la distancia y aplica"
    }

    /// Ejecuta el push/pull: distancia > 0 añade material (boss), < 0 excava (pocket).
    /// Devuelve true si el B-rep y la malla del modelo quedaron actualizados.
    @discardableResult
    func apply() -> Bool {
        guard let sel = selection else { return false }
        guard abs(distance) > 1e-9 else {
            statusMessage = "Distancia cero — nada que aplicar"
            return false
        }
        let applied = BRepModeling.applyFeature(to: sel.model) { shape in
            BRepModeling.pushPullFace(shape, faceIndex: sel.faceIndex, distance: distance)
        }
        if applied {
            logger.info("[PushPull] cara \(sel.faceIndex) distancia \(self.distance) aplicada")
            selection = nil
            statusMessage = "Push/pull aplicado"
        } else {
            statusMessage = "La operación falló en esta cara"
        }
        return applied
    }

    func clear() {
        selection = nil
        statusMessage = "Toca una cara para empezar"
    }
}
