import Foundation
import simd
import OCCTSwift
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "Sketch")

/// Sketch EN el viewport 3D sobre el plano de trabajo (v1: el piso, y=0),
/// como Shapr3D — no una pantalla 2D aparte. Entrada por TAPS (dedo y pencil):
/// línea = tap-tap-…-tap sobre el primer punto para cerrar; rectángulo =
/// esquina→esquina; círculo = centro→radio. El Pencil además dibuja EN VIVO
/// por drag. Los perfiles cerrados producen sólidos B-rep REALES
/// (Wire → Shape.extrude/revolve, verificados @v1.8.8).
@MainActor
final class SketchController: ObservableObject {

    enum Tool { case line, rectangle, circle, spline, polygon }

    enum Entity: Equatable {
        case polyline(points: [SIMD2<Float>], closed: Bool)
        case rect(a: SIMD2<Float>, b: SIMD2<Float>)
        case circle(center: SIMD2<Float>, radius: Float)
        /// Spline por puntos de control (curva ABIERTA — ruta para Tubo/Barrido).
        case spline(points: [SIMD2<Float>])
        /// Polígono regular N lados (perfil cerrado — extruible/revolucionable).
        case polygonEnt(center: SIMD2<Float>, radius: Float, sides: Int)

        var isClosedProfile: Bool {
            switch self {
            case .polyline(let pts, let closed): return closed && pts.count >= 3
            case .rect(let a, let b): return abs(a.x - b.x) > 1e-4 && abs(a.y - b.y) > 1e-4
            case .circle(_, let r): return r > 1e-4
            case .spline: return false
            case .polygonEnt(_, let r, let s): return r > 1e-4 && s >= 3
            }
        }

        /// Ruta abierta utilizable por Tubo/Barrido.
        var isOpenPath: Bool {
            switch self {
            case .polyline(let pts, false): return pts.count >= 2
            case .spline(let pts): return pts.count >= 2
            default: return false
            }
        }

        /// Vértices del polígono regular (y=0) para overlay y Wire.
        static func polygonVerts(center: SIMD2<Float>, radius: Float, sides: Int) -> [SIMD2<Float>] {
            (0..<sides).map { k in
                let t = Float(k) / Float(sides) * 2 * .pi - .pi / 2
                return center + SIMD2(cos(t), sin(t)) * radius
            }
        }
    }

    @Published private(set) var entities: [Entity] = []
    /// Cadena de líneas en curso (tap a tap).
    @Published private(set) var chain: [SIMD2<Float>] = []
    /// Ancla del gesto de 2 taps (rect: esquina A; círculo/polígono: centro).
    @Published private(set) var anchor: SIMD2<Float>? = nil
    /// Punto vivo bajo el dedo/pencil (preview).
    @Published var preview: SIMD2<Float>? = nil
    @Published private(set) var statusMessage = ""
    var activeTool: Tool = .line
    /// Número de lados del polígono (editable en sketchBar, rango 3-12).
    @Published var polygonSides: Int = 6

    static let snapRadius: Float = 0.14

    var hasClosedProfile: Bool { entities.contains { $0.isClosedProfile } }
    /// ¿Hay ruta abierta (spline/cadena) para Tubo/Barrido?
    var hasOpenPath: Bool { entities.contains { $0.isOpenPath } || chain.count >= 2 }
    /// ¿Hay DOS perfiles cerrados? (Transición/loft)
    var hasTwoProfiles: Bool { entities.filter { $0.isClosedProfile }.count >= 2 }
    /// Cadena de spline en curso (puntos de control tocados).
    @Published private(set) var splineChain: [SIMD2<Float>] = []

    /// Todos los puntos notables (snap): endpoints, esquinas, centros.
    private var snapPoints: [SIMD2<Float>] {
        var pts: [SIMD2<Float>] = chain
        for e in entities {
            switch e {
            case .polyline(let p, _): pts.append(contentsOf: p)
            case .rect(let a, let b):
                pts.append(contentsOf: [a, b, SIMD2(a.x, b.y), SIMD2(b.x, a.y)])
            case .circle(let c, _): pts.append(c)
            case .polygonEnt(let c, _, _): pts.append(c)
            case .spline: break
            }
        }
        return pts
    }

    func snap(_ p: SIMD2<Float>) -> SIMD2<Float> {
        for pt in snapPoints where simd_distance(pt, p) < Self.snapRadius { return pt }
        return p
    }

    // MARK: - Entrada por taps (dedo Y pencil)

    func tap(at raw: SIMD2<Float>) {
        let p = snap(raw)
        switch activeTool {
        case .line:
            if let first = chain.first, chain.count >= 3,
               simd_distance(p, first) < Self.snapRadius {
                // Tap sobre el primer punto = CERRAR el perfil
                entities.append(.polyline(points: chain, closed: true))
                chain = []
                statusMessage = "Perfil cerrado ✓ — extruye o revoluciona"
            } else {
                chain.append(p)
                statusMessage = chain.count == 1
                    ? "Sigue tocando; toca el primer punto para cerrar"
                    : "\(chain.count) puntos · toca el primero para cerrar"
            }
        case .rectangle:
            if let a = anchor {
                entities.append(.rect(a: a, b: p))
                anchor = nil
                statusMessage = "Rectángulo ✓ — extruye o revoluciona"
            } else {
                anchor = p
                statusMessage = "Toca la esquina opuesta"
            }
        case .circle:
            if let c = anchor {
                let r = simd_distance(c, p)
                if r > 1e-3 { entities.append(.circle(center: c, radius: r)) }
                anchor = nil
                statusMessage = "Círculo ✓ — extruye o revoluciona"
            } else {
                anchor = p
                statusMessage = "Toca un punto del radio"
            }
        case .spline:
            splineChain.append(p)
            statusMessage = splineChain.count < 2
                ? "Sigue añadiendo puntos de control"
                : "\(splineChain.count) puntos · «Fin spline» para confirmar"
        case .polygon:
            if let c = anchor {
                let r = simd_distance(c, p)
                if r > 1e-3 {
                    entities.append(.polygonEnt(center: c, radius: r, sides: polygonSides))
                }
                anchor = nil
                statusMessage = "Polígono ✓ — extruye o revoluciona"
            } else {
                anchor = p
                statusMessage = "Toca un vértice del radio"
            }
        }
        preview = nil
    }

    /// Confirma la spline en curso (curva abierta = ruta para Tubo).
    func finishSpline() {
        guard splineChain.count >= 2 else { return }
        entities.append(.spline(points: splineChain))
        splineChain = []
        statusMessage = "Spline ✓ — úsala como ruta de Tubo"
    }

    // MARK: - Trazo vivo con Pencil (drag = dibujar)

    func pencilDragBegan(at p: SIMD2<Float>) {
        if activeTool == .spline {
            splineChain = [snap(p)]
            preview = splineChain.first
            return
        }
        anchor = snap(p)
        preview = anchor
    }

    func pencilDragChanged(to p: SIMD2<Float>) {
        if activeTool == .spline {
            // El trazo del pencil siembra puntos de control cada ~0.35
            if let last = splineChain.last, simd_distance(last, p) > 0.35 {
                splineChain.append(p)
            }
            preview = p
            return
        }
        preview = snap(p)
    }

    func pencilDragEnded(at p: SIMD2<Float>) {
        if activeTool == .spline {
            splineChain.append(p)
            finishSpline()   // el trazo del pencil ES la spline: fluido
            preview = nil
            return
        }
        guard let a = anchor else { return }
        let end = snap(p)
        switch activeTool {
        case .line:
            if chain.isEmpty { chain = [a] }
            chain.append(end)
            statusMessage = "\(chain.count) puntos · toca el primero para cerrar"
        case .rectangle:
            entities.append(.rect(a: a, b: end))
            statusMessage = "Rectángulo ✓ — extruye o revoluciona"
        case .circle:
            let r = simd_distance(a, end)
            if r > 1e-3 { entities.append(.circle(center: a, radius: r)) }
            statusMessage = "Círculo ✓ — extruye o revoluciona"
        case .polygon:
            let r = simd_distance(a, end)
            if r > 1e-3 {
                entities.append(.polygonEnt(center: a, radius: r, sides: polygonSides))
            }
            statusMessage = "Polígono ✓ — extruye o revoluciona"
        case .spline:
            break
        }
        anchor = nil
        preview = nil
    }

    func undoLast() {
        if !splineChain.isEmpty { splineChain.removeLast() }
        else if !chain.isEmpty { chain.removeLast() }
        else if anchor != nil { anchor = nil }
        else if !entities.isEmpty { entities.removeLast() }
        preview = nil
    }

    func clear() {
        entities = []
        chain = []
        splineChain = []
        anchor = nil
        preview = nil
        statusMessage = ""
    }

    /// Establece un mensaje de ayuda visible en la sketchBar (usado por flujos externos
    /// como el botón Extruir del flyout cuando aún no hay perfil cerrado).
    func hint(_ s: String) { statusMessage = s }

    // MARK: - Plano ↔ mundo (v1: piso y=0; el eje de revolución es Z del mundo)

    func world(_ p: SIMD2<Float>) -> SIMD3<Float> { SIMD3(p.x, 0, p.y) }

    // MARK: - OCCT: perfil → sólido REAL

    private func wire(for entity: Entity, atHeight y: Double = 0) -> Wire? {
        switch entity {
        case .polyline(let pts, true):
            return Wire.polygon3D(pts.map { SIMD3<Double>(Double($0.x), y, Double($0.y)) },
                                  closed: true)
        case .rect(let a, let b):
            let corners = [a, SIMD2(b.x, a.y), b, SIMD2(a.x, b.y)]
            return Wire.polygon3D(corners.map { SIMD3<Double>(Double($0.x), y, Double($0.y)) },
                                  closed: true)
        case .circle(let c, let r):
            return Wire.circle(origin: SIMD3<Double>(Double(c.x), y, Double(c.y)),
                               normal: SIMD3<Double>(0, 1, 0),
                               radius: Double(r))
        case .polygonEnt(let c, let r, let sides):
            let verts = Entity.polygonVerts(center: c, radius: r, sides: sides)
            return Wire.polygon3D(verts.map { SIMD3<Double>(Double($0.x), y, Double($0.y)) },
                                  closed: true)
        default:
            return nil
        }
    }

    private func firstClosedWire() -> Wire? {
        for e in entities where e.isClosedProfile {
            if let w = wire(for: e) { return w }
        }
        return nil
    }

    // MARK: - Rutas abiertas (Tubo / Barrido)

    private func firstOpenPath() -> (points: [SIMD2<Float>], isSpline: Bool)? {
        for e in entities {
            if case .spline(let pts) = e, pts.count >= 2 { return (pts, true) }
            if case .polyline(let pts, false) = e, pts.count >= 2 { return (pts, false) }
        }
        if chain.count >= 2 { return (chain, false) }
        return nil
    }

    /// TUBO (plomería de cohete): círculo Ø barrido a lo largo de la ruta
    /// dibujada (spline o cadena). API sweep verificada @v1.8.8.
    func tubeAlongPath(radius: Double) -> Model? {
        guard radius > 1e-9, let (pts, isSpline) = firstOpenPath() else {
            statusMessage = "Dibuja una ruta abierta (spline o cadena) primero"
            return nil
        }
        let p3 = pts.map { SIMD3<Double>(Double($0.x), 0, Double($0.y)) }
        let path: Wire? = isSpline ? Wire.bspline(p3) : Wire.polygon3D(p3, closed: false)
        let start = p3[0]
        let dir3 = simd_normalize(p3[1] - p3[0])
        guard let pathW = path,
              let profile = Wire.circle(origin: start, normal: dir3, radius: radius),
              let shape = OCCTSwift.Shape.sweep(profile: profile, along: pathW),
              let mesh = OCCTBridge.toMesh(shape, quality: .medium) else {
            statusMessage = "No se pudo crear el tubo"
            return nil
        }
        let model = Model(name: "Tubo_\(UUID().uuidString.prefix(6))")
        model.cadShape = shape
        model.meshes = [mesh]
        model.edgesMesh = OCCTBridge.edgesMesh(shape)
        return model
    }

    /// TRANSICIÓN (loft): del 1er perfil cerrado (en el piso) al 2º perfil
    /// ELEVADO a `height` — conductos rect→círculo, campanas, etc.
    func loftProfiles(height: Double) -> Model? {
        let closed = entities.filter { $0.isClosedProfile }
        guard closed.count >= 2 else {
            statusMessage = "Dibuja DOS perfiles cerrados para la transición"
            return nil
        }
        guard height > 1e-9,
              let wA = wire(for: closed[0], atHeight: 0),
              let wB = wire(for: closed[1], atHeight: height),
              let shape = OCCTSwift.Shape.loft(profiles: [wA, wB], solid: true),
              let mesh = OCCTBridge.toMesh(shape, quality: .medium) else {
            statusMessage = "No se pudo crear la transición"
            return nil
        }
        let model = Model(name: "Transición_\(UUID().uuidString.prefix(6))")
        model.cadShape = shape
        model.meshes = [mesh]
        model.edgesMesh = OCCTBridge.edgesMesh(shape)
        return model
    }

    /// Extruye el primer perfil cerrado hacia arriba → Model con B-rep + aristas.
    func extrudeProfile(height: Double) -> Model? {
        guard height > 1e-9, let w = firstClosedWire(),
              let shape = OCCTSwift.Shape.extrude(profile: w,
                                                  direction: SIMD3<Double>(0, 1, 0),
                                                  length: height),
              let mesh = OCCTBridge.toMesh(shape, quality: .medium) else {
            statusMessage = "No se pudo extruir el perfil"
            return nil
        }
        let model = Model(name: "Extrusión_\(UUID().uuidString.prefix(6))")
        model.cadShape = shape
        model.meshes = [mesh]
        model.edgesMesh = OCCTBridge.edgesMesh(shape)
        return model
    }

    /// Revoluciona el primer perfil cerrado alrededor del eje Z del mundo
    /// (la línea x=0 del plano — dibuja el perfil a un lado del eje).
    func revolveProfile(angle: Double = .pi * 2) -> Model? {
        guard let w = firstClosedWire(),
              let shape = OCCTSwift.Shape.revolve(profile: w,
                                                  axisOrigin: .zero,
                                                  axisDirection: SIMD3<Double>(0, 0, 1),
                                                  angle: angle),
              let mesh = OCCTBridge.toMesh(shape, quality: .medium) else {
            statusMessage = "No se pudo revolucionar (¿el perfil cruza el eje?)"
            return nil
        }
        let model = Model(name: "Revolución_\(UUID().uuidString.prefix(6))")
        model.cadShape = shape
        model.meshes = [mesh]
        model.edgesMesh = OCCTBridge.edgesMesh(shape)
        return model
    }

    // MARK: - Overlay de render (tubos en vivo)

    /// Malla combinada del sketch para el overlay "__sketch" (tubos steel para
    /// lo confirmado; la cadena/preview va aparte en "__sketchLive", brasa).
    func overlayMesh() -> Mesh? {
        var v: [Vertex] = []
        var i: [UInt32] = []
        for e in entities { appendEntityTube(e, to: &v, indices: &i) }
        return v.isEmpty ? nil : Mesh(vertices: v, indices: i)
    }

    func liveOverlayMesh() -> Mesh? {
        var v: [Vertex] = []
        var i: [UInt32] = []
        if chain.count >= 2 {
            GizmoBuilder.appendTube(polyline: chain.map(world), radius: 0.02,
                                    to: &v, indices: &i)
        }
        // Segmento vivo: último punto de la cadena (o ancla) → preview
        if let p = preview {
            let from: SIMD2<Float>? = chain.last ?? anchor
            if let f = from, simd_distance(f, p) > 1e-4 {
                switch activeTool {
                case .line:
                    GizmoBuilder.appendTube(polyline: [world(f), world(p)], radius: 0.02,
                                            to: &v, indices: &i)
                case .rectangle:
                    let corners = [f, SIMD2(p.x, f.y), p, SIMD2(f.x, p.y), f]
                    GizmoBuilder.appendTube(polyline: corners.map(world), radius: 0.02,
                                            to: &v, indices: &i)
                case .circle:
                    appendCircleTube(center: f, radius: simd_distance(f, p),
                                     to: &v, indices: &i)
                case .polygon:
                    let r = simd_distance(f, p)
                    let pts = Entity.polygonVerts(center: f, radius: r, sides: polygonSides)
                    var line = pts.map(world)
                    if let first = line.first { line.append(first) }
                    GizmoBuilder.appendTube(polyline: line, radius: 0.02, to: &v, indices: &i)
                case .spline:
                    break
                }
            }
        }
        // Marcar puntos de la cadena y el ancla (cubitos táctiles)
        for p in chain { appendPointMarker(p, to: &v, indices: &i) }
        if let a = anchor { appendPointMarker(a, to: &v, indices: &i) }
        return v.isEmpty ? nil : Mesh(vertices: v, indices: i)
    }

    private func appendEntityTube(_ e: Entity, to v: inout [Vertex], indices i: inout [UInt32]) {
        switch e {
        case .polyline(let pts, let closed):
            var line = pts.map(world)
            if closed, let f = line.first { line.append(f) }
            GizmoBuilder.appendTube(polyline: line, radius: 0.02, to: &v, indices: &i)
        case .rect(let a, let b):
            let corners = [a, SIMD2(b.x, a.y), b, SIMD2(a.x, b.y), a]
            GizmoBuilder.appendTube(polyline: corners.map(world), radius: 0.02,
                                    to: &v, indices: &i)
        case .circle(let c, let r):
            appendCircleTube(center: c, radius: r, to: &v, indices: &i)
        case .polygonEnt(let c, let r, let sides):
            let pts = Entity.polygonVerts(center: c, radius: r, sides: sides)
            var line = pts.map(world)
            if let f = line.first { line.append(f) }
            GizmoBuilder.appendTube(polyline: line, radius: 0.02, to: &v, indices: &i)
        case .spline:
            break
        }
    }

    private func appendCircleTube(center: SIMD2<Float>, radius: Float,
                                  to v: inout [Vertex], indices i: inout [UInt32]) {
        guard radius > 1e-4 else { return }
        var pts: [SIMD3<Float>] = []
        for k in 0...48 {
            let t = Float(k) / 48 * 2 * .pi
            pts.append(world(center + SIMD2(cos(t), sin(t)) * radius))
        }
        GizmoBuilder.appendTube(polyline: pts, radius: 0.02, to: &v, indices: &i)
    }

    private func appendPointMarker(_ p: SIMD2<Float>, to v: inout [Vertex], indices i: inout [UInt32]) {
        let w = world(p)
        let s: Float = 0.045
        GizmoBuilder.appendTube(polyline: [w - SIMD3<Float>(0, 0, s), w + SIMD3<Float>(0, 0, s)],
                                radius: s, to: &v, indices: &i)
    }
}
