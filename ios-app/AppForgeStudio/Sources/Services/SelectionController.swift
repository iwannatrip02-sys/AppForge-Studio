import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "Selection")

/// Selección unificada del modo CAD (ÁREA 1): el sistema nervioso de las
/// herramientas. Semántica estilo Shapr3D:
///   1er tap sobre un cuerpo  → selecciona el CUERPO (outline brasa).
///   2º tap sobre ese cuerpo  → refina a ARISTA (si el toque está cerca de una)
///                              o a CARA (highlight).
///   tap en vacío             → deselecciona.
/// Testeable sin UI (patrón PushPullController).
@MainActor
final class SelectionController: ObservableObject {

    enum Selection: Equatable {
        case body(modelIndex: Int)
        case face(modelIndex: Int, faceIndex: Int)
        case edge(modelIndex: Int, edgeIndex: Int)

        var modelIndex: Int {
            switch self {
            case .body(let m), .face(let m, _), .edge(let m, _): return m
            }
        }
    }

    @Published private(set) var selection: Selection?
    @Published private(set) var statusMessage = ""
    /// Highlight de cara/arista (overlay de malla). El outline de CUERPO lo
    /// dibuja el renderer (outlinedModelId) — no es un overlay tocable.
    @Published private(set) var highlightMesh: Mesh?
    /// id del modelo para el outline del renderer (solo en selección de cuerpo).
    @Published private(set) var outlinedModelId: String?
    /// Último hit que produjo la selección (para acciones que lo necesitan,
    /// p. ej. arrancar push/pull sobre la cara seleccionada).
    private(set) var lastHit: SurfaceHit?

    var hasSelection: Bool { selection != nil }

    func handleTap(hit: SurfaceHit, models: [Model]) {
        guard hit.modelIndex >= 0, hit.modelIndex < models.count else { return }
        let model = models[hit.modelIndex]
        lastHit = hit

        if let sel = selection, sel.modelIndex == hit.modelIndex, case .body = sel {
            refine(hit: hit, model: model)
        } else {
            selection = .body(modelIndex: hit.modelIndex)
            outlinedModelId = model.id.uuidString
            highlightMesh = nil
            statusMessage = "\(model.name) · toca de nuevo para cara o arista"
        }
    }

    private func refine(hit: SurfaceHit, model: Model) {
        guard let shape = model.cadShape else {
            // Estado VISIBLE, nunca silencio (feedback device: 'la esfera muda')
            statusMessage = "\(model.name) es malla libre — sin caras/aristas exactas"
            return
        }
        if let e = BRepEdgePicker.edgeIndex(of: shape, nearest: hit.position, maxDistance: 0.08) {
            selection = .edge(modelIndex: hit.modelIndex, edgeIndex: e)
            outlinedModelId = nil
            highlightMesh = BRepEdgePicker.highlightTube(shape: shape, edgeIndex: e)
            statusMessage = "Arista seleccionada"
        } else if let f = BRepFacePicker.faceIndex(of: shape, nearest: hit.position),
                  let dm = model.meshes.first,
                  let hm = BRepFacePicker.highlightMesh(shape: shape, faceIndex: f,
                                                        displayMesh: dm) {
            selection = .face(modelIndex: hit.modelIndex, faceIndex: f)
            outlinedModelId = nil
            highlightMesh = hm
            statusMessage = "Cara seleccionada"
        } else {
            statusMessage = "No se encontró cara ni arista bajo el toque"
        }
    }

    func deselect() {
        selection = nil
        outlinedModelId = nil
        highlightMesh = nil
        lastHit = nil
        statusMessage = ""
    }
}
