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

        if let sel = selection, sel.modelIndex == hit.modelIndex {
            // Mismo cuerpo: refinar SIEMPRE a lo tocado (cara/arista nueva).
            // Antes, con cara/arista ya seleccionada, un tap en OTRA cara
            // devolvía a cuerpo — "no deja seleccionar la cara que uno decida".
            refine(hit: hit, model: model)
        } else {
            selection = .body(modelIndex: hit.modelIndex)
            outlinedModelId = model.id.uuidString
            highlightMesh = nil
            statusMessage = "\(model.name)\(bodyMetrics(model)) · toca de nuevo para cara/arista"
        }
    }

    // MARK: - Métricas reales (estilo barra inferior de Shapr3D)

    /// Dimensiones del bbox + volumen exacto del B-rep.
    private func bodyMetrics(_ model: Model) -> String {
        var minP = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxP = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for v in model.meshes.first?.vertices ?? [] {
            minP = simd_min(minP, v.position)
            maxP = simd_max(maxP, v.position)
        }
        guard minP.x <= maxP.x else { return "" }
        let d = maxP - minP
        var s = String(format: " · %.1f×%.1f×%.1f", d.x, d.y, d.z)
        if let vol = model.cadShape?.volume {
            s += String(format: " · vol %.2f", vol)
        }
        return s
    }

    private func refine(hit: SurfaceHit, model: Model) {
        guard let shape = model.cadShape else {
            // Estado VISIBLE, nunca silencio (feedback device: 'la esfera muda')
            statusMessage = "\(model.name) es malla libre — sin caras/aristas exactas"
            return
        }
        // Tolerancia de arista contenida (0.05): cerca del borde gana la arista,
        // pero un tap franco en la cara selecciona LA CARA (no roba la arista).
        if let e = BRepEdgePicker.edgeIndex(of: shape, nearest: hit.position, maxDistance: 0.05) {
            selection = .edge(modelIndex: hit.modelIndex, edgeIndex: e)
            outlinedModelId = nil
            highlightMesh = BRepEdgePicker.highlightTube(shape: shape, edgeIndex: e)
            let edges = shape.edges()
            let len = e < edges.count ? edges[e].length : 0
            statusMessage = String(format: "Arista · %.2f mm", len)
        } else if let f = BRepFacePicker.faceIndex(of: shape, nearest: hit.position),
                  let dm = model.meshes.first,
                  let hm = BRepFacePicker.highlightMesh(shape: shape, faceIndex: f,
                                                        displayMesh: dm) {
            selection = .face(modelIndex: hit.modelIndex, faceIndex: f)
            outlinedModelId = nil
            highlightMesh = hm
            let faces = shape.faces()
            let area = f < faces.count ? faces[f].area() : 0
            statusMessage = String(format: "Cara · área %.2f mm²", area)
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
