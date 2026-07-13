import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "Selection")

/// Selección DIRECTA y en tiempo real (v2, feedback device):
///   · Un tap selecciona LO QUE TOCAS: la arista si estás cerca de una, si no
///     LA CARA — sin pasar por "cuerpo" primero ("era torpe, dos taps, raro").
///   · Taps adicionales AÑADEN a la selección (multi-selección); tocar algo ya
///     seleccionado lo quita.
///   · "Cuerpo" se selecciona escalando desde la barra contextual (botón) —
///     para mover/patrón/espejo/eliminar.
///   · Tap en vacío deselecciona todo.
/// Testeable sin UI.
@MainActor
final class SelectionController: ObservableObject {

    enum Item: Equatable, Hashable {
        case face(modelIndex: Int, faceIndex: Int)
        case edge(modelIndex: Int, edgeIndex: Int)
        case vertex(modelIndex: Int, vertexIndex: Int)

        var modelIndex: Int {
            switch self {
            case .face(let m, _), .edge(let m, _), .vertex(let m, _): return m
            }
        }
    }

    /// Selección múltiple (orden de toque preservado; el último manda en acciones 1-target).
    @Published private(set) var items: [Item] = []
    /// Cuerpo escalado (botón "Cuerpo" de la barra): habilita acciones de cuerpo entero.
    @Published private(set) var bodyIndex: Int? = nil
    @Published private(set) var statusMessage = ""
    /// Highlight COMBINADO de todas las caras/aristas seleccionadas.
    @Published private(set) var highlightMesh: Mesh?
    /// id del modelo para el outline del renderer (solo con cuerpo escalado).
    @Published private(set) var outlinedModelId: String?
    private(set) var lastHit: SurfaceHit?

    var hasSelection: Bool { !items.isEmpty || bodyIndex != nil }
    var lastItem: Item? { items.last }

    // MARK: - Tap directo (cara/arista, toggle multi)

    func handleTap(hit: SurfaceHit, models: [Model]) {
        guard hit.modelIndex >= 0, hit.modelIndex < models.count else { return }
        let model = models[hit.modelIndex]
        lastHit = hit
        bodyIndex = nil
        outlinedModelId = nil

        guard let shape = model.cadShape else {
            statusMessage = "\(model.name): malla libre — usa Esculpir o transforma el cuerpo"
            return
        }

        let item: Item
        if let v = BRepVertexPicker.vertexIndex(of: shape, nearest: hit.position, maxDistance: 0.03) {
            item = .vertex(modelIndex: hit.modelIndex, vertexIndex: v)
        } else if let e = BRepEdgePicker.edgeIndex(of: shape, nearest: hit.position, maxDistance: 0.05) {
            item = .edge(modelIndex: hit.modelIndex, edgeIndex: e)
        } else if let f = BRepFacePicker.faceIndex(of: shape, nearest: hit.position) {
            item = .face(modelIndex: hit.modelIndex, faceIndex: f)
        } else {
            statusMessage = "Nada seleccionable bajo el toque"
            return
        }

        if let idx = items.firstIndex(of: item) {
            items.remove(at: idx)          // tocar lo seleccionado lo QUITA
        } else {
            items.append(item)             // añadir (multi-selección natural)
        }
        rebuildHighlight(models: models)
        updateStatus(models: models)
    }

    /// Selección de cuerpo desde el panel de Elementos.
    func selectBodyFromPanel(index: Int, models: [Model]) {
        guard index >= 0, index < models.count else { return }
        bodyIndex = index
        items = []
        highlightMesh = nil
        outlinedModelId = models[index].id.uuidString
        statusMessage = "\(models[index].name)\(bodyMetrics(models[index]))"
    }

    /// Escalar la selección al CUERPO del último item (botón de la barra).
    func escalateToBody(models: [Model]) {
        guard let m = items.last?.modelIndex ?? lastHit.map({ $0.modelIndex }),
              m < models.count else { return }
        bodyIndex = m
        items = []
        highlightMesh = nil
        outlinedModelId = models[m].id.uuidString
        statusMessage = "\(models[m].name)\(bodyMetrics(models[m]))"
    }

    /// Mensaje contextual desde la UI (drag de cara, avisos honestos) — se muestra
    /// en la misma barra de estado de la selección.
    func showHint(_ text: String) { statusMessage = text }

    func deselect() {
        items = []
        bodyIndex = nil
        highlightMesh = nil
        outlinedModelId = nil
        lastHit = nil
        statusMessage = ""
    }

    // MARK: - Highlight combinado

    private func rebuildHighlight(models: [Model]) {
        var v: [Vertex] = []
        var i: [UInt32] = []
        for item in items {
            guard item.modelIndex < models.count,
                  let shape = models[item.modelIndex].cadShape else { continue }
            switch item {
            case .face(_, let f):
                if let dm = models[item.modelIndex].meshes.first,
                   let hm = BRepFacePicker.highlightMesh(shape: shape, faceIndex: f,
                                                         displayMesh: dm) {
                    let base = UInt32(v.count)
                    v.append(contentsOf: hm.vertices)
                    i.append(contentsOf: hm.indices.map { $0 + base })
                }
            case .edge(_, let e):
                if let tube = BRepEdgePicker.highlightTube(shape: shape, edgeIndex: e) {
                    let base = UInt32(v.count)
                    v.append(contentsOf: tube.vertices)
                    i.append(contentsOf: tube.indices.map { $0 + base })
                }
            case .vertex(_, let vi):
                if let pos = BRepVertexPicker.position(of: shape, vertexIndex: vi) {
                    let dot = BRepVertexPicker.highlightDot(at: pos)
                    let base = UInt32(v.count)
                    v.append(contentsOf: dot.vertices)
                    i.append(contentsOf: dot.indices.map { $0 + base })
                }
            }
        }
        highlightMesh = v.isEmpty ? nil : Mesh(vertices: v, indices: i)
    }

    // MARK: - Métricas

    private func updateStatus(models: [Model]) {
        let faces = items.filter { if case .face = $0 { return true }; return false }
        let edges = items.filter { if case .edge = $0 { return true }; return false }
        let verts = items.filter { if case .vertex = $0 { return true }; return false }
        if items.isEmpty { statusMessage = ""; return }

        var parts: [String] = []
        if !faces.isEmpty {
            var area = 0.0
            for case .face(let m, let f) in faces where m < models.count {
                if let shape = models[m].cadShape {
                    let fs = shape.faces()
                    if f < fs.count { area += fs[f].area() }
                }
            }
            parts.append(faces.count == 1
                ? String(format: "Cara · área %.2f", area)
                : String(format: "%d caras · área %.2f", faces.count, area))
        }
        if !edges.isEmpty {
            var len = 0.0
            for case .edge(let m, let e) in edges where m < models.count {
                if let shape = models[m].cadShape {
                    let es = shape.edges()
                    if e < es.count { len += es[e].length }
                }
            }
            parts.append(edges.count == 1
                ? String(format: "Arista · %.2f mm", len)
                : String(format: "%d aristas · %.2f mm", edges.count, len))
        }
        if !verts.isEmpty {
            if verts.count == 1, case .vertex(let m, let vi) = verts[0], m < models.count,
               let shape = models[m].cadShape,
               let p = BRepVertexPicker.position(of: shape, vertexIndex: vi) {
                parts.append(String(format: "Punto · (%.2f, %.2f, %.2f)", p.x, p.y, p.z))
            } else {
                parts.append("\(verts.count) puntos")
            }
        }
        statusMessage = parts.joined(separator: " · ")
    }

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
}
