import Foundation
import simd
import OCCTSwift
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "BRepModeling")

/// Núcleo de modelado sobre el B-rep vivo (`Model.cadShape`).
///
/// Principio (el mismo de Shapr3D/Fusion360 con Parasolid): el B-rep es la fuente
/// de verdad de la geometría; la malla (`Model.meshes`) es solo la representación
/// para render/sculpt. Toda operación de ingeniería (booleanos, fillet, chamfer,
/// shell, push/pull) se ejecuta sobre el B-rep y re-triangula la malla.
enum BRepModeling {

    // MARK: - Booleanos reales entre modelos

    /// Booleano B-rep entre dos modelos. Devuelve un modelo nuevo con B-rep + malla,
    /// o nil si alguno no tiene B-rep o la operación falla en geometría degenerada.
    static func boolean(_ op: CADOperationType, _ a: Model, _ b: Model,
                        quality: MeshQuality = .medium) -> Model? {
        guard let shapeA = a.cadShape, let shapeB = b.cadShape else {
            logger.info("[BRep] boolean \(op.rawValue): algún modelo sin B-rep — fallback a malla")
            return nil
        }
        let result: CADShape?
        let prefix: String
        switch op {
        case .booleanUnion: result = shapeA + shapeB; prefix = "Union"
        case .booleanSubtract: result = shapeA - shapeB; prefix = "Subtract"
        case .booleanIntersect: result = shapeA & shapeB; prefix = "Intersect"
        default: return nil
        }
        guard let shape = result, let mesh = OCCTBridge.toMesh(shape, quality: quality) else {
            logger.warning("[BRep] boolean \(op.rawValue) falló (geometría degenerada?)")
            return nil
        }
        let model = Model(name: "\(prefix)_\(UUID().uuidString.prefix(6))")
        model.cadShape = shape
        model.meshes = [mesh]
        model.edgesMesh = OCCTBridge.edgesMesh(shape)
        return model
    }

    // MARK: - Features in-place

    /// Aplica una transformación de feature al B-rep del modelo y refresca su malla.
    /// Devuelve false (sin mutar nada) si el modelo no tiene B-rep o la feature falla.
    @discardableResult
    static func applyFeature(to model: Model, quality: MeshQuality = .medium,
                             _ transform: (CADShape) -> CADShape?) -> Bool {
        guard let shape = model.cadShape else { return false }
        guard let newShape = transform(shape),
              let mesh = OCCTBridge.toMesh(newShape, quality: quality) else {
            logger.warning("[BRep] feature falló sobre \(model.name)")
            return false
        }
        model.cadShape = newShape
        model.meshes = [mesh]
        model.edgesMesh = OCCTBridge.edgesMesh(newShape)  // aristas visibles (look Shapr3D)
        model.geometryVersion += 1  // el renderer reconstruye los buffers GPU
        return true
    }

    /// Fillet de todas las aristas con radio dado (B-rep real vía OCCT TKFillet).
    @discardableResult
    static func fillet(_ model: Model, radius: Double) -> Bool {
        applyFeature(to: model) { $0.filleted(radius: radius) }
    }

    /// Chamfer de todas las aristas (B-rep real).
    @discardableResult
    static func chamfer(_ model: Model, distance: Double) -> Bool {
        applyFeature(to: model) { $0.chamfered(distance: distance) }
    }

    /// Fillet selectivo de UNA arista (menú adaptativo: tocar arista → redondear).
    /// API verificada @v1.8.8: `Shape.filleted(edges: [Edge], radius:) -> Shape?`.
    @discardableResult
    static func filletEdge(_ model: Model, edgeIndex: Int, radius: Double) -> Bool {
        filletEdges(model, edgeIndices: [edgeIndex], radius: radius)
    }

    /// Fillet de VARIAS aristas seleccionadas en UNA sola operación OCCT
    /// (barrido device 2026-07-11: con multi-selección solo se redondeaba la
    /// última). Una op conjunta también resuelve bien las esquinas compartidas.
    @discardableResult
    static func filletEdges(_ model: Model, edgeIndices: [Int], radius: Double) -> Bool {
        applyFeature(to: model) { shape in
            let all = shape.edges()
            guard !edgeIndices.isEmpty,
                  edgeIndices.allSatisfy({ $0 >= 0 && $0 < all.count }) else { return nil }
            return shape.filleted(edges: edgeIndices.map { all[$0] }, radius: radius)
        }
    }

    /// Chaflán de aristas seleccionadas (corte plano, distancia uniforme).
    /// Reemplaza el placebo de índices de malla hardcodeados (barrido 2026-07-11).
    /// API verificada @v1.8.8: `chamferedWithFullHistory(distance:, edges: [Int])`.
    @discardableResult
    static func chamferEdges(_ model: Model, edgeIndices: [Int], distance: Double) -> Bool {
        applyFeature(to: model) { shape in
            let count = shape.edges().count
            guard !edgeIndices.isEmpty,
                  edgeIndices.allSatisfy({ $0 >= 0 && $0 < count }) else { return nil }
            return shape.chamferedWithFullHistory(distance: distance,
                                                  edges: edgeIndices)?.result
        }
    }

    // MARK: - Transformaciones directas (Mover/Rotar/Escalar horneadas al B-rep)
    // Compuestas desde primitivas verificadas @v1.8.8 (translated/rotated/scaled);
    // rotated/scaled operan alrededor del ORIGEN → conjugar con traslaciones.

    /// Traslada el sólido (el B-rep es la fuente de verdad de la posición).
    @discardableResult
    static func translate(_ model: Model, by delta: SIMD3<Double>) -> Bool {
        applyFeature(to: model) { $0.translated(by: delta) }
    }

    /// Rota alrededor de un eje arbitrario que pasa por `center` (radianes).
    @discardableResult
    static func rotate(_ model: Model, axis: SIMD3<Double>, angle: Double,
                       center: SIMD3<Double>) -> Bool {
        applyFeature(to: model) { shape in
            shape.translated(by: -center)?
                .rotated(axis: axis, angle: angle)?
                .translated(by: center)
        }
    }

    /// Rota alrededor del eje Y que pasa por `center` (ángulo en radianes).
    @discardableResult
    static func rotateY(_ model: Model, angle: Double, center: SIMD3<Double>) -> Bool {
        rotate(model, axis: SIMD3<Double>(0, 1, 0), angle: angle, center: center)
    }

    /// AGUJERO perpendicular (herramienta estrella de Fusion que Shapr3D hace a
    /// mano): API drilled verificada @v1.8.8. depth 0 = PASANTE.
    @discardableResult
    static func drill(_ model: Model, at point: SIMD3<Double>,
                      direction: SIMD3<Double>, radius: Double,
                      depth: Double = 0) -> Bool {
        guard radius > 1e-9 else { return false }
        return applyFeature(to: model) {
            $0.drilled(at: point, direction: direction, radius: radius, depth: depth)
        }
    }

    /// Copia REFLEJADA a través de un plano (v1: YZ por el origen — el plano
    /// del eje azul de la grilla). Devuelve el cuerpo nuevo, no muta el original.
    static func mirroredCopy(of model: Model,
                             planeNormal: SIMD3<Double> = SIMD3<Double>(1, 0, 0),
                             planeOrigin: SIMD3<Double> = .zero) -> Model? {
        guard let shape = model.cadShape,
              let mirrored = shape.mirrored(planeNormal: planeNormal, planeOrigin: planeOrigin),
              let mesh = OCCTBridge.toMesh(mirrored, quality: .medium) else { return nil }
        let copy = Model(name: "\(model.name)_espejo")
        copy.cadShape = mirrored
        copy.meshes = [mesh]
        copy.edgesMesh = OCCTBridge.edgesMesh(mirrored)
        copy.color = model.color
        return copy
    }

    /// Patrón LINEAL: n−1 copias trasladadas a `spacing` a lo largo de `direction`.
    /// (Como en Shapr3D, las copias son cuerpos del árbol — editables después.)
    static func linearPattern(of model: Model, count: Int,
                              spacing: SIMD3<Double>) -> [Model] {
        guard count >= 2, let shape = model.cadShape else { return [] }
        var copies: [Model] = []
        for i in 1..<count {
            let offset = spacing * Double(i)
            guard let moved = shape.translated(by: offset),
                  let mesh = OCCTBridge.toMesh(moved, quality: .medium) else { continue }
            let copy = Model(name: "\(model.name)_p\(i)")
            copy.cadShape = moved
            copy.meshes = [mesh]
            copy.edgesMesh = OCCTBridge.edgesMesh(moved)
            copy.color = model.color
            copies.append(copy)
        }
        return copies
    }

    /// Patrón CIRCULAR: count−1 copias rotadas uniformemente 2π·i/count alrededor
    /// de `axisDirection` que pasa por `axisOrigin`. Mismo patrón que linearPattern
    /// pero con `rotated(axis:angle:)` verificada @v1.8.8. Las copias rotan
    /// alrededor del ORIGEN (la API opera sobre el origen) — usar axisOrigin=.zero
    /// para el caso típico (eje Y por el centro de la escena).
    static func circularPattern(of model: Model, count: Int,
                                axisOrigin: SIMD3<Double> = .zero,
                                axisDirection: SIMD3<Double> = SIMD3<Double>(0, 1, 0)) -> [Model] {
        guard count >= 2, let shape = model.cadShape else { return [] }
        let axis = simd_normalize(axisDirection)
        var copies: [Model] = []
        for i in 1..<count {
            let angle = 2 * Double.pi * Double(i) / Double(count)
            // rotated(axis:angle:) opera alrededor del ORIGEN — conjugar con traslaciones
            // si axisOrigin ≠ .zero (patrón estándar: T(-o)·R·T(o))
            let rotated: CADShape?
            if simd_length(axisOrigin) > 1e-9 {
                rotated = shape
                    .translated(by: -axisOrigin)?
                    .rotated(axis: axis, angle: angle)?
                    .translated(by: axisOrigin)
            } else {
                rotated = shape.rotated(axis: axis, angle: angle)
            }
            guard let rotShape = rotated,
                  let mesh = OCCTBridge.toMesh(rotShape, quality: .medium) else { continue }
            let copy = Model(name: "\(model.name)_c\(i)")
            copy.cadShape = rotShape
            copy.meshes = [mesh]
            copy.edgesMesh = OCCTBridge.edgesMesh(rotShape)
            copy.color = model.color
            copies.append(copy)
        }
        return copies
    }

    /// Escala uniforme alrededor de `center`.
    @discardableResult
    static func scaleUniform(_ model: Model, factor: Double, center: SIMD3<Double>) -> Bool {
        guard factor > 1e-6 else { return false }
        return applyFeature(to: model) { shape in
            shape.translated(by: -center)?
                .scaled(by: factor)?
                .translated(by: center)
        }
    }

    /// Vaciado del sólido con grosor de pared dado (B-rep real vía TKOffset).
    /// Un shell necesita al menos una cara abierta (igual que en Shapr3D);
    /// sin `openFaceIndex` explícito se abre la cara de mayor área.
    @discardableResult
    /// Vaciado con dirección: `outward: false` (default) quita material HACIA ADENTRO
    /// conservando el contorno exterior — lo esperado en CAD. La semántica OCCT es
    /// offset positivo = crece hacia afuera (bug device 2026-07-11: engrosaba afuera),
    /// así que adentro = thickness negativo.
    static func shell(_ model: Model, thickness: Double, openFaceIndex: Int? = nil,
                      outward: Bool = false) -> Bool {
        let signed = outward ? abs(thickness) : -abs(thickness)
        return applyFeature(to: model) { shape in
            let faces = shape.faces()
            let openFace: Face?
            if let idx = openFaceIndex, idx >= 0, idx < faces.count {
                openFace = faces[idx]
            } else {
                openFace = faces.max(by: { $0.area() < $1.area() })
            }
            guard let face = openFace else { return shape.shelled(thickness: signed) }
            return shape.shelled(thickness: signed, openFaces: [face])
        }
    }

    // MARK: - Push/Pull real (la operación insignia de Shapr3D)

    /// Push/pull de una cara vía BRepFeat prism (boss/pocket):
    /// `distance > 0` añade material extruyendo la cara hacia fuera;
    /// `distance < 0` quita material excavando hacia dentro.
    static func pushPullFace(_ shape: CADShape, faceIndex: Int, distance: Double) -> CADShape? {
        let faces = shape.faces()
        guard faceIndex >= 0, faceIndex < faces.count, abs(distance) > 1e-12,
              let normal = faces[faceIndex].normal,
              let wire = faces[faceIndex].outerWire else { return nil }
        let fuse = distance >= 0
        let direction = fuse ? normal : -normal
        return shape.withPrism(profile: wire, direction: direction,
                               height: abs(distance), fuse: fuse)
    }

    /// Índice de la primera cara plana cuya normal apunta (con tolerancia) en `direction`.
    static func faceIndex(of shape: CADShape, withNormal direction: SIMD3<Double>,
                          tolerance: Double = 1e-4) -> Int? {
        let target = simd_normalize(direction)
        return shape.faces().firstIndex { face in
            guard let n = face.normal else { return false }
            return simd_length(simd_normalize(n) - target) < tolerance
        }
    }

    // MARK: - Export STEP real (B-rep con fidelidad AP214)

    /// Exporta el B-rep del modelo a STEP real vía OCCT. Devuelve false si no hay B-rep
    /// (el caller decide el fallback al STEP sintetizado desde malla).
    static func exportSTEP(_ model: Model, to url: URL) -> Bool {
        guard let shape = model.cadShape else { return false }
        do {
            try Exporter.writeSTEP(shape: shape, to: url)
            return true
        } catch {
            logger.error("[BRep] STEP export falló: \(error.localizedDescription)")
            return false
        }
    }
}
