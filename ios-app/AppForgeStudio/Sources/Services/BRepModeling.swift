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
        applyFeature(to: model) { shape in
            let edges = shape.edges()
            guard edgeIndex >= 0, edgeIndex < edges.count else { return nil }
            return shape.filleted(edges: [edges[edgeIndex]], radius: radius)
        }
    }

    /// Vaciado del sólido con grosor de pared dado (B-rep real vía TKOffset).
    /// Un shell necesita al menos una cara abierta (igual que en Shapr3D);
    /// sin `openFaceIndex` explícito se abre la cara de mayor área.
    @discardableResult
    static func shell(_ model: Model, thickness: Double, openFaceIndex: Int? = nil) -> Bool {
        applyFeature(to: model) { shape in
            let faces = shape.faces()
            let openFace: Face?
            if let idx = openFaceIndex, idx >= 0, idx < faces.count {
                openFace = faces[idx]
            } else {
                openFace = faces.max(by: { $0.area() < $1.area() })
            }
            guard let face = openFace else { return shape.shelled(thickness: thickness) }
            return shape.shelled(thickness: thickness, openFaces: [face])
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
