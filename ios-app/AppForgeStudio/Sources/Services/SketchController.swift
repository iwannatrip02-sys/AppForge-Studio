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

    enum Tool { case line, rectangle, circle }

    enum Entity: Equatable {
        case polyline(points: [SIMD2<Float>], closed: Bool)
        case rect(a: SIMD2<Float>, b: SIMD2<Float>)
        case circle(center: SIMD2<Float>, radius: Float)

        var isClosedProfile: Bool {
            switch self {
            case .polyline(let pts, let closed): return closed && pts.count >= 3
            case .rect(let a, let b): return abs(a.x - b.x) > 1e-4 && abs(a.y - b.y) > 1e-4
            case .circle(_, let r): return r > 1e-4
            }
        }
    }

    @Published private(set) var entities: [Entity] = []
    /// Cadena de líneas en curso (tap a tap).
    @Published private(set) var chain: [SIMD2<Float>] = []
    /// Ancla del gesto de 2 taps (rect: esquina A; círculo: centro).
    @Published private(set) var anchor: SIMD2<Float>? = nil
    /// Punto vivo bajo el dedo/pencil (preview).
    @Published var preview: SIMD2<Float>? = nil
    @Published private(set) var statusMessage = ""
    var activeTool: Tool = .line

    static let snapRadius: Float = 0.14

    var hasClosedProfile: Bool { entities.contains { $0.isClosedProfile } }

    /// Todos los puntos notables (snap): endpoints, esquinas, centros.
    private var snapPoints: [SIMD2<Float>] {
        var pts: [SIMD2<Float>] = chain
        for e in entities {
            switch e {
            case .polyline(let p, _): pts.append(contentsOf: p)
            case .rect(let a, let b):
                pts.append(contentsOf: [a, b, SIMD2(a.x, b.y), SIMD2(b.x, a.y)])
            case .circle(let c, _): pts.append(c)
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
        }
        preview = nil
    }

    // MARK: - Trazo vivo con Pencil (drag = dibujar)

    func pencilDragBegan(at p: SIMD2<Float>) {
        anchor = snap(p)
        preview = anchor
    }

    func pencilDragChanged(to p: SIMD2<Float>) {
        preview = snap(p)
    }

    func pencilDragEnded(at p: SIMD2<Float>) {
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
        }
        anchor = nil
        preview = nil
    }

    func undoLast() {
        if !chain.isEmpty { chain.removeLast() }
        else if anchor != nil { anchor = nil }
        else if !entities.isEmpty { entities.removeLast() }
        preview = nil
    }

    func clear() {
        entities = []
        chain = []
        anchor = nil
        preview = nil
        statusMessage = ""
    }

    // MARK: - Plano ↔ mundo (v1: piso y=0; el eje de revolución es Z del mundo)

    func world(_ p: SIMD2<Float>) -> SIMD3<Float> { SIMD3(p.x, 0, p.y) }

    // MARK: - OCCT: perfil → sólido REAL

    private func wire(for entity: Entity) -> Wire? {
        switch entity {
        case .polyline(let pts, true):
            return Wire.polygon3D(pts.map { SIMD3<Double>(Double($0.x), 0, Double($0.y)) },
                                  closed: true)
        case .rect(let a, let b):
            let corners = [a, SIMD2(b.x, a.y), b, SIMD2(a.x, b.y)]
            return Wire.polygon3D(corners.map { SIMD3<Double>(Double($0.x), 0, Double($0.y)) },
                                  closed: true)
        case .circle(let c, let r):
            return Wire.circle(origin: SIMD3<Double>(Double(c.x), 0, Double(c.y)),
                               normal: SIMD3<Double>(0, 1, 0),
                               radius: Double(r))
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
