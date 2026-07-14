import Foundation
import simd

/// Objetivo unificado de una transformación directa (mover/rotar/escalar).
///
/// El nudo del sustrato (auditoría 2026-07-13, síntoma 1) era que el gizmo/transform
/// leían SIEMPRE `selectionController.bodyIndex` (cuerpo entero) y la selección de
/// sub-objeto (`items[]`) nunca llegaba al transform. `TransformTarget` es la fuente
/// única: si hay un sub-objeto activo (cara/arista/vértice) el objetivo es ESE
/// sub-objeto; si no, el cuerpo escalado.
///
/// Honestidad (regla dura del repo): `supportsRealGeometry` distingue lo que hoy
/// tiene geometría OCCT verificada (cara → push/pull vía `pushPullFace`) de lo que
/// solo ancla el gizmo + numérico pero AÚN no deforma geometría (arista/vértice).
enum TransformTarget: Equatable {
    case body(modelIndex: Int)
    case face(modelIndex: Int, faceIndex: Int)
    case edge(modelIndex: Int, edgeIndex: Int)
    case vertex(modelIndex: Int, vertexIndex: Int)

    var modelIndex: Int {
        switch self {
        case .body(let m), .face(let m, _), .edge(let m, _), .vertex(let m, _): return m
        }
    }

    /// ¿Es un sub-objeto (cara/arista/vértice) en vez del cuerpo entero?
    var isSubObject: Bool {
        if case .body = self { return false }
        return true
    }

    /// ¿El objetivo es una ARISTA?
    var isEdge: Bool {
        if case .edge = self { return true }
        return false
    }

    /// ¿El objetivo es un VÉRTICE?
    var isVertex: Bool {
        if case .vertex = self { return true }
        return false
    }

    /// ¿Hay hoy una op de kernel OCCT verificada que deforme ESTE objetivo?
    /// - cuerpo: sí (translate/rotate/scaleUniform verificados).
    /// - cara: sí (push/pull vía `BRepModeling.pushPullFace`).
    /// - arista/vértice: NO todavía — se ancla el gizmo + numérico pero no se
    ///   finge geometría (spec §Realismo). Devolver false hace que la UI muestre
    ///   estado honesto "no soportado aún" en vez de un botón falso.
    var supportsRealGeometry: Bool {
        switch self {
        case .body, .face: return true
        case .edge, .vertex: return false
        }
    }
}

/// Resolver PURO selección → objetivo de transform. Sin dependencias de UI ni de
/// `@MainActor`: testeable en unidad (spec §Criterios 3-4).
enum TransformTargetResolver {

    /// Resuelve el objetivo activo a partir del estado de selección.
    /// Prioridad: sub-objeto seleccionado (el ÚLTIMO tocado manda, como en las
    /// acciones 1-target de la barra) > cuerpo escalado. `nil` si no hay nada.
    ///
    /// - Parameters:
    ///   - lastItem: el último sub-objeto tocado (`SelectionController.lastItem`).
    ///   - bodyIndex: el cuerpo escalado (`SelectionController.bodyIndex`).
    static func target(lastItem: SelectionController.Item?,
                       bodyIndex: Int?) -> TransformTarget? {
        if let item = lastItem {
            switch item {
            case .face(let m, let f):   return .face(modelIndex: m, faceIndex: f)
            case .edge(let m, let e):   return .edge(modelIndex: m, edgeIndex: e)
            case .vertex(let m, let v): return .vertex(modelIndex: m, vertexIndex: v)
            }
        }
        if let b = bodyIndex { return .body(modelIndex: b) }
        return nil
    }

    /// Centroide del objetivo, en coordenadas de MUNDO — el punto de anclaje del
    /// gizmo (spec §Alcance 1: "el gizmo se ancla al centroide del sub-objeto, no
    /// al centro del cuerpo"). Usa SOLO pickers ya verificados contra OCCT v1.8.8:
    ///   · cuerpo  → centro del bounding box de la malla de display.
    ///   · cara    → media de los vértices de su malla de highlight (triángulos de
    ///               display que yacen sobre la cara). Fallback: media de endpoints
    ///               de aristas que proyectan sobre la cara.
    ///   · arista  → punto medio de la polilínea muestreada (`BRepEdgePicker`).
    ///   · vértice → su posición (`BRepVertexPicker.position`).
    static func center(for target: TransformTarget, in models: [Model]) -> SIMD3<Float>? {
        let idx = target.modelIndex
        guard idx >= 0, idx < models.count else { return nil }
        let model = models[idx]

        switch target {
        case .body:
            return bboxCenter(of: model)

        case .face(_, let f):
            guard let shape = model.cadShape else { return nil }
            if let dm = model.meshes.first,
               let hm = BRepFacePicker.highlightMesh(shape: shape, faceIndex: f,
                                                     displayMesh: dm),
               !hm.vertices.isEmpty {
                var sum = SIMD3<Float>(repeating: 0)
                for v in hm.vertices { sum += v.position }
                return sum / Float(hm.vertices.count)
            }
            // Fallback: promedio de las esquinas del wire (endpoints de aristas que
            // caen sobre la cara). Menos preciso pero suficiente para anclar.
            return faceCornerCentroid(shape: shape, faceIndex: f)

        case .edge(_, let e):
            guard let shape = model.cadShape,
                  let pts = BRepEdgePicker.polyline(of: shape, edgeIndex: e),
                  !pts.isEmpty else { return nil }
            var sum = SIMD3<Float>(repeating: 0)
            for p in pts { sum += p }
            return sum / Float(pts.count)

        case .vertex(_, let v):
            guard let shape = model.cadShape else { return nil }
            return BRepVertexPicker.position(of: shape, vertexIndex: v)
        }
    }

    // MARK: - Helpers puros

    /// Centro del bounding box de la malla de display del cuerpo. Idéntico al
    /// `bboxCenter` histórico de CADModeView (extraído aquí para reutilizar).
    static func bboxCenter(of model: Model) -> SIMD3<Float> {
        var minP = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxP = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for v in model.meshes.first?.vertices ?? [] {
            minP = simd_min(minP, v.position)
            maxP = simd_max(maxP, v.position)
        }
        return minP.x <= maxP.x ? (minP + maxP) * 0.5 : .zero
    }

    /// Promedio de los endpoints de aristas que proyectan sobre la cara `faceIndex`.
    /// Todo con API verificada (`shape.faces()`, `Face.project`, `shape.edges()`,
    /// `Edge.points`).
    private static func faceCornerCentroid(shape: CADShape, faceIndex: Int) -> SIMD3<Float>? {
        let faces = shape.faces()
        guard faceIndex >= 0, faceIndex < faces.count else { return nil }
        let face = faces[faceIndex]
        var sum = SIMD3<Float>(repeating: 0)
        var n = 0
        for edge in shape.edges() {
            for p in edge.points(count: 2) {
                let pd = SIMD3<Double>(p.x, p.y, p.z)
                if let proj = face.project(point: pd), proj.distance < 1e-3 {
                    sum += SIMD3<Float>(Float(p.x), Float(p.y), Float(p.z))
                    n += 1
                }
            }
        }
        return n > 0 ? sum / Float(n) : nil
    }
}
