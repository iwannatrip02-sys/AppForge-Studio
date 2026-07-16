import Foundation
import simd
import OCCTSwift
import OSLog
import SketchKernel

private let logger = Logger(subsystem: "com.appforgestudio", category: "Sketch")

// MARK: - Conversión frontera kernel (Double) ↔ app (Float)

extension Vec2 {
    init(_ s: SIMD2<Float>) { self.init(Double(s.x), Double(s.y)) }
    var simd: SIMD2<Float> { SIMD2<Float>(Float(x), Float(y)) }
}

/// Sketch EN el viewport 3D sobre el plano de trabajo, como Shapr3D.
/// FASE 1 (docs/FASE_1_DIBUJO_CONTRATO.md): reescrito sobre SketchKernel —
/// topología conectada (una esquina = UN punto), snap e inferencia con guías
/// visibles, hit-testing real (tocar un trazo lo selecciona) y regiones
/// cerradas robustas. Este controlador es el ADAPTADOR entre la UI (gestos y
/// render) y el kernel puro; el puente OCCT (extruir/revolucionar/tubo/loft)
/// vive aquí igual que antes.
@MainActor
final class SketchController: ObservableObject {

    // MARK: - Plano de trabajo (sin cambios)

    /// Plano de trabajo arbitrario (origin, u, v, normal) — como Shapr3D dibujar
    /// SOBRE una cara. v1 por defecto = el piso (y=0).
    struct WorkPlane: Equatable {
        var origin: SIMD3<Float> = .zero
        var u: SIMD3<Float> = SIMD3(1, 0, 0)
        var v: SIMD3<Float> = SIMD3(0, 0, 1)
        var normal: SIMD3<Float> = SIMD3(0, 1, 0)
        static let floor = WorkPlane()
    }
    @Published var plane: WorkPlane = .floor

    enum Tool { case line, rectangle, circle, arc, spline, polygon }

    // MARK: - Estado del kernel

    /// El documento de sketch (tipo valor — undo = pila de copias).
    @Published private(set) var model = SketchModel(mergeTolerance: 1e-3)
    /// Regiones cerradas cacheadas (se recalculan al mutar el modelo).
    @Published private(set) var regions: [SketchKernel.SketchRegion] = []

    private var undoStack: [SketchModel] = []
    private let snapEngine = SnapEngine()
    private let hitTester = HitTester()

    /// Radio de snap en unidades del plano. La UI puede reducirlo con Pencil.
    static let snapRadius: Float = 0.14

    // MARK: - Estado de dibujo en curso

    /// Cadena de líneas en curso: posición del último punto confirmado
    /// (referencia para guías H/V) y el primero (para cerrar).
    private(set) var chainLast: Vec2? = nil
    private(set) var chainStart: Vec2? = nil
    private(set) var chainCount: Int = 0
    /// Ancla del gesto de 2 taps (rect: esquina A; círculo/polígono: centro;
    /// arco: centro→inicio→fin usa además `arcStart`).
    @Published private(set) var anchor: SIMD2<Float>? = nil
    private var arcStart: Vec2? = nil
    /// Puntos de la spline en curso.
    @Published private(set) var splineDraft: [SIMD2<Float>] = []
    /// Modo de la spline (los DOS de Shapr3D). La UI podrá alternarlo.
    @Published var splineMode: SplineMode = .throughPoints

    // MARK: - Feedback visual (lo dibuja SketchCanvasOverlay)

    /// Marcador de snap activo: dónde se enganchó y por qué.
    @Published private(set) var snapMarker: (position: SIMD2<Float>, kind: SnapKind)? = nil
    /// Guías de inferencia activas (punteadas), como segmentos listos de dibujar.
    @Published private(set) var guideSegments: [(a: SIMD2<Float>, b: SIMD2<Float>)] = []
    /// Polilínea de preview de la figura en curso (sigue el dedo).
    @Published private(set) var previewPolyline: [SIMD2<Float>] = []
    /// Punto vivo bajo el dedo/pencil.
    @Published var preview: SIMD2<Float>? = nil

    @Published private(set) var statusMessage = ""
    @Published var activeTool: Tool = .line
    @Published var polygonSides: Int = 6

    /// Bump en cada mutación del modelo — CADModeView reconstruye overlays.
    @Published private(set) var revision: Int = 0

    // MARK: - Selección

    /// Curva seleccionada (tocar un trazo lo selecciona — Fase 1 §4).
    @Published var selectedCurveID: CurveID? = nil
    /// Vértices de la región cerrada seleccionada por tap (nil = ninguna).
    @Published private(set) var selectedRegion: [SIMD2<Float>]? = nil

    // MARK: - Compatibilidad con la UI existente

    /// Curvas en orden de dibujo (panel de Elementos, overlay).
    var entities: [SketchCurve] { model.orderedCurves }

    /// Puntos de la cadena en curso (compat con onChange de la UI).
    var chain: [SIMD2<Float>] {
        var pts: [SIMD2<Float>] = []
        if let s = chainStart { pts.append(s.simd) }
        if chainCount > 0, let l = chainLast { pts.append(l.simd) }
        return pts
    }

    var splineChain: [SIMD2<Float>] { splineDraft }

    /// Índice de la curva seleccionada en `entities` (panel de Elementos).
    var selectedEntityIndex: Int? {
        get {
            guard let id = selectedCurveID else { return nil }
            return model.curveOrder.firstIndex(of: id)
        }
        set {
            if let idx = newValue, idx >= 0, idx < model.curveOrder.count {
                selectedCurveID = model.curveOrder[idx]
                statusMessage = "Entidad seleccionada — edita o elimina"
            } else {
                selectedCurveID = nil
            }
        }
    }

    var hasClosedProfile: Bool { !regions.isEmpty }
    var hasExtrudableArea: Bool { !regions.isEmpty }
    var hasTwoProfiles: Bool { regions.count >= 2 }
    /// Ruta abierta utilizable por Tubo: HOY solo splines (regla anti-placebo:
    /// el botón solo aparece si tubeAlongPath puede cumplir).
    var hasOpenPath: Bool {
        model.orderedCurves.contains { if case .spline = $0.kind { return true } else { return false } }
    }

    // MARK: - Snap

    /// Consulta de snap para el cursor, publicando marcador y guías.
    @discardableResult
    private func snap(_ raw: SIMD2<Float>, reference: Vec2? = nil,
                      excludePoints: Set<PointID> = []) -> SnapResult {
        let ctx = SnapContext(cursor: Vec2(raw),
                              radius: Double(Self.snapRadius),
                              referencePoint: reference,
                              excludedPoints: excludePoints)
        let result = snapEngine.snap(ctx, in: model)
        publishFeedback(result)
        return result
    }

    private func publishFeedback(_ result: SnapResult) {
        if result.kind == .none {
            snapMarker = nil
        } else {
            snapMarker = (result.position.simd, result.kind)
        }
        // Guías como segmentos largos centrados en su punto de paso
        let ext = 12.0
        guideSegments = result.guides.map { g in
            ((g.through - g.direction * ext).simd, (g.through + g.direction * ext).simd)
        }
    }

    private func clearFeedback() {
        snapMarker = nil
        guideSegments = []
        previewPolyline = []
        preview = nil
    }

    /// Distancia al punto topológico más cercano — decide la prioridad del
    /// gesto (ajuste fino vs. región vs. trazo), igual que antes.
    func nearestEditablePointDistance(to p: SIMD2<Float>) -> Float? {
        var best = Double.greatestFiniteMagnitude
        let c = Vec2(p)
        for (_, pos) in model.positions { best = min(best, pos.distance(to: c)) }
        return best == .greatestFiniteMagnitude ? nil : Float(best)
    }

    // MARK: - Mutación con undo

    private func mutate(_ body: (inout SketchModel) -> Void) {
        undoStack.append(model)
        if undoStack.count > 64 { undoStack.removeFirst() }
        body(&model)
        modelDidChange()
    }

    private func modelDidChange() {
        regions = RegionFinder.regions(in: model)
        revision += 1
    }

    // MARK: - Herramientas (taps)

    /// Selecciona herramienta EMPEZANDO LIMPIO (bug de device: sin esto una
    /// línea nueva continuaba desde el punto anterior).
    func beginTool(_ tool: Tool) {
        cancelDrafts()
        activeTool = tool
        statusMessage = ""
    }

    private func cancelDrafts() {
        chainLast = nil; chainStart = nil; chainCount = 0
        anchor = nil; arcStart = nil
        splineDraft = []
        selectedCurveID = nil
        draggedPoint = nil
        clearFeedback()
    }

    private var isDrafting: Bool {
        chainLast != nil || anchor != nil || !splineDraft.isEmpty || arcStart != nil
    }

    /// ¿Hay una figura a medio dibujar? La UI no debe robar el tap/drag para
    /// seleccionar regiones mientras se dibuja.
    var isDrawingInProgress: Bool { isDrafting }

    func tap(at raw: SIMD2<Float>) {
        // Sin dibujo en curso: tocar un trazo/punto existente lo SELECCIONA;
        // tocar dentro de una región la selecciona (drag desde adentro extruye).
        // El radio de punto es ESTRECHO para no robar el inicio de una figura.
        if !isDrafting {
            let hit = hitTester.hitTest(at: Vec2(raw), in: model,
                                        pointRadius: Double(Self.snapRadius) * 0.8,
                                        curveRadius: Double(Self.snapRadius) * 0.6,
                                        regions: regions)
            switch hit {
            case .curve(let id, _):
                selectedCurveID = id
                selectedRegion = nil
                statusMessage = "Trazo seleccionado — edita o elimina"
                clearFeedback()
                return
            case .region(let region):
                selectedRegion = region.polygon.map { $0.simd }
                selectedCurveID = nil
                statusMessage = "Región seleccionada — arrastra desde adentro para extruir"
                clearFeedback()
                return
            case .point, .none:
                // Un punto bajo el dedo NO selecciona al dibujar: es target de
                // snap para seguir construyendo (dibujar tiene prioridad).
                break
            }
            if selectedCurveID != nil || selectedRegion != nil {
                // Tap en vacío deselecciona
                selectedCurveID = nil
                selectedRegion = nil
                statusMessage = ""
                return
            }
        }

        switch activeTool {
        case .line: tapLine(raw)
        case .rectangle: tapRectangle(raw)
        case .circle: tapCircle(raw)
        case .arc: tapArc(raw)
        case .spline: tapSpline(raw)
        case .polygon: tapPolygon(raw)
        }
        preview = nil
    }

    private func tapLine(_ raw: SIMD2<Float>) {
        let s = snap(raw, reference: chainLast)
        let p = s.position

        if let start = chainStart, chainCount >= 2,
           p.distance(to: start) < Double(Self.snapRadius) {
            // Tap sobre el primer punto = CERRAR el perfil
            if let last = chainLast {
                mutate { $0.addLine(from: last, to: start) }
            }
            chainLast = nil; chainStart = nil; chainCount = 0
            clearFeedback()
            statusMessage = "Perfil cerrado ✓ — tócalo y arrastra para extruir"
            return
        }

        if let last = chainLast {
            guard p.distance(to: last) > 1e-6 else { return }
            mutate { $0.addLine(from: last, to: p) }
            chainCount += 1
            chainLast = p
            statusMessage = "\(chainCount + 1) puntos · toca el primero para cerrar"
        } else {
            chainStart = p
            chainLast = p
            chainCount = 0
            statusMessage = "Sigue tocando; toca el primer punto para cerrar"
        }
    }

    private func tapRectangle(_ raw: SIMD2<Float>) {
        let p = snap(raw, reference: anchor.map { Vec2($0) }).position
        if let a = anchor {
            commitRectangle(from: Vec2(a), to: p)
            anchor = nil
            clearFeedback()
        } else {
            anchor = p.simd
            statusMessage = "Toca la esquina opuesta"
        }
    }

    /// Rect = 4 LÍNEAS con esquinas compartidas: topología real — las 4
    /// esquinas quedan arrastrables y los lados seleccionables por separado.
    private func commitRectangle(from a: Vec2, to b: Vec2) {
        guard abs(a.x - b.x) > 1e-6, abs(a.y - b.y) > 1e-6 else {
            statusMessage = "Rectángulo degenerado — toca dos esquinas distintas"
            return
        }
        mutate { m in
            let c1 = a, c2 = Vec2(b.x, a.y), c3 = b, c4 = Vec2(a.x, b.y)
            m.addLine(from: c1, to: c2)
            m.addLine(from: c2, to: c3)
            m.addLine(from: c3, to: c4)
            m.addLine(from: c4, to: c1)
        }
        statusMessage = "Rectángulo ✓ — tócalo y arrastra para extruir"
    }

    private func tapCircle(_ raw: SIMD2<Float>) {
        let p = snap(raw, reference: anchor.map { Vec2($0) }).position
        if let c = anchor {
            let r = p.distance(to: Vec2(c))
            if r > 1e-3 {
                mutate { $0.addCircle(center: Vec2(c), radius: r) }
                statusMessage = "Círculo ✓ — tócalo y arrastra para extruir"
            }
            anchor = nil
            clearFeedback()
        } else {
            anchor = p.simd
            statusMessage = "Toca un punto del radio"
        }
    }

    private func tapArc(_ raw: SIMD2<Float>) {
        let p = snap(raw, reference: arcStart ?? anchor.map { Vec2($0) }).position
        if let c = anchor.map({ Vec2($0) }), let s = arcStart {
            // Tercer tap: fin. Sentido = el barrido menor.
            let v1 = s - c, v2 = p - c
            let ccw = v1.cross(v2) > 0
            mutate { $0.addArc(center: c, start: s, end: p, ccw: ccw) }
            anchor = nil; arcStart = nil
            clearFeedback()
            statusMessage = "Arco ✓"
        } else if let _ = anchor {
            arcStart = p
            statusMessage = "Toca el punto final del arco"
        } else {
            anchor = p.simd
            statusMessage = "Toca el punto inicial del arco"
        }
    }

    private func tapSpline(_ raw: SIMD2<Float>) {
        let p = snap(raw, reference: splineDraft.last.map { Vec2($0) }).position
        splineDraft.append(p.simd)
        statusMessage = splineDraft.count < 2
            ? "Sigue añadiendo puntos"
            : "\(splineDraft.count) puntos · «Fin spline» para confirmar"
    }

    /// Confirma la spline en curso.
    func finishSpline() {
        guard splineDraft.count >= 2 else { return }
        let pts = splineDraft.map { Vec2($0) }
        let mode = splineMode
        mutate { $0.addSpline(through: pts, mode: mode) }
        splineDraft = []
        clearFeedback()
        statusMessage = "Spline ✓ — tócala para editar sus puntos"
    }

    private func tapPolygon(_ raw: SIMD2<Float>) {
        let p = snap(raw, reference: anchor.map { Vec2($0) }).position
        if let c = anchor.map({ Vec2($0) }) {
            let r = p.distance(to: c)
            if r > 1e-3 { commitPolygon(center: c, radius: r) }
            anchor = nil
            clearFeedback()
        } else {
            anchor = p.simd
            statusMessage = "Toca un vértice del radio"
        }
    }

    /// Polígono = N líneas con vértices compartidos (igual que el rect).
    private func commitPolygon(center: Vec2, radius: Double) {
        let sides = max(3, min(12, polygonSides))
        mutate { m in
            var verts: [Vec2] = []
            for k in 0..<sides {
                let t = Double(k) / Double(sides) * 2 * .pi - .pi / 2
                verts.append(center + Vec2(cos(t), sin(t)) * radius)
            }
            for k in 0..<sides {
                m.addLine(from: verts[k], to: verts[(k + 1) % sides])
            }
        }
        statusMessage = "Polígono ✓ — tócalo y arrastra para extruir"
    }

    // MARK: - Trazo por drag (dedo o Pencil): figura en vivo con snap

    func pencilDragBegan(at raw: SIMD2<Float>) {
        if activeTool == .spline {
            let p = snap(raw).position
            splineDraft = [p.simd]
            preview = p.simd
            return
        }
        let p = snap(raw, reference: chainLast).position
        anchor = p.simd
        preview = p.simd
    }

    func pencilDragChanged(to raw: SIMD2<Float>) {
        if activeTool == .spline {
            // El trazo siembra puntos cada ~0.35 (fluido con Pencil)
            if let last = splineDraft.last,
               simd_distance(last, raw) > 0.35 {
                splineDraft.append(raw)
            }
            preview = raw
            previewPolyline = splineDraft + [raw]
            return
        }
        guard let a = anchor.map({ Vec2($0) }) else { return }
        let s = snap(raw, reference: a)
        preview = s.position.simd
        previewPolyline = draftShape(from: a, to: s.position)
    }

    func pencilDragEnded(at raw: SIMD2<Float>) {
        if activeTool == .spline {
            splineDraft.append(raw)
            finishSpline()   // el trazo ES la spline
            return
        }
        guard let a = anchor.map({ Vec2($0) }) else { return }
        let end = snap(raw, reference: a).position
        switch activeTool {
        case .line:
            if end.distance(to: a) > 1e-6 {
                mutate { $0.addLine(from: a, to: end) }
                // El drag continúa la cadena: siguiente segmento desde el fin
                if chainStart == nil { chainStart = a }
                chainLast = end
                chainCount += 1
                statusMessage = "Sigue con más segmentos o toca el primero para cerrar"
            }
        case .rectangle:
            commitRectangle(from: a, to: end)
        case .circle:
            let r = end.distance(to: a)
            if r > 1e-3 {
                mutate { $0.addCircle(center: a, radius: r) }
                statusMessage = "Círculo ✓ — tócalo y arrastra para extruir"
            }
        case .polygon:
            let r = end.distance(to: a)
            if r > 1e-3 { commitPolygon(center: a, radius: r) }
        case .arc:
            // Drag de arco: ancla = centro, fin del drag = inicio; el fin llega
            // con un tap posterior (flujo centro→inicio→fin).
            arcStart = end
            statusMessage = "Toca el punto final del arco"
            preview = nil
            previewPolyline = []
            return
        case .spline:
            break
        }
        anchor = nil
        clearFeedback()
    }

    /// Polilínea de preview de la figura entre `a` y el cursor.
    private func draftShape(from a: Vec2, to p: Vec2) -> [SIMD2<Float>] {
        switch activeTool {
        case .line, .arc:
            return [a.simd, p.simd]
        case .rectangle:
            return [a.simd, Vec2(p.x, a.y).simd, p.simd, Vec2(a.x, p.y).simd, a.simd]
        case .circle:
            let r = p.distance(to: a)
            guard r > 1e-6 else { return [] }
            return (0...48).map { k in
                let t = Double(k) / 48 * 2 * .pi
                return (a + Vec2(cos(t), sin(t)) * r).simd
            }
        case .polygon:
            let r = p.distance(to: a)
            guard r > 1e-6 else { return [] }
            let sides = max(3, min(12, polygonSides))
            var verts: [SIMD2<Float>] = []
            for k in 0...sides {
                let t = Double(k % sides) / Double(sides) * 2 * .pi - .pi / 2
                verts.append((a + Vec2(cos(t), sin(t)) * r).simd)
            }
            return verts
        case .spline:
            return splineDraft + [p.simd]
        }
    }

    // MARK: - Arrastre de puntos existentes (ajuste fino con topología)

    private var draggedPoint: PointID? = nil
    var isDraggingPoint: Bool { draggedPoint != nil }

    /// Intenta iniciar arrastre de un punto topológico cercano.
    @discardableResult
    func beginDrag(near raw: SIMD2<Float>) -> Bool {
        guard let pid = model.existingPoint(near: Vec2(raw),
                                            tolerance: Double(Self.snapRadius) * 2) else {
            return false
        }
        undoStack.append(model)   // un snapshot por gesto, no por frame
        draggedPoint = pid
        statusMessage = "Arrastra para ajustar — el snap te guía"
        return true
    }

    /// Mueve el punto arrastrado: TODA la topología conectada lo sigue.
    func drag(to raw: SIMD2<Float>) {
        guard let pid = draggedPoint else { return }
        let s = snap(raw, excludePoints: [pid])
        model.movePoint(pid, to: s.position)
        preview = s.position.simd
        revision += 1
    }

    func endDrag() {
        draggedPoint = nil
        modelDidChange()
        clearFeedback()
        statusMessage = regions.isEmpty ? "" : "Perfil cerrado ✓ — toca la región y arrastra para extruir"
    }

    // MARK: - Regiones (tap dentro → seleccionar, drag → extruir)

    /// Región cerrada que contiene el punto (la más pequeña — círculo dentro
    /// del rect elige el círculo).
    func region(at p: SIMD2<Float>) -> [SIMD2<Float>]? {
        RegionFinder.region(at: Vec2(p), in: regions)?.polygon.map { $0.simd }
    }

    @discardableResult
    func selectRegion(at p: SIMD2<Float>) -> Bool {
        guard let verts = region(at: p) else {
            selectedRegion = nil
            return false
        }
        selectedRegion = verts
        statusMessage = "Región seleccionada — arrastra desde adentro para extruir"
        return true
    }

    func deselectRegion() { selectedRegion = nil }

    // MARK: - Undo / limpiar

    func undoLast() {
        // Primero deshace borradores en curso (comportamiento previo)
        if !splineDraft.isEmpty { splineDraft.removeLast(); return }
        if arcStart != nil { arcStart = nil; return }
        if anchor != nil { anchor = nil; return }
        if chainLast != nil {
            // Deshacer el último segmento de la cadena restaura el modelo previo
            if let prev = undoStack.popLast() {
                model = prev
                chainCount = max(0, chainCount - 1)
                if chainCount == 0 { chainLast = nil; chainStart = nil }
                modelDidChange()
            } else {
                chainLast = nil; chainStart = nil; chainCount = 0
            }
            return
        }
        if let prev = undoStack.popLast() {
            model = prev
            modelDidChange()
        }
        selectedCurveID = nil
        selectedRegion = nil
        clearFeedback()
    }

    func clear() {
        undoStack.append(model)
        model.removeAll()
        cancelDrafts()
        selectedRegion = nil
        modelDidChange()
        statusMessage = ""
    }

    /// Mensaje de ayuda visible en la sketchBar.
    func hint(_ s: String) { statusMessage = s }

    // MARK: - Selección/edición de la curva seleccionada

    @discardableResult
    func selectEntity(near p: SIMD2<Float>, centersOnly: Bool = false) -> Bool {
        let hit = hitTester.hitTest(at: Vec2(p), in: model,
                                    pointRadius: Double(Self.snapRadius),
                                    curveRadius: Double(Self.snapRadius),
                                    regions: [])
        if case .curve(let id, _) = hit {
            selectedCurveID = id
            statusMessage = "Trazo seleccionado — edita o elimina"
            return true
        }
        selectedCurveID = nil
        return false
    }

    func deselectEntity() { selectedCurveID = nil }

    func deleteEntity(at index: Int? = nil) {
        let id: CurveID?
        if let i = index, i >= 0, i < model.curveOrder.count {
            id = model.curveOrder[i]
        } else {
            id = selectedCurveID
        }
        guard let target = id else { return }
        mutate { $0.removeCurve(target) }
        selectedCurveID = nil
        statusMessage = "Trazo eliminado"
    }

    func selectEntity(at index: Int) {
        selectedEntityIndex = index
    }

    /// Radio editable de la curva seleccionada (círculo), o nil.
    var selectedRadius: Float? {
        guard let id = selectedCurveID,
              case .circle(_, let r) = model.curves[id]?.kind else { return nil }
        return Float(r)
    }

    /// Los lados/tamaño de rect del sistema viejo ya no aplican: rectángulos y
    /// polígonos son LÍNEAS reales con esquinas arrastrables (mejor que campos).
    var selectedSides: Int? { nil }
    var selectedRectSize: (w: Float, h: Float)? { nil }

    func editSelectedRadius(_ r: Float) {
        guard let id = selectedCurveID,
              case .circle = model.curves[id]?.kind else { return }
        mutate { $0.setCircleRadius(id, radius: Double(max(1e-3, r))) }
    }

    func editSelectedSides(_ sides: Int) {}
    func editSelectedRectSize(w: Float, h: Float) {}

    // MARK: - Plano ↔ mundo

    func world(_ p: SIMD2<Float>) -> SIMD3<Float> {
        plane.origin + plane.u * p.x + plane.v * p.y
    }

    func resetPlaneToFloor() {
        plane = .floor
        statusMessage = "Plano de boceto: suelo"
    }

    // MARK: - OCCT: regiones → sólidos REALES

    private func world3(_ p: SIMD2<Float>, height: Double) -> SIMD3<Double> {
        let w = world(p) + plane.normal * Float(height)
        return SIMD3<Double>(Double(w.x), Double(w.y), Double(w.z))
    }

    private func wire(vertices: [SIMD2<Float>], atHeight y: Double = 0) -> Wire? {
        guard vertices.count >= 3 else { return nil }
        return Wire.polygon3D(vertices.map { world3($0, height: y) }, closed: true)
    }

    /// Vértices de la región ACTIVA: la seleccionada, o la de mayor área.
    private func activeRegionVertices() -> [SIMD2<Float>]? {
        if let sel = selectedRegion, sel.count >= 3 { return sel }
        guard let biggest = regions.first, biggest.polygon.count >= 3 else { return nil }
        return biggest.polygon.map { $0.simd }
    }

    private func activeRegionWire() -> Wire? {
        guard let verts = activeRegionVertices() else { return nil }
        return wire(vertices: verts)
    }

    /// Perfil planar (cara B-rep) de la región activa, en coords mundo.
    func activeRegionProfile() -> CADShape? {
        guard let w = activeRegionWire() else { return nil }
        return OCCTSwift.Shape.face(from: w, planar: true)
    }

    /// Prisma B-rep de extruir la región activa. Puro: NO toca la escena.
    func extrudedShapeForActiveRegion(distance: Double) -> CADShape? {
        guard distance > 1e-9, let w = activeRegionWire() else { return nil }
        let dir = SIMD3<Double>(Double(plane.normal.x), Double(plane.normal.y), Double(plane.normal.z))
        return OCCTSwift.Shape.extrude(profile: w, direction: dir, length: distance)
    }

    /// Extruye una región dada por sus vértices 2D del plano.
    func extrudeRegion(vertices: [SIMD2<Float>], height: Double) -> Model? {
        guard height > 1e-9, vertices.count >= 3 else {
            statusMessage = "Región inválida para extruir"
            return nil
        }
        let dir = SIMD3<Double>(Double(plane.normal.x), Double(plane.normal.y), Double(plane.normal.z))
        guard let w = wire(vertices: vertices),
              let shape = OCCTSwift.Shape.extrude(profile: w, direction: dir, length: height),
              let mesh = OCCTBridge.toMesh(shape, quality: .medium) else {
            statusMessage = "No se pudo extruir la región"
            return nil
        }
        let model3D = Model(name: "Región_\(UUID().uuidString.prefix(6))")
        model3D.cadShape = shape
        model3D.meshes = [mesh]
        model3D.edgesMesh = OCCTBridge.edgesMesh(shape)
        return model3D
    }

    /// Extruye la región que contiene el punto tocado.
    func extrudeRegion(at point: SIMD2<Float>, height: Double) -> Model? {
        guard let verts = region(at: point) else {
            statusMessage = "No hay región cerrada bajo el toque"
            return nil
        }
        return extrudeRegion(vertices: verts, height: height)
    }

    /// Extruye el área cerrada activa (la seleccionada o la mayor).
    func extrudeClosedArea(height: Double) -> Model? {
        guard let verts = activeRegionVertices() else {
            statusMessage = "No hay área cerrada para extruir"
            return nil
        }
        return extrudeRegion(vertices: verts, height: height)
    }

    /// Compat: extruir "el primer perfil cerrado" = la región mayor.
    func extrudeProfile(height: Double) -> Model? {
        extrudeClosedArea(height: height)
    }

    /// TUBO: círculo barrido a lo largo de la última spline dibujada.
    func tubeAlongPath(radius: Double) -> Model? {
        guard radius > 1e-9 else { return nil }
        var samples: [Vec2]? = nil
        for curve in model.orderedCurves.reversed() {
            if case .spline = curve.kind,
               let g = CurveGeometry.resolve(curve, in: model),
               case .sampledSpline(let s) = g.shape {
                samples = s
                break
            }
        }
        guard let pts = samples, pts.count >= 2 else {
            statusMessage = "Dibuja una spline como ruta primero"
            return nil
        }
        let p3 = pts.map { world3($0.simd, height: 0) }
        let start = p3[0]
        let dir3 = simd_normalize(p3[1] - p3[0])
        guard let pathW = Wire.bspline(p3),
              let profile = Wire.circle(origin: start, normal: dir3, radius: radius),
              let shape = OCCTSwift.Shape.sweep(profile: profile, along: pathW),
              let mesh = OCCTBridge.toMesh(shape, quality: .medium) else {
            statusMessage = "No se pudo crear el tubo"
            return nil
        }
        let model3D = Model(name: "Tubo_\(UUID().uuidString.prefix(6))")
        model3D.cadShape = shape
        model3D.meshes = [mesh]
        model3D.edgesMesh = OCCTBridge.edgesMesh(shape)
        return model3D
    }

    /// TRANSICIÓN (loft): de la región mayor (abajo) a la segunda (elevada).
    func loftProfiles(height: Double) -> Model? {
        guard regions.count >= 2 else {
            statusMessage = "Dibuja DOS perfiles cerrados para la transición"
            return nil
        }
        let vA = regions[0].polygon.map { $0.simd }
        let vB = regions[1].polygon.map { $0.simd }
        guard height > 1e-9,
              let wA = wire(vertices: vA, atHeight: 0),
              let wB = wire(vertices: vB, atHeight: height),
              let shape = OCCTSwift.Shape.loft(profiles: [wA, wB], solid: true),
              let mesh = OCCTBridge.toMesh(shape, quality: .medium) else {
            statusMessage = "No se pudo crear la transición"
            return nil
        }
        let model3D = Model(name: "Transición_\(UUID().uuidString.prefix(6))")
        model3D.cadShape = shape
        model3D.meshes = [mesh]
        model3D.edgesMesh = OCCTBridge.edgesMesh(shape)
        return model3D
    }

    /// Revoluciona la región activa alrededor del eje del plano.
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
        guard let w = activeRegionWire(),
              let shape = OCCTSwift.Shape.revolve(profile: w,
                                                  axisOrigin: axisOrigin,
                                                  axisDirection: axisDir,
                                                  angle: angle),
              let mesh = OCCTBridge.toMesh(shape, quality: .medium) else {
            statusMessage = "No se pudo revolucionar (¿el perfil cruza el eje?)"
            return nil
        }
        let model3D = Model(name: "Revolución_\(UUID().uuidString.prefix(6))")
        model3D.cadShape = shape
        model3D.meshes = [mesh]
        model3D.edgesMesh = OCCTBridge.edgesMesh(shape)
        return model3D
    }
}

// MARK: - Presentación de curvas (panel de Elementos)

extension SketchCurve {
    var displayName: String {
        switch kind {
        case .line: return "Línea"
        case .arc: return "Arco"
        case .circle(_, let r): return String(format: "Círculo R %.2f", r)
        case .spline(let pts, let mode):
            return mode == .throughPoints ? "Spline (\(pts.count))" : "Spline ctrl (\(pts.count))"
        }
    }

    var iconName: String {
        switch kind {
        case .line: return "line.diagonal"
        case .arc: return "point.topleft.down.curvedto.point.bottomright.up"
        case .circle: return "circle"
        case .spline: return "scribble.variable"
        }
    }
}

// MARK: - UUID helper (compat: usado históricamente por otros módulos)

extension UUID {
    /// Genera un UUID determinístico a partir de un string hash.
    static func from(hash: String) -> UUID {
        let data = hash.data(using: .utf8) ?? Data()
        var bytes = [UInt8](repeating: 0, count: 16)
        for (i, byte) in data.prefix(16).enumerated() { bytes[i] = byte }
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
