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

    /// Plano de trabajo arbitrario (origin, u, v, normal) — como Shapr3D dibujar
    /// SOBRE una cara. v1 por defecto = el piso (y=0). Los puntos 2D del boceto
    /// se mapean a 3D con `origin + u·x + v·y`; la extrusión va a lo largo de `normal`.
    struct WorkPlane: Equatable {
        var origin: SIMD3<Float> = .zero
        var u: SIMD3<Float> = SIMD3(1, 0, 0)   // eje X local
        var v: SIMD3<Float> = SIMD3(0, 0, 1)   // eje Y local
        var normal: SIMD3<Float> = SIMD3(0, 1, 0)
        static let floor = WorkPlane()
    }
    @Published var plane: WorkPlane = .floor

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

        /// Centro (o punto medio) de la entidad — usado para selección/edición.
        var center: SIMD2<Float> {
            switch self {
            case .polyline(let pts, _):
                guard !pts.isEmpty else { return .zero }
                return pts.reduce(.zero, +) / Float(pts.count)
            case .rect(let a, let b): return (a + b) * 0.5
            case .circle(let c, _): return c
            case .spline(let pts):
                guard !pts.isEmpty else { return .zero }
                return pts.reduce(.zero, +) / Float(pts.count)
            case .polygonEnt(let c, _, _): return c
            }
        }

        /// Puntos notables (centro + vértices) para el picking de selección.
        var pickPoints: [SIMD2<Float>] {
            switch self {
            case .polyline(let pts, _): return pts + [center]
            case .rect(let a, let b):
                return [a, b, SIMD2(a.x, b.y), SIMD2(b.x, a.y), center]
            case .circle(let c, _): return [c]
            case .spline(let pts): return pts + [center]
            case .polygonEnt(let c, let r, let s):
                return Entity.polygonVerts(center: c, radius: r, sides: s) + [c]
            }
        }

        /// Distancia mínima del punto `p` al CONTORNO de la entidad (anillo del
        /// círculo, lados del rect/polígono, segmentos de la cadena/spline). Es
        /// lo que permite seleccionar tocando la figura, no solo su centro.
        func distanceToOutline(_ p: SIMD2<Float>) -> Float {
            func segDist(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
                let ab = b - a
                let len2 = simd_dot(ab, ab)
                if len2 < 1e-12 { return simd_distance(p, a) }
                let t = max(0, min(1, simd_dot(p - a, ab) / len2))
                return simd_distance(p, a + ab * t)
            }
            func polyDist(_ pts: [SIMD2<Float>], closed: Bool) -> Float {
                guard pts.count >= 2 else { return pts.first.map { simd_distance(p, $0) } ?? .greatestFiniteMagnitude }
                var best = Float.greatestFiniteMagnitude
                for i in 0..<(pts.count - 1) { best = min(best, segDist(pts[i], pts[i + 1])) }
                if closed { best = min(best, segDist(pts[pts.count - 1], pts[0])) }
                return best
            }
            switch self {
            case .circle(let c, let r):
                return abs(simd_distance(p, c) - r)   // distancia al anillo
            case .rect(let a, let b):
                let corners = [a, SIMD2(b.x, a.y), b, SIMD2(a.x, b.y)]
                return polyDist(corners, closed: true)
            case .polygonEnt(let c, let r, let s):
                return polyDist(Entity.polygonVerts(center: c, radius: r, sides: s), closed: true)
            case .polyline(let pts, let closed):
                return polyDist(pts, closed: closed)
            case .spline(let pts):
                return polyDist(pts, closed: false)
            }
        }

        /// Nombre legible por tipo para el panel de Elementos (TAREA 4).
        var displayName: String {
            switch self {
            case .circle(_, let r): return String(format: "Círculo R %.2f", r)
            case .rect(let a, let b):
                return String(format: "Rect %.1f×%.1f", abs(b.x - a.x), abs(b.y - a.y))
            case .spline(let pts): return "Spline (\(pts.count))"
            case .polygonEnt(_, _, let s): return "Polígono \(s)L"
            case .polyline(let pts, _): return "Cadena (\(pts.count))"
            }
        }

        /// Icono SF Symbols por tipo (panel de Elementos).
        var iconName: String { "scribble" }

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

    /// Entidad seleccionada para editar sus parámetros (TAREA 3). nil = ninguna.
    @Published var selectedEntityIndex: Int? = nil

    var hasClosedProfile: Bool { entities.contains { $0.isClosedProfile } }
    /// ¿Hay ruta abierta (spline/cadena) para Tubo/Barrido?
    var hasOpenPath: Bool { entities.contains { $0.isOpenPath } || chain.count >= 2 }
    /// ¿Hay un área cerrada (perfil de una entidad, O región por intersección de
    /// segmentos) que se pueda extruir? El botón Extruir se guía por esto.
    var hasExtrudableArea: Bool {
        if hasClosedProfile { return true }
        return SketchRegionDetector.detectRegions(in: entities, chain: chain)
            .contains { abs($0.area) > 1e-4 }
    }
    /// ¿Hay DOS perfiles cerrados? (Transición/loft)
    var hasTwoProfiles: Bool { entities.filter { $0.isClosedProfile }.count >= 2 }
    /// Cadena de spline en curso (puntos de control tocados).
    @Published private(set) var splineChain: [SIMD2<Float>] = []

    // MARK: - Constraint solving (Newton-Raphson en vivo)

    /// Solver 2D integrado: restricciones geométricas en tiempo real durante el boceto.
    private let constraintSolver = SolverSwift()
    /// Restricciones activas (inferidas + manuales).
    @Published var activeConstraints: [GeometryConstraint] = []
    /// Si está activo, cada nueva entidad dispara inferencia + solve.
    @Published var autoConstrain: Bool = true

    // MARK: - Gizmo de sketch (arrastrar puntos)

    /// Estado del gizmo de arrastre de puntos de sketch.
    enum DragState: Equatable {
        case inactive
        case dragging(entityIndex: Int, pointIndex: Int, startPosition: SIMD2<Float>)
    }
    @Published var dragState: DragState = .inactive

    /// True mientras se arrastra un punto/vértice existente (no un trazo nuevo).
    var isDraggingPoint: Bool {
        if case .dragging = dragState { return true }
        return false
    }

    /// Intenta iniciar arrastre de un punto cercano a `position`.
    /// Retorna true si encontró un punto y comenzó el drag.
    func beginDrag(near position: SIMD2<Float>) -> Bool {
        let radius = Self.snapRadius * 2.0
        var bestEntity: Int?
        var bestPoint: Int?
        var bestDist: Float = .greatestFiniteMagnitude

        for (ei, entity) in entities.enumerated() {
            let pts = entityPoints(for: entity)
            for (pi, pt) in pts.enumerated() {
                let d = simd_distance(pt, position)
                if d < radius && d < bestDist {
                    bestDist = d
                    bestEntity = ei
                    bestPoint = pi
                }
            }
        }

        // También buscar en la cadena activa
        for (ci, pt) in chain.enumerated() {
            let d = simd_distance(pt, position)
            if d < radius && d < bestDist {
                bestDist = d
                bestEntity = -1  // código especial: cadena
                bestPoint = ci
            }
        }

        if let ei = bestEntity, let pi = bestPoint, bestDist < radius {
            if ei == -1 {
                dragState = .dragging(entityIndex: -1, pointIndex: pi,
                                      startPosition: chain[pi])
            } else {
                let pts = entityPoints(for: entities[ei])
                guard pi < pts.count else { return false }
                dragState = .dragging(entityIndex: ei, pointIndex: pi,
                                      startPosition: pts[pi])
            }
            statusMessage = "Arrastra para ajustar"
            return true
        }
        return false
    }

    /// Mueve el punto arrastrado a una nueva posición.
    func drag(to position: SIMD2<Float>) {
        guard case .dragging(let ei, let pi, _) = dragState else { return }
        let snapped = snap(position)

        if ei == -1 && pi < chain.count {
            chain[pi] = snapped
        } else if ei >= 0, ei < entities.count {
            moveEntityPoint(entityIndex: ei, pointIndex: pi, to: snapped)
        }
        preview = position
    }

    /// Finaliza el arrastre y re-resuelve constraints.
    func endDrag() {
        dragState = .inactive
        preview = nil
        if autoConstrain {
            inferConstraints()
            resolveConstraints()
        }
        statusMessage = entities.contains(where: { $0.isClosedProfile })
            ? "Perfil cerrado ✓ — extruye o revoluciona"
            : ""
    }

    /// Extrae todos los puntos editables de una entidad
    private func entityPoints(for entity: Entity) -> [SIMD2<Float>] {
        switch entity {
        case .polyline(let pts, _): return pts
        case .rect(let a, let b): return [a, b, SIMD2(b.x, a.y), SIMD2(a.x, b.y)]
        case .circle(let c, _): return [c]
        case .polygonEnt(let c, let r, let s):
            return [c] + Entity.polygonVerts(center: c, radius: r, sides: s)
        case .spline(let pts): return pts
        }
    }

    /// Mueve un punto específico de una entidad a una nueva posición
    private func moveEntityPoint(entityIndex: Int, pointIndex: Int, to newPos: SIMD2<Float>) {
        guard entityIndex >= 0, entityIndex < entities.count else { return }
        let entity = entities[entityIndex]

        switch entity {
        case .polyline(var pts, let closed):
            guard pointIndex < pts.count else { return }
            pts[pointIndex] = newPos
            entities[entityIndex] = .polyline(points: pts, closed: closed)

        case .rect(let a, let b):
            // Las 4 esquinas (orden de entityPoints): 0=a, 1=b, 2=(b.x,a.y), 3=(a.x,b.y).
            // Mover cualquiera reforma el rect ajustando solo los ejes de esa esquina.
            switch pointIndex {
            case 0: entities[entityIndex] = .rect(a: newPos, b: b)
            case 1: entities[entityIndex] = .rect(a: a, b: newPos)
            case 2: entities[entityIndex] = .rect(a: SIMD2(a.x, newPos.y), b: SIMD2(newPos.x, b.y))
            case 3: entities[entityIndex] = .rect(a: SIMD2(newPos.x, a.y), b: SIMD2(b.x, newPos.y))
            default: break
            }

        case .circle(_, let r):
            if pointIndex == 0 {
                entities[entityIndex] = .circle(center: newPos, radius: r)
            }

        case .polygonEnt(_, let r, let s):
            if pointIndex == 0 {
                entities[entityIndex] = .polygonEnt(center: newPos, radius: r, sides: s)
            } else {
                // Mover vértice: recalcular radio desde el centro
                let center = entity.center
                let newRadius = simd_distance(center, newPos)
                entities[entityIndex] = .polygonEnt(center: center,
                                                     radius: max(1e-3, newRadius),
                                                     sides: s)
            }

        case .spline(var pts):
            guard pointIndex < pts.count else { return }
            pts[pointIndex] = newPos
            entities[entityIndex] = .spline(points: pts)
        }
    }

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
        // Editar entidad existente: solo el CENTRO selecciona mientras hay
        // herramienta de dibujo activa — los vértices son targets de snap para
        // seguir dibujando (mecánica Shapr3D: dibujar tiene prioridad).
        if chain.isEmpty, anchor == nil, splineChain.isEmpty {
            if selectEntity(near: p, centersOnly: true) {
                preview = nil
                return
            }
        }
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
        selectedEntityIndex = nil
        activeConstraints = []
        dragState = .inactive
        statusMessage = ""
    }

    /// Establece un mensaje de ayuda visible en la sketchBar (usado por flujos externos
    /// como el botón Extruir del flyout cuando aún no hay perfil cerrado).
    func hint(_ s: String) { statusMessage = s }

    // MARK: - Selección y edición de entidades (TAREA 3)

    /// Selecciona la entidad tocando su CONTORNO (anillo del círculo, lados,
    /// segmentos) o su centro/vértices, a < tolerancia de `p`. Con `centersOnly`
    /// (mientras se dibuja) solo mira el centro, para no secuestrar el inicio de
    /// una figura nueva sobre un vértice existente (fix del loft).
    /// Si ninguna, deselecciona y devuelve false (el tap sigue su curso normal).
    @discardableResult
    func selectEntity(near p: SIMD2<Float>, centersOnly: Bool = false) -> Bool {
        let radius = Self.snapRadius * 1.5
        var best: (idx: Int, dist: Float)?
        for (i, e) in entities.enumerated() {
            let d: Float
            if centersOnly {
                d = simd_distance(e.center, p)
            } else {
                // Contorno O centro O vértices: lo que esté más cerca.
                let dOutline = e.distanceToOutline(p)
                let dPoints = e.pickPoints.map { simd_distance($0, p) }.min() ?? .greatestFiniteMagnitude
                d = min(dOutline, dPoints)
            }
            if d < radius, d < (best?.dist ?? .greatestFiniteMagnitude) {
                best = (i, d)
            }
        }
        if let hit = best {
            selectedEntityIndex = hit.idx
            statusMessage = "Entidad seleccionada — edita sus parámetros"
            return true
        }
        selectedEntityIndex = nil
        return false
    }

    func deselectEntity() {
        selectedEntityIndex = nil
    }

    /// Elimina la entidad seleccionada (o la de `index`).
    func deleteEntity(at index: Int? = nil) {
        let i = index ?? selectedEntityIndex
        guard let i = i, i >= 0, i < entities.count else { return }
        entities.remove(at: i)
        selectedEntityIndex = nil
        statusMessage = "Entidad eliminada"
    }

    /// Selecciona la fila del panel de Elementos.
    func selectEntity(at index: Int) {
        guard index >= 0, index < entities.count else { return }
        selectedEntityIndex = index
    }

    // ---- Edición in-situ (reemplaza la entidad en el array) ----

    private func replaceSelected(_ transform: (Entity) -> Entity?) {
        guard let i = selectedEntityIndex, i >= 0, i < entities.count,
              let updated = transform(entities[i]) else { return }
        entities[i] = updated
    }

    /// Radio de la entidad seleccionada (círculo/polígono), o nil.
    var selectedRadius: Float? {
        guard let i = selectedEntityIndex, i >= 0, i < entities.count else { return nil }
        switch entities[i] {
        case .circle(_, let r): return r
        case .polygonEnt(_, let r, _): return r
        default: return nil
        }
    }

    /// Lados de la entidad seleccionada (polígono), o nil.
    var selectedSides: Int? {
        guard let i = selectedEntityIndex, i >= 0, i < entities.count else { return nil }
        if case .polygonEnt(_, _, let s) = entities[i] { return s }
        return nil
    }

    /// Ancho/alto del rectángulo seleccionado, o nil.
    var selectedRectSize: (w: Float, h: Float)? {
        guard let i = selectedEntityIndex, i >= 0, i < entities.count else { return nil }
        if case .rect(let a, let b) = entities[i] {
            return (abs(b.x - a.x), abs(b.y - a.y))
        }
        return nil
    }

    func editSelectedRadius(_ r: Float) {
        replaceSelected { e in
            switch e {
            case .circle(let c, _): return .circle(center: c, radius: max(1e-3, r))
            case .polygonEnt(let c, _, let s): return .polygonEnt(center: c, radius: max(1e-3, r), sides: s)
            default: return nil
            }
        }
    }

    func editSelectedSides(_ sides: Int) {
        replaceSelected { e in
            if case .polygonEnt(let c, let r, _) = e {
                return .polygonEnt(center: c, radius: r, sides: max(3, min(12, sides)))
            }
            return nil
        }
    }

    /// Reescala el rect manteniendo la esquina `a`; `b` se recalcula desde a + (w,h).
    func editSelectedRectSize(w: Float, h: Float) {
        replaceSelected { e in
            if case .rect(let a, let b) = e {
                let sx: Float = b.x >= a.x ? 1 : -1
                let sy: Float = b.y >= a.y ? 1 : -1
                return .rect(a: a, b: SIMD2(a.x + sx * max(1e-3, w), a.y + sy * max(1e-3, h)))
            }
            return nil
        }
    }

    // MARK: - Plano ↔ mundo (plano arbitrario; el piso es el caso por defecto)

    /// Punto 2D del boceto → mundo 3D sobre el plano de trabajo activo.
    func world(_ p: SIMD2<Float>) -> SIMD3<Float> {
        plane.origin + plane.u * p.x + plane.v * p.y
    }

    /// Restaura el plano al piso (y=0).
    func resetPlaneToFloor() {
        plane = .floor
        statusMessage = "Plano de boceto: suelo"
    }

    // MARK: - OCCT: perfil → sólido REAL

    /// Punto 2D del boceto → mundo 3D, elevado `height` a lo largo de la normal
    /// del plano (para el loft, el 2º perfil sube por la normal, no por Y global).
    private func world3(_ p: SIMD2<Float>, height: Double) -> SIMD3<Double> {
        let w = world(p) + plane.normal * Float(height)
        return SIMD3<Double>(Double(w.x), Double(w.y), Double(w.z))
    }

    private func wire(for entity: Entity, atHeight y: Double = 0) -> Wire? {
        let n = SIMD3<Double>(Double(plane.normal.x), Double(plane.normal.y), Double(plane.normal.z))
        switch entity {
        case .polyline(let pts, true):
            return Wire.polygon3D(pts.map { world3($0, height: y) }, closed: true)
        case .rect(let a, let b):
            let corners = [a, SIMD2(b.x, a.y), b, SIMD2(a.x, b.y)]
            return Wire.polygon3D(corners.map { world3($0, height: y) }, closed: true)
        case .circle(let c, let r):
            return Wire.circle(origin: world3(c, height: y), normal: n, radius: Double(r))
        case .polygonEnt(let c, let r, let sides):
            let verts = Entity.polygonVerts(center: c, radius: r, sides: sides)
            return Wire.polygon3D(verts.map { world3($0, height: y) }, closed: true)
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
        let p3 = pts.map { world3($0, height: 0) }
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
        let dir = SIMD3<Double>(Double(plane.normal.x), Double(plane.normal.y), Double(plane.normal.z))
        guard height > 1e-9, let w = firstClosedWire(),
              let shape = OCCTSwift.Shape.extrude(profile: w,
                                                  direction: dir,
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

    // MARK: - Regiones → 3D (F4, issue #15)

    /// Extruye una REGIÓN cerrada (área formada por la intersección de varios
    /// segmentos, no un perfil de una sola entidad) a partir de sus vértices 2D
    /// en el plano de trabajo. Mismo constructor de wire que `extrudeProfile`.
    func extrudeRegion(vertices: [SIMD2<Float>], height: Double) -> Model? {
        guard height > 1e-9, vertices.count >= 3 else {
            statusMessage = "Región inválida para extruir"
            return nil
        }
        let p3 = vertices.map { world3($0, height: 0) }
        let dir = SIMD3<Double>(Double(plane.normal.x), Double(plane.normal.y), Double(plane.normal.z))
        guard let w = Wire.polygon3D(p3, closed: true),
              let shape = OCCTSwift.Shape.extrude(profile: w, direction: dir, length: height),
              let mesh = OCCTBridge.toMesh(shape, quality: .medium) else {
            statusMessage = "No se pudo extruir la región"
            return nil
        }
        let model = Model(name: "Región_\(UUID().uuidString.prefix(6))")
        model.cadShape = shape
        model.meshes = [mesh]
        model.edgesMesh = OCCTBridge.edgesMesh(shape)
        return model
    }

    /// Extruye la región cerrada que contiene el punto tocado — para tocar un
    /// área sombreada (formada por líneas que se cruzan) y volverla 3D.
    func extrudeRegion(at point: SIMD2<Float>, height: Double) -> Model? {
        // Agnóstico al sentido de trazado (winding): la región válida es la que
        // CONTIENE el punto; si varias, la de mayor área (el contorno exterior).
        let regions = SketchRegionDetector.detectRegions(in: entities, chain: chain)
        let containing = regions.filter { SketchRegionDetector.polygonContains($0.vertices, point) }
        let hit = containing.max { abs($0.area) < abs($1.area) }
            ?? regions.min { simd_distance($0.centroid, point) < simd_distance($1.centroid, point) }
        guard let region = hit else {
            statusMessage = "No hay región cerrada bajo el toque"
            return nil
        }
        return extrudeRegion(vertices: region.vertices, height: height)
    }

    /// Extruye el área cerrada disponible: primero un perfil de entidad; si no
    /// hay, la región de mayor área formada por intersección de segmentos. Es lo
    /// que usa el botón «Extruir» para que las áreas de dibujos funcionen.
    func extrudeClosedArea(height: Double) -> Model? {
        if let m = extrudeProfile(height: height) { return m }
        let regions = SketchRegionDetector.detectRegions(in: entities, chain: chain)
        guard let region = regions.max(by: { abs($0.area) < abs($1.area) }),
              abs(region.area) > 1e-4 else {
            statusMessage = "No hay área cerrada para extruir"
            return nil
        }
        return extrudeRegion(vertices: region.vertices, height: height)
    }

    /// Revoluciona el primer perfil cerrado. En el piso: eje Z del mundo (la línea
    /// x=0 del plano — dibuja el perfil a un lado del eje). En un plano sobre cara:
    /// el eje es la línea que pasa por el origen del plano con dirección `plane.v`
    /// (el eje Y local del plano de trabajo).
    func revolveProfile(angle: Double = .pi * 2) -> Model? {
        let axisOrigin: SIMD3<Double>
        let axisDir: SIMD3<Double>
        if plane == .floor {
            axisOrigin = .zero
            axisDir = SIMD3<Double>(0, 0, 1)
        } else {
            axisOrigin = SIMD3<Double>(Double(plane.origin.x), Double(plane.origin.y), Double(plane.origin.z))
            axisDir = SIMD3<Double>(Double(plane.v.x), Double(plane.v.y), Double(plane.v.z))
        }
        guard let w = firstClosedWire(),
              let shape = OCCTSwift.Shape.revolve(profile: w,
                                                  axisOrigin: axisOrigin,
                                                  axisDirection: axisDir,
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

    // MARK: - Constraint solving (Newton-Raphson integrado)

    /// Extrae todos los puntos notables de las entidades para alimentar el solver.
    private func collectSolverPoints() -> [(id: UUID, position: SIMD2<Float>)] {
        var pts: [(UUID, SIMD2<Float>)] = []
        for (i, e) in entities.enumerated() {
            switch e {
            case .polyline(let polyPts, _):
                for (j, p) in polyPts.enumerated() {
                    pts.append((UUID.from(hash: "poly_\(i)_\(j)"), p))
                }
            case .rect(let a, let b):
                pts.append((UUID.from(hash: "rect_\(i)_a"), a))
                pts.append((UUID.from(hash: "rect_\(i)_b"), b))
            case .circle(let c, _):
                pts.append((UUID.from(hash: "circle_\(i)"), c))
            case .polygonEnt(let c, _, _):
                pts.append((UUID.from(hash: "poly_\(i)"), c))
            case .spline(let splinePts):
                for (j, p) in splinePts.enumerated() {
                    pts.append((UUID.from(hash: "spline_\(i)_\(j)"), p))
                }
            }
        }
        for (j, p) in chain.enumerated() {
            pts.append((UUID.from(hash: "chain_\(j)"), p))
        }
        return pts
    }

    /// Infiere restricciones geométricas entre entidades basado en proximidad y geometría.
    func inferConstraints() {
        guard autoConstrain else { return }
        activeConstraints.removeAll()
        let pts = collectSolverPoints()
        guard pts.count >= 2 else { return }

        let angleTol: Float = 3.0 * .pi / 180.0
        let distTol: Float = 0.15
        let lenRatioTol: Float = 0.03

        // Segmentos reales: cada tramo de polilínea/cadena, no solo extremos.
        // (La cadena en curso también infiere — el usuario ve los badges al dibujar.)
        var segments: [(SIMD2<Float>, SIMD2<Float>)] = []
        for e in entities {
            switch e {
            case .polyline(let polyPts, let closed) where polyPts.count >= 2:
                for k in 0..<(polyPts.count - 1) { segments.append((polyPts[k], polyPts[k + 1])) }
                if closed && polyPts.count >= 3 { segments.append((polyPts.last!, polyPts.first!)) }
            case .rect(let a, let b):
                segments.append((a, b))
            default: break
            }
        }
        if chain.count >= 2 {
            for k in 0..<(chain.count - 1) { segments.append((chain[k], chain[k + 1])) }
        }
        segments.removeAll { simd_distance($0.0, $0.1) < 1e-5 }

        for i in 0..<segments.count {
            for j in (i+1)..<segments.count {
                let (a1, a2) = segments[i]
                let (b1, b2) = segments[j]
                let dirA = simd_normalize(a2 - a1)
                let dirB = simd_normalize(b2 - b1)
                let dot = abs(simd_dot(dirA, dirB))
                let angle = acos(min(max(dot, -1), 1))

                let lenA = simd_distance(a1, a2)
                let lenB = simd_distance(b1, b2)

                // NOTA: paralelas detectadas NO se agregan al solver — ConstraintType
                // aún no tiene .parallel y forzar .perpendicular rompería la geometría.
                if abs(angle - .pi / 2) < angleTol {
                    activeConstraints.append(GeometryConstraint(
                        type: .perpendicular, entityIDs: [],
                        value: 90, label: "Perpendicular"
                    ))
                }

                let lenRatio = abs(lenA - lenB) / max(lenA, lenB)
                if lenRatio < lenRatioTol {
                    activeConstraints.append(GeometryConstraint(
                        type: .equal, entityIDs: [],
                        value: lenA, label: "Igual longitud"
                    ))
                }
            }
        }

        // Buscar puntos coincidentes (cercanos)
        for i in 0..<pts.count {
            for j in (i+1)..<pts.count {
                let dist = simd_distance(pts[i].position, pts[j].position)
                if dist < distTol && dist > 1e-5 {
                    activeConstraints.append(GeometryConstraint(
                        type: .distance, entityIDs: [pts[i].id, pts[j].id],
                        value: 0, label: "Coincidente"
                    ))
                }
            }
        }

        // Detectar segmentos horizontales/verticales
        for (i, seg) in segments.enumerated() {
            let dir = simd_normalize(seg.1 - seg.0)
            if abs(dir.x) < angleTol {
                activeConstraints.append(GeometryConstraint(
                    type: .vertical, entityIDs: [UUID.from(hash: "seg_\(i)")],
                    label: "Vertical"
                ))
            } else if abs(dir.y) < angleTol {
                activeConstraints.append(GeometryConstraint(
                    type: .horizontal, entityIDs: [UUID.from(hash: "seg_\(i)")],
                    label: "Horizontal"
                ))
            }
        }
        // Un rectángulo es H+V por construcción (sus lados son axis-aligned)
        for (i, e) in entities.enumerated() {
            if case .rect = e {
                activeConstraints.append(GeometryConstraint(
                    type: .horizontal, entityIDs: [UUID.from(hash: "ent_\(i)")],
                    label: "Horizontal"
                ))
                activeConstraints.append(GeometryConstraint(
                    type: .vertical, entityIDs: [UUID.from(hash: "ent_\(i)")],
                    label: "Vertical"
                ))
            }
        }

        if !activeConstraints.isEmpty {
            statusMessage = "\(activeConstraints.count) restricciones inferidas"
        }
    }

    /// Resuelve las constraints activas con Newton-Raphson, ajustando posiciones.
    func resolveConstraints() {
        guard !activeConstraints.isEmpty else { return }
        let pts = collectSolverPoints()
        guard pts.count >= 2 else { return }

        constraintSolver.clear()

        // Alimentar puntos al solver (primeros 2 fijos como referencia)
        for (i, pt) in pts.enumerated() {
            let sp = SolverPoint(
                id: pt.id,
                x: Double(pt.position.x),
                y: Double(pt.position.y),
                isFixed: i < 2
            )
            constraintSolver.addPoint(sp)
        }

        // Traducir GeometryConstraint → SolverConstraint
        for gc in activeConstraints {
            guard let sc = bridgeConstraint(gc, points: pts) else { continue }
            constraintSolver.addConstraint(sc)
        }

        let result = constraintSolver.solve()

        if result.converged {
            // Escribir posiciones ajustadas de vuelta a las entidades
            applySolverResult(result)
            logger.info("SketchController: constraints solved in \(result.iterations) iter, residual=\(result.residual)")
        }
    }

    /// Traduce una GeometryConstraint genérica a un SolverConstraint concreto.
    private func bridgeConstraint(_ gc: GeometryConstraint,
                                   points: [(UUID, SIMD2<Float>)]) -> SolverConstraint? {
        let ids = gc.entityIDs
        switch gc.type {
        case .horizontal:
            guard let id = ids.first else { return nil }
            return SolverConstraint(id: gc.id,
                type: .horizontal(pointID: id), weight: 1.0)
        case .vertical:
            guard let id = ids.first else { return nil }
            return SolverConstraint(id: gc.id,
                type: .vertical(pointID: id), weight: 1.0)
        case .distance:
            guard ids.count >= 2 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .distance(pointA: ids[0], pointB: ids[1],
                               value: Double(gc.value ?? 10)),
                weight: 1.0)
        case .perpendicular:
            guard ids.count >= 4 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .perpendicular(lineAStart: ids[0], lineAEnd: ids[1],
                                    lineBStart: ids[2], lineBEnd: ids[3]),
                weight: 1.0)
        case .equal:
            guard ids.count >= 4 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .equal(pointA: ids[0], pointB: ids[1],
                            pointC: ids[2], pointD: ids[3]),
                weight: 1.0)
        case .angle:
            guard ids.count >= 3 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .angle(pointA: ids[0], pointB: ids[1], pointC: ids[2],
                            value: Double(gc.value ?? 45)),
                weight: 1.0)
        case .midpoint:
            guard ids.count >= 3 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .midpoint(pointA: ids[0], pointB: ids[1], pointMid: ids[2]),
                weight: 1.0)
        case .collinear:
            guard ids.count >= 3 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .collinear(pointA: ids[0], pointB: ids[1], pointC: ids[2]),
                weight: 1.0)
        case .tangent:
            guard ids.count >= 2 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .tangent(center: ids[0], point: ids[1],
                              radius: Double(gc.value ?? 1)),
                weight: 1.0)
        case .concentric:
            guard ids.count >= 2 else { return nil }
            return SolverConstraint(id: gc.id,
                type: .coincident(pointA: ids[0], pointB: ids[1]),
                weight: 1.0)
        }
    }

    /// Aplica el resultado del solver a las entidades del sketch.
    private func applySolverResult(_ result: SolverResult) {
        // Reconstruir: mapear puntos ajustados → entidades
        var adjustedPts: [UUID: SIMD2<Float>] = [:]
        for sp in result.points {
            adjustedPts[sp.id] = SIMD2<Float>(Float(sp.x), Float(sp.y))
        }

        // Actualizar entidades con posiciones ajustadas
        for (i, e) in entities.enumerated() {
            switch e {
            case .polyline(let polyPts, let closed):
                let newPts = polyPts.enumerated().map { (j, _) in
                    adjustedPts[UUID.from(hash: "poly_\(i)_\(j)")] ?? polyPts[j]
                }
                entities[i] = .polyline(points: newPts, closed: closed)
            case .rect(_, let b):
                let a = adjustedPts[UUID.from(hash: "rect_\(i)_a")] ??
                    (entities[i].center - SIMD2<Float>(abs(b.x - entities[i].center.x), abs(b.y - entities[i].center.y)))
                let newB = adjustedPts[UUID.from(hash: "rect_\(i)_b")] ?? b
                entities[i] = .rect(a: a, b: newB)
            case .circle(_, let r):
                let c = adjustedPts[UUID.from(hash: "circle_\(i)")] ?? entities[i].center
                entities[i] = .circle(center: c, radius: r)
            case .polygonEnt(_, let r, let s):
                let c = adjustedPts[UUID.from(hash: "poly_\(i)")] ?? entities[i].center
                entities[i] = .polygonEnt(center: c, radius: r, sides: s)
            case .spline(var pts):
                for (j, _) in pts.enumerated() {
                    if let adj = adjustedPts[UUID.from(hash: "spline_\(i)_\(j)")] {
                        pts[j] = adj
                    }
                }
                entities[i] = .spline(points: pts)
            }
        }
    }
}

// MARK: - UUID helper para hashing determinístico

extension UUID {
    /// Genera un UUID determinístico a partir de un string hash.
    static func from(hash: String) -> UUID {
        let data = hash.data(using: .utf8) ?? Data()
        var bytes = [UInt8](repeating: 0, count: 16)
        for (i, byte) in data.prefix(16).enumerated() { bytes[i] = byte }
        // Usar sha256-like simple: xor con posición para variar
        for i in 0..<min(16, data.count) {
            bytes[i] = data[i] ^ UInt8(i & 0xFF)
        }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
