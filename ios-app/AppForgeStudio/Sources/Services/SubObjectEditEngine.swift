import Foundation
import simd
import OCCTSwift
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "SubObjectEdit")

/// Edición directa de SUB-OBJETOS del B-rep: escalar el contorno de una cara,
/// mover una arista/vértice — la op de modelado directo que Shapr3D hace y que es
/// la queja #1 del usuario ("selecciono la arista de la base y la escalo").
///
/// CONTRATO de la Tanda A (`docs/SUPREMACIA_HOLISTICA.md §4`). El engine SIEMPRE
/// existe y compila para que G1 (capa de vista) pueda llamarlo sin referencia
/// colgante. Devolver `nil` NO es un placebo: es el estado HONESTO "OCCT no soporta
/// esto aún para esta cara/arista" → la UI muestra estado real, cero botón falso
/// (regla dura del repo).
///
/// `CADShape` = `OCCTSwift.Shape` (typealias en `Sources/CSG/Shape.swift`).
///
/// ─────────────────────────────────────────────────────────────────────────────
/// HALLAZGOS DEL SPIKE — OCCTSwift v1.8.8 (clon pineado, verificado archivo:línea)
/// ─────────────────────────────────────────────────────────────────────────────
/// Editar sub-objetos de un B-rep ARBITRARIO se apoya en estas primitivas REALES:
///  • `Shape.replacingSubShapes([(old:new:)]) -> Shape?`     Shape.swift:5432 (BRepTools_ReShape)
///  • `Shape.substituted(replacing:with:) -> Shape?`         Shape.swift:7669 (BRepTools_Substitution)
///  • `Face.outerWire -> Wire?`                              Face.swift:40
///  • `Wire.orderedEdgePoints(at:maxPoints:) -> [SIMD3<Double>]?`  Wire.swift:1187 (BRepTools_WireExplorer)
///  • `Wire.orderedEdgeCount`                                Wire.swift:1162
///  • `Wire.polygon3D(_:closed:) -> Wire?`                   Wire.swift:158 (BRepBuilderAPI_MakePolygon)
///  • `Shape.face(from:planar:) -> Shape?`                   Shape.swift:1275
///  • `Shape.loft(profiles:solid:ruled:...) -> Shape?`       Shape.swift:479 (BRepOffsetAPI_ThruSections)
///  • `Shape.scaledAboutPoint(_:factor:) -> Shape?`          Shape.swift:7336 (uniforme 3D, NO en-plano)
///  • `Shape.offsetPerFace(defaultOffset:faceOffsets:) -> Shape?`  Shape.swift:5130 (mueve cara ⟂ su normal = push/pull)
///  • `Shape.static offsetWire(face:offset:) -> Shape?`      Shape.swift:7495 (BRepFill_OffsetWire, offset ≠ escala)
///  • `Shape.isValidSolid: Bool`  Shape.swift:1716  ·  `isValid` :747  ·  `centroid` :12838
///
/// LÍMITE DURO ENCONTRADO: NO existe wrap de una edición de sub-objeto que
/// re-ajuste las SUPERFICIES vecinas al mover una arista/vértice. `replacingSubShapes`
/// / `substituted` son BRepTools_ReShape: intercambian HANDLES de topología, no
/// re-fitean las caras laterales que comparten la arista movida → el sólido queda
/// no-manifold / auto-intersectado. No hay `BRepTools_Modifier` con un
/// GTransform por-vértice, ni `LocOpe`/`BRepFeat` que mueva un vértice, ni
/// `moveFace`, expuestos en v1.8.8. Por eso `moveEdge`/`moveVertex` = `nil` honesto.
///
/// Lo que SÍ es factible y de alto valor (la queja #1 literal, "base más ancha"):
/// escalar el contorno de una cara PLANAR de un sólido PRISMÁTICO reconstruyendo
/// el sólido por LOFT entre el aro opuesto (sin tocar) y el aro escalado. Eso da un
/// sólido cerrado VÁLIDO (verificado con `isValidSolid`), no una cáscara rota.
enum SubObjectEditEngine {

    // MARK: - Escalar el contorno de una cara (queja #1: "hacer la base más ancha")

    /// Escala el outer wire de una cara planar en su plano, sobre su centroide, y
    /// reconstruye el sólido. `nil` si OCCT no lo soporta para esa cara.
    ///
    /// Estrategia REAL (v1.8.8): sólo para sólidos PRISMÁTICOS de tapa poligonal
    /// (caja, prisma extruido) — el caso que el usuario toca al escalar "la base".
    /// 1. Extrae los vértices ordenados del outer wire de la cara objetivo y de su
    ///    cara OPUESTA (normal anti-paralela, mismo nº de vértices).
    /// 2. Escala los vértices de la cara objetivo en su plano sobre el centroide de
    ///    la cara (`p' = c + factor·(p − c)`), dejando la cara opuesta intacta.
    /// 3. Reconstruye el sólido por LOFT (ThruSections) entre ambos aros.
    /// Gate de honestidad: si no hay cara opuesta poligonal compatible, o el loft no
    /// produce un sólido válido, devuelve `nil` (→ G1 no ofrece el botón).
    ///
    /// - Note: no re-usa las caras laterales originales (imposible sin un modifier de
    ///   sub-objeto en OCCTSwift v1.8.8); las regenera limpiamente vía loft. Para
    ///   sólidos no prismáticos, la solución definitiva es editar el PERFIL
    ///   paramétrico del sketch (Tanda B), no el B-rep horneado.
    static func scaleFaceWire(_ shape: CADShape, faceIndex: Int, factor: Double) -> CADShape? {
        let faces = shape.faces()
        guard faceIndex >= 0, faceIndex < faces.count,
              factor > 1e-6, abs(factor - 1.0) > 1e-9 else { return nil }

        let target = faces[faceIndex]
        guard target.isPlanar,
              let targetNormal = target.normal,
              let targetCorners = orderedCorners(of: target),
              targetCorners.count >= 3 else { return nil }

        // Cara opuesta: planar, normal anti-paralela, MISMO nº de vértices (prisma).
        let n = simd_normalize(targetNormal)
        var oppositeCorners: [SIMD3<Double>]? = nil
        for i in 0..<faces.count where i != faceIndex {
            let f = faces[i]
            guard f.isPlanar, let fn = f.normal,
                  simd_dot(simd_normalize(fn), n) < -0.999 else { continue }  // anti-paralela
            guard let corners = orderedCorners(of: f),
                  corners.count == targetCorners.count else { continue }
            oppositeCorners = corners
            break
        }
        guard let oppositeCorners else { return nil }

        // Escalar los vértices de la cara objetivo en su plano, sobre su centroide.
        // (El centroide de la cara está en su plano; escalar 3D sobre él con la cara
        // planar equivale a escalar en-plano — el componente normal es 0 para todos.)
        let c = faceCentroid(targetCorners)
        let scaledCorners = targetCorners.map { c + factor * ($0 - c) }

        // Coherencia de bobinado: los outer wires de ambas caras están orientados por
        // sus normales OPUESTAS, así que se recorren en sentidos contrarios respecto al
        // eje del loft `n`. Un ThruSections con perfiles de bobinado opuesto se retuerce
        // / auto-intersecta → alinear el aro opuesto al mismo sentido que el objetivo.
        // El aro objetivo (tapa) se recorre con normal ≈ +n. Forzar que el aro
        // opuesto tenga el MISMO sentido (normal ≈ +n) para que el loft no se retuerza.
        var bottomCorners = oppositeCorners
        if simd_dot(polygonNormal(bottomCorners), n) < 0 {
            bottomCorners.reverse()
        }

        guard let topWire = Wire.polygon3D(scaledCorners, closed: true),
              let bottomWire = Wire.polygon3D(bottomCorners, closed: true) else { return nil }

        // LOFT reglado (ruled) = caras laterales planas, coherentes con un prisma.
        guard let solid = CADShape.loft(profiles: [bottomWire, topWire],
                                        solid: true, ruled: true),
              solid.isValidSolid else {
            logger.info("[SubObj] scaleFaceWire: loft no dio sólido válido (cara \(faceIndex))")
            return nil
        }
        return solid
    }

    // MARK: - Mover arista / vértice (NO factible en OCCTSwift v1.8.8 — nil honesto)

    /// Traslada una arista y estira las caras adyacentes (press-pull de arista).
    /// `nil` — NO factible con la superficie de OCCTSwift v1.8.8.
    ///
    /// POR QUÉ: mover una arista exige re-ajustar (re-fit) las superficies de las
    /// dos caras que la comparten para que sigan pasando por la arista nueva. Las
    /// únicas cirugías de sub-objeto expuestas en v1.8.8 son `BRepTools_ReShape`
    /// (`replacingSubShapes` Shape.swift:5432) y `BRepTools_Substitution`
    /// (`substituted` Shape.swift:7669): AMBAS intercambian handles topológicos sin
    /// re-fitear las caras vecinas → sólido no-manifold / auto-intersectado. No hay
    /// wrap de `BRepTools_Modifier`/`BRepTools_NurbsConvert` con un GTransform
    /// por-arista, ni de un `LocOpe`/`BRepFeat` de arrastre de arista.
    ///
    /// ALTERNATIVA (siembra de la solución definitiva): para prismas, el press-pull
    /// de arista de la base se puede modelar como un `scaleFaceWire` no-uniforme
    /// (escala 1D del aro) — extensión natural de la ruta loft de arriba. Para el
    /// caso general, la vía correcta es editar el PERFIL paramétrico del sketch
    /// (Tanda B: variables/expresiones), no el B-rep horneado.
    static func moveEdge(_ shape: CADShape, edgeIndex: Int, delta: SIMD3<Double>) -> CADShape? {
        return nil
    }

    /// Traslada un vértice del B-rep. `nil` — NO factible en OCCTSwift v1.8.8.
    ///
    /// POR QUÉ: idéntico límite que `moveEdge`. Arrastrar un vértice mueve todas las
    /// aristas incidentes y obliga a re-fitear cada cara incidente. `BRepTools_ReShape`
    /// (`replacingSubShapes`/`substituted`) sólo cambia handles de topología, no la
    /// geometría de las caras vecinas → resultado inválido. OCCTSwift v1.8.8 no
    /// expone un modificador de vértice (BRepTools_Modifier / GTransform por-vértice).
    ///
    /// ALTERNATIVA: editar el perfil paramétrico (Tanda B). Para verificar la
    /// dirección: `Shape.vertices() -> [SIMD3<Double>]` (Shape.swift:2215) sí lista
    /// los vértices, pero no hay op de escritura que los desplace re-fiteando caras.
    static func moveVertex(_ shape: CADShape, vertexIndex: Int, delta: SIMD3<Double>) -> CADShape? {
        return nil
    }

    // MARK: - Helpers puros (geometría, sin efectos)

    /// Vértices/esquinas del outer wire de una cara, EN ORDEN de recorrido.
    /// Toma el primer punto de cada arista ordenada (`BRepTools_WireExplorer`), que
    /// para un aro cerrado son exactamente las esquinas en secuencia conectada.
    private static func orderedCorners(of face: Face) -> [SIMD3<Double>]? {
        guard let wire = face.outerWire else { return nil }
        let edgeCount = wire.orderedEdgeCount
        guard edgeCount >= 3 else { return nil }
        var corners: [SIMD3<Double>] = []
        corners.reserveCapacity(edgeCount)
        for i in 0..<edgeCount {
            guard let pts = wire.orderedEdgePoints(at: i, maxPoints: 2),
                  let first = pts.first else { return nil }
            corners.append(first)
        }
        return corners
    }

    /// Centroide (media aritmética) de las esquinas — para un polígono planar cae en
    /// su plano, así que escalar sobre él es escala EN-PLANO exacta.
    private static func faceCentroid(_ corners: [SIMD3<Double>]) -> SIMD3<Double> {
        guard !corners.isEmpty else { return .zero }
        var sum = SIMD3<Double>.zero
        for p in corners { sum += p }
        return sum / Double(corners.count)
    }

    /// Normal del polígono por el sentido de recorrido (método de Newell — robusto
    /// para cualquier polígono planar, no depende de la convexidad). El sentido
    /// (signo) codifica el bobinado: se usa para alinear los dos aros del loft.
    private static func polygonNormal(_ pts: [SIMD3<Double>]) -> SIMD3<Double> {
        guard pts.count >= 3 else { return .zero }
        var nrm = SIMD3<Double>.zero
        for i in 0..<pts.count {
            let a = pts[i]
            let b = pts[(i + 1) % pts.count]
            nrm.x += (a.y - b.y) * (a.z + b.z)
            nrm.y += (a.z - b.z) * (a.x + b.x)
            nrm.z += (a.x - b.x) * (a.y + b.y)
        }
        return nrm
    }
}
