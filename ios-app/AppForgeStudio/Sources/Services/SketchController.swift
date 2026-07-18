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

    enum Tool { case line, rectangle, circle, arc, spline, polygon, trim }

    // MARK: - Estado del kernel

    /// El documento de sketch (tipo valor — undo = pila de copias).
    @Published private(set) var model = SketchModel(mergeTolerance: 1e-3)
    /// Regiones cerradas cacheadas (se recalculan al mutar el modelo).
    @Published private(set) var regions: [SketchKernel.SketchRegion] = []

    private var undoStack: [SketchModel] = []
    // Calificado: la app tiene un `class SnapEngine` propio (snap 3D de
    // transformaciones) que sombrea al del kernel dentro de este módulo.
    private let snapEngine = SketchKernel.SnapEngine()
    private let hitTester = HitTester()

    /// Radio de snap FALLBACK en unidades del plano (si aún no hay escala de
    /// zoom conocida). El radio REAL de trabajo es `snapRadiusPlane`, que se
    /// deriva de `unitsPerPoint` (adaptativo al zoom) — beta 2026-07-16b: el
    /// radio fijo "agarraba un poco" porque no se adaptaba al zoom.
    static let snapRadius: Float = 0.14

    // MARK: - Escala adaptativa al zoom (beta 2026-07-16b)

    /// Unidades de plano por PUNTO de pantalla. La calcula CADModeView
    /// proyectando `plane.origin` y `plane.origin + plane.u` con las MISMAS
    /// matrices que usa SketchCanvasOverlay.proj. A más zoom → menor valor.
    @Published var unitsPerPoint: Float = 0.01

    /// Radio de snap del DEDO en unidades de plano, adaptado al zoom: ~22 pt de
    /// pantalla siempre (con zoom lejano agarra desde más lejos en el plano; con
    /// zoom cercano exige más precisión). Sustituye a `Self.snapRadius` fijo.
    var snapRadiusPlane: Float {
        max(1e-4, 22 * unitsPerPoint)
    }

    /// Paso de siembra de la spline con Pencil, adaptado al zoom (~8 pt).
    private var splineSeedStep: Float {
        max(1e-4, 8 * unitsPerPoint)
    }

    /// Paso "bonito" de rejilla (1/2/5 × 10^n) tal que la celda mida ~60 pt.
    /// Lo usa el snap a rejilla y el dibujo de la grilla (CADModeView).
    var adaptiveGridStep: Double {
        Self.niceNumber(Double(60 * unitsPerPoint))
    }

    /// Redondeo a la escala "bonita" 1/2/5·10^n más cercana por arriba — la
    /// misma progresión de reglas y planos CAD.
    static func niceNumber(_ raw: Double) -> Double {
        guard raw > 1e-12 else { return 1 }
        let exp = floor(log10(raw))
        let base = pow(10.0, exp)
        let frac = raw / base
        let nice: Double
        if frac <= 1.5 { nice = 1 }
        else if frac <= 3.5 { nice = 2 }
        else if frac <= 7.5 { nice = 5 }
        else { nice = 10 }
        return nice * base
    }

    // MARK: - Estado de dibujo en curso

    /// Cadena de líneas en curso: posición del último punto confirmado
    /// (referencia para guías H/V) y el primero (para cerrar).
    private(set) var chainLast: Vec2? = nil
    private(set) var chainStart: Vec2? = nil
    private(set) var chainCount: Int = 0
    /// PointID topológico del primer punto de la cadena (para cerrar robusto:
    /// si el snap engancha ESE punto, cerramos aunque el radio no dé — beta
    /// 2026-07-16b: "cerrar cadena flojo").
    private var chainStartPoint: PointID? = nil
    /// Ancla del gesto de 2 taps (rect: esquina A; círculo/polígono: centro;
    /// arco: centro→inicio→fin usa además `arcStart`).
    @Published private(set) var anchor: SIMD2<Float>? = nil
    private var arcStart: Vec2? = nil
    /// Inicio del arco en curso (para que el overlay dibuje el radio punteado
    /// centro→cursor mientras se arma el arco). nil si aún no hay inicio.
    var arcStartPoint: SIMD2<Float>? { arcStart?.simd }
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

    /// Herramienta ARMADA (beta 2026-07-16b: paradigma Shapr3D). `nil` = estado
    /// NEUTRAL: tocar selecciona/mueve, no dibuja. Al confirmar una figura
    /// cerrada se vuelve a neutral (auto-neutral) — el flujo natural es
    /// dibujar → tocar el área → extruir.
    @Published var armedTool: Tool? = nil

    /// Alias de compat: mucho código de UI/render lee `activeTool`. Devuelve la
    /// armada, o `.line` como neutro visual cuando no hay ninguna (el render de
    /// preview solo se usa si hay borrador, así que el valor neutro es inocuo).
    var activeTool: Tool { armedTool ?? .line }

    @Published var polygonSides: Int = 6

    /// Bump en cada mutación del modelo — CADModeView reconstruye overlays.
    @Published private(set) var revision: Int = 0

    // MARK: - Selección

    /// Selección MÚLTIPLE de trazos (beta 2026-07-16b: en neutral, cada tap
    /// añade/quita del conjunto — como Shapr3D sin botón de seleccionar).
    @Published var selectedCurveIDs: Set<CurveID> = []

    /// Doble tap = seleccionar el PERÍMETRO completo (mecánica Shapr3D). Guarda
    /// la curva del último tap y su instante; si el siguiente tap cae sobre la
    /// MISMA curva antes de `doubleTapWindow`, se expande a la cadena conectada.
    private var lastTapCurve: CurveID? = nil
    private var lastTapTime: TimeInterval = 0
    /// Ventana de doble tap (s): dos taps más cercanos que esto sobre la misma
    /// curva = seleccionar el perímetro. 0.35 s = umbral cómodo con dedo.
    static let doubleTapWindow: TimeInterval = 0.35

    /// "Curva caliente": la RECIÉN confirmada. La barra muestra campos numéricos
    /// contextuales para editarla en vivo (longitud/ángulo/radio) además del
    /// auto-neutral. Brecha #1 de sensación vs Shapr3D (input al dibujar). Se
    /// limpia al tocar en vacío o armar otra herramienta.
    @Published private(set) var hotCurveID: CurveID? = nil

    /// Compat: el panel de Elementos y el render leen un solo `selectedCurveID`.
    /// Es el PRIMERO del conjunto (orden de dibujo). Asignarlo reemplaza el set.
    var selectedCurveID: CurveID? {
        get {
            model.curveOrder.first(where: { selectedCurveIDs.contains($0) })
        }
        set {
            if let id = newValue { selectedCurveIDs = [id] }
            else { selectedCurveIDs = [] }
        }
    }

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
        // Radio adaptativo al zoom + snap a rejilla adaptativa activo (el kernel
        // le da PRIORIDAD MÍNIMA: los puntos duros ganan a la rejilla).
        let ctx = SnapContext(cursor: Vec2(raw),
                              radius: Double(snapRadiusPlane),
                              referencePoint: reference,
                              excludedPoints: excludePoints,
                              gridSpacing: adaptiveGridStep)
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

    /// ¿El snap enganchó un punto NOTABLE "duro" (endpoint/intersección/medio/
    /// centro/cuadrante)? Si sí, la posición es intencional y NO debe ajustarse
    /// a H/V en el commit — el usuario apuntó exactamente ahí.
    private func isHardSnap(_ result: SnapResult) -> Bool {
        switch result.kind {
        case .endpoint, .intersection, .midpoint, .center, .quadrant:
            return true
        default:
            return false
        }
    }

    /// Commit H/V DEFINITIVO (<10°, delega en `AxisSnap` del kernel — lógica
    /// pura testeable). Solo endereza cuando NO hubo snap duro: si el usuario
    /// enganchó un punto notable, esa posición fue intencional.
    private func snapEndpointToAxis(_ endpoint: Vec2, from reference: Vec2,
                                    snap result: SnapResult) -> Vec2 {
        AxisSnap.commit(endpoint: endpoint, reference: reference,
                        allowAdjust: !isHardSnap(result))
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
        // Primera pasada con la tolerancia por defecto.
        var found = RegionFinder.regions(in: model)
        // Segunda pasada TOLERANTE (robustez): si no salió ninguna región pero
        // hay ≥3 curvas no-construcción (un perfil que "parece" cerrado en
        // pantalla pero con gaps de Pencil), reintenta soldando con una
        // tolerancia mayor derivada del radio de snap. Feedback device: "cerrar
        // cadena todavía no funciona muy bien". (Dune3D usa Clipper2 tolerante;
        // esto es el equivalente barato: subir weldTolerance en el segundo pase.)
        if found.isEmpty {
            let solidCurves = model.orderedCurves.filter { !$0.isConstruction }.count
            if solidCurves >= 3 {
                let weld = Double(snapRadiusPlane) * 0.5
                let second = RegionFinder.regions(in: model, weldTolerance: weld)
                if !second.isEmpty { found = second }
            }
        }
        regions = found
        revision += 1
    }

    /// Re-evalúa las regiones sin mutar el modelo. Útil cuando cambia el zoom
    /// (el umbral del segundo pase depende de `snapRadiusPlane`). Internal para
    /// que los tests verifiquen el segundo pase con un radio concreto.
    func recomputeRegions() { modelDidChange() }

    // MARK: - Herramientas (taps)

    /// ARMA la herramienta EMPEZANDO LIMPIO (bug de device: sin esto una línea
    /// nueva continuaba desde el punto anterior).
    func beginTool(_ tool: Tool) {
        cancelDrafts()
        armedTool = tool
        statusMessage = ""
    }

    /// Vuelve al estado NEUTRAL (sin herramienta armada): tocar selecciona/mueve,
    /// no dibuja. Cancela cualquier borrador en curso.
    func disarm() {
        cancelDrafts()
        armedTool = nil
        statusMessage = ""
    }

    private func cancelDrafts() {
        chainLast = nil; chainStart = nil; chainCount = 0
        chainStartPoint = nil
        anchor = nil; arcStart = nil
        splineDraft = []
        selectedCurveIDs = []
        hotCurveID = nil
        draggedPoint = nil
        clearFeedback()
    }

    private var isDrafting: Bool {
        chainLast != nil || anchor != nil || !splineDraft.isEmpty || arcStart != nil
    }

    /// ¿Hay una figura a medio dibujar? La UI no debe robar el tap/drag para
    /// seleccionar regiones mientras se dibuja.
    var isDrawingInProgress: Bool { isDrafting }

    /// - Parameter now: instante del tap (para detectar doble tap). Por defecto
    ///   el reloj monótono real; los tests lo inyectan para controlar la ventana.
    func tap(at raw: SIMD2<Float>, now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        // ESTADO NEUTRAL (sin herramienta armada): tocar selecciona/mueve, no
        // dibuja. Paradigma Shapr3D — sin botón de seleccionar (beta
        // 2026-07-16b). El hit-test completo decide qué se tocó.
        guard let tool = armedTool else {
            neutralTap(raw, now: now)
            return
        }

        // ESTADO ARMADO: el tap SIEMPRE dibuja (nada de robar el gesto para
        // seleccionar). El snap del kernel arranca EXACTO desde un punto
        // existente si estás cerca — así B→C funciona y A→B queda intacta.
        switch tool {
        case .line: tapLine(raw)
        case .rectangle: tapRectangle(raw)
        case .circle: tapCircle(raw)
        case .arc: tapArc(raw)
        case .spline: tapSpline(raw)
        case .polygon: tapPolygon(raw)
        case .trim: tapTrim(raw)
        }
        preview = nil
    }

    /// Tap en NEUTRAL: hit-test completo → punto (selecciona/arrastrable),
    /// trazo (selección múltiple: añade/quita del set), región (selecciona),
    /// vacío (deselecciona todo). Radio adaptativo al zoom.
    private func neutralTap(_ raw: SIMD2<Float>, now: TimeInterval) {
        let r = Double(snapRadiusPlane)
        let hit = hitTester.hitTest(at: Vec2(raw), in: model,
                                    pointRadius: r,
                                    curveRadius: r * 0.8,
                                    regions: regions)
        switch hit {
        case .curve(let id, _):
            // ¿DOBLE TAP sobre la MISMA curva dentro de la ventana? → seleccionar
            // el PERÍMETRO completo (cadena conectada por extremos, mecánica
            // Shapr3D). La primera vez expande el perímetro; un segundo doble tap
            // sobre él (todas ya seleccionadas) lo DESELECCIONA (toggle limpio).
            let isDouble = (lastTapCurve == id)
                && (now - lastTapTime) < Self.doubleTapWindow
            if isDouble {
                let chain = hitTester.connectedChain(from: id, in: model)
                // Decisión por MAYORÍA (robusta al medio-toggle del 1er tap del par:
                // ese tap pudo quitar/añadir SOLO este trazo del perímetro): si más
                // de la mitad de la cadena ya está seleccionada, el doble tap la
                // DESELECCIONA entera; si no, la SELECCIONA entera.
                let alreadyIn = chain.filter { selectedCurveIDs.contains($0) }.count
                if !chain.isEmpty, alreadyIn * 2 > chain.count {
                    selectedCurveIDs.subtract(chain)          // perímetro ya activo → quita
                    statusMessage = selectedCurveIDs.isEmpty ? "" : "\(selectedCurveIDs.count) trazo(s)"
                } else {
                    selectedCurveIDs.formUnion(chain)         // selecciona el perímetro
                    statusMessage = "Perímetro seleccionado (\(chain.count) trazos) — edita o extruye"
                }
                lastTapCurve = nil                            // consume el doble tap
                lastTapTime = 0
                selectedRegion = nil
                clearFeedback()
                return
            }
            // Tap SIMPLE: añade/quita este trazo del conjunto (toggle).
            if selectedCurveIDs.contains(id) {
                selectedCurveIDs.remove(id)
            } else {
                selectedCurveIDs.insert(id)
            }
            lastTapCurve = id
            lastTapTime = now
            selectedRegion = nil
            statusMessage = selectedCurveIDs.isEmpty
                ? ""
                : "\(selectedCurveIDs.count) trazo(s) — edita, extruye o doble-tap = perímetro"
            clearFeedback()
        case .point:
            // Un punto seleccionado queda listo para arrastrar (el drag lo mueve).
            lastTapCurve = nil   // rompe cualquier doble tap de curva en curso
            selectedRegion = nil
            statusMessage = "Punto seleccionado — arrástralo para moverlo"
            clearFeedback()
        case .region(let region):
            lastTapCurve = nil
            selectedRegion = region.polygon.map { $0.simd }
            selectedCurveIDs = []
            statusMessage = "Región seleccionada — arrastra desde adentro para extruir"
            clearFeedback()
        case .none:
            // Tap en vacío deselecciona todo (incluida la curva caliente).
            lastTapCurve = nil
            selectedCurveIDs = []
            selectedRegion = nil
            hotCurveID = nil
            statusMessage = ""
            clearFeedback()
        }
    }

    private func tapLine(_ raw: SIMD2<Float>) {
        let s = snap(raw, reference: chainLast)
        let p = s.position

        if let start = chainStart, chainCount >= 2 {
            // CERRAR robusto: el snap enganchó el PUNTO inicial (pointID) o el
            // cursor cayó dentro del radio dinámico (beta 2026-07-16b: antes el
            // radio fijo hacía "cerrar cadena flojo").
            let hitStartPoint = (chainStartPoint != nil && s.pointID == chainStartPoint)
            let withinRadius = p.distance(to: start) < Double(snapRadiusPlane)
            if hitStartPoint || withinRadius {
                if let last = chainLast {
                    mutate { $0.addLine(from: last, to: start) }
                }
                endChain()
                statusMessage = "Perfil cerrado ✓ — tócalo y arrastra para extruir"
                return
            }
        }

        if let last = chainLast {
            guard p.distance(to: last) > 1e-6 else { return }
            // Commit H/V definitivo (<10°): endereza el extremo si el ángulo
            // desde el punto anterior está casi horizontal/vertical y no hubo
            // snap duro.
            let end = snapEndpointToAxis(p, from: last, snap: s)
            var added: CurveID?
            mutate { added = $0.addLine(from: last, to: end) }
            hotCurveID = added   // curva caliente: editable en vivo por longitud/ángulo
            chainCount += 1
            chainLast = end
            // El punto de arranque ya EXISTE en el modelo tras el primer
            // segmento: capturamos su pointID para cerrar por identidad
            // topológica (más robusto que sólo por distancia).
            if chainStartPoint == nil, let start = chainStart {
                chainStartPoint = model.existingPoint(near: start, tolerance: Double(snapRadiusPlane) * 0.5)
            }
            statusMessage = "\(chainCount + 1) puntos · toca el primero para cerrar"
        } else {
            chainStart = p
            chainLast = p
            chainCount = 0
            // Si arrancamos ENGANCHADOS a un punto existente (topología), ya
            // tenemos su id; si no, lo tomaremos tras el primer segmento.
            chainStartPoint = s.pointID
            statusMessage = "Sigue tocando; toca el primer punto para cerrar"
        }
    }

    /// Termina la cadena en curso → estado NEUTRAL (auto-neutral: cerrar un
    /// perfil devuelve al usuario a tocar/extruir sin herramienta armada).
    private func endChain() {
        chainLast = nil; chainStart = nil; chainCount = 0
        chainStartPoint = nil
        armedTool = nil
        clearFeedback()
    }

    private func tapRectangle(_ raw: SIMD2<Float>) {
        let p = snap(raw, reference: anchor.map { Vec2($0) }).position
        if let a = anchor {
            commitRectangle(from: Vec2(a), to: p)
            anchor = nil
            clearFeedback()
            armedTool = nil   // auto-neutral: figura cerrada confirmada
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
                var added: CurveID?
                mutate { added = $0.addCircle(center: Vec2(c), radius: r) }
                hotCurveID = added   // radio editable en vivo
                statusMessage = "Círculo ✓ — tócalo y arrastra para extruir"
            }
            anchor = nil
            clearFeedback()
            armedTool = nil   // auto-neutral: figura cerrada confirmada
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
            var added: CurveID?
            mutate { added = $0.addArc(center: c, start: s, end: p, ccw: ccw) }
            hotCurveID = added   // radio editable en vivo
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
        // La curva se VE crecer tap a tap: muestrea la spline del borrador con el
        // MISMO evaluador que usará al confirmar (beta 2026-07-16b: antes solo se
        // veían los puntos y parecía una recta).
        refreshSplinePreview()
        statusMessage = splineDraft.count < 2
            ? "Sigue añadiendo puntos"
            : "\(splineDraft.count) puntos · «Fin spline» para confirmar"
    }

    /// Recalcula `previewPolyline` a partir del borrador de spline actual.
    private func refreshSplinePreview() {
        guard splineDraft.count >= 2 else { previewPolyline = []; return }
        let pts = splineDraft.map { Vec2($0) }
        previewPolyline = SplineEvaluator.sample(points: pts, mode: splineMode).map { $0.simd }
    }

    /// Confirma la spline en curso → estado NEUTRAL (auto-neutral).
    func finishSpline() {
        guard splineDraft.count >= 2 else { return }
        let pts = splineDraft.map { Vec2($0) }
        let mode = splineMode
        mutate { $0.addSpline(through: pts, mode: mode) }
        splineDraft = []
        clearFeedback()
        armedTool = nil   // auto-neutral: la spline terminada devuelve a neutral
        statusMessage = "Spline ✓ — tócala para editar sus puntos"
    }

    private func tapPolygon(_ raw: SIMD2<Float>) {
        let p = snap(raw, reference: anchor.map { Vec2($0) }).position
        if let c = anchor.map({ Vec2($0) }) {
            let r = p.distance(to: c)
            if r > 1e-3 { commitPolygon(center: c, radius: r) }
            anchor = nil
            clearFeedback()
            armedTool = nil   // auto-neutral: figura cerrada confirmada
        } else {
            anchor = p.simd
            statusMessage = "Toca un vértice del radio"
        }
    }

    /// Tap con la herramienta TRIM armada: localiza el trazo bajo el toque
    /// (HitTester) y lo recorta en ese tramo (kernel.trim). Tras recortar sigue
    /// ARMADO (recortes en ráfaga, como Shapr3D). Status honesto si no pudo.
    private func tapTrim(_ raw: SIMD2<Float>) {
        let r = Double(snapRadiusPlane)
        let hit = hitTester.hitTest(at: Vec2(raw), in: model,
                                    pointRadius: r * 0.5,   // el punto no gana al trazo aquí
                                    curveRadius: r,
                                    regions: [])
        guard case .curve(let id, let closest) = hit else {
            statusMessage = "Toca un trazo para recortarlo"
            return
        }
        var didTrim = false
        mutate { didTrim = $0.trim(id, at: closest) }
        statusMessage = didTrim
            ? "Recortado ✓ — sigue tocando trazos para recortar"
            : "No se pudo recortar aquí (¿spline o sin cruces suficientes?)"
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
        // Solo dibuja si hay herramienta armada (en neutral el drag se enruta a
        // mover-punto/región desde CADModeView, no aquí).
        guard let tool = armedTool else { return }
        // Trim es SOLO por tap: un drag lo trata como un tap de recorte.
        if tool == .trim { return }
        if tool == .spline {
            let p = snap(raw).position
            splineDraft = [p.simd]
            preview = p.simd
            return
        }
        // Arco en su 3ª fase (centro=anchor y arcStart ya fijados): un drag elige
        // el FIN. No sobrescribir el centro — solo mostrar el preview del arco.
        if tool == .arc, anchor != nil, arcStart != nil {
            let p = snap(raw, reference: arcStart).position   // arcStart ya es Vec2?
            preview = p.simd
            if let c = anchor.map({ Vec2($0) }), let s = arcStart {
                previewPolyline = arcPreviewPolyline(center: c, start: s, cursor: p)
            }
            return
        }
        let p = snap(raw, reference: chainLast).position
        anchor = p.simd
        preview = p.simd
    }

    func pencilDragChanged(to raw: SIMD2<Float>) {
        guard let tool = armedTool else { return }
        if tool == .trim { return }   // trim no dibuja preview
        if tool == .spline {
            // El trazo siembra puntos cada `splineSeedStep` (adaptativo al zoom:
            // beta 2026-07-16b — con paso fijo 0.35 salían 2 puntos y parecía
            // una recta).
            if let last = splineDraft.last,
               simd_distance(last, raw) > splineSeedStep {
                splineDraft.append(raw)
            }
            preview = raw
            previewPolyline = SplineEvaluator.sample(
                points: (splineDraft + [raw]).map { Vec2($0) }, mode: splineMode
            ).map { $0.simd }
            return
        }
        guard let a = anchor.map({ Vec2($0) }) else { return }
        let s = snap(raw, reference: a)
        preview = s.position.simd
        previewPolyline = draftShape(from: a, to: s.position)
    }

    func pencilDragEnded(at raw: SIMD2<Float>) {
        guard let tool = armedTool else { return }
        // Trim SOLO por tap: si el drag terminó sin haberse iniciado como dibujo
        // (no hay anchor), lo tratamos como un tap de recorte.
        if tool == .trim { tapTrim(raw); return }
        if tool == .spline {
            splineDraft.append(raw)
            finishSpline()   // el trazo ES la spline (finishSpline hace auto-neutral)
            return
        }
        guard let a = anchor.map({ Vec2($0) }) else { return }
        let endSnap = snap(raw, reference: a)
        let end = endSnap.position
        switch tool {
        case .line:
            // Commit H/V definitivo (<10°): endereza el extremo del drag si no
            // hubo snap duro y el ángulo está casi horizontal/vertical.
            let lineEnd = snapEndpointToAxis(end, from: a, snap: endSnap)
            if lineEnd.distance(to: a) > 1e-6 {
                var added: CurveID?
                mutate { added = $0.addLine(from: a, to: lineEnd) }
                hotCurveID = added
                // El drag continúa la cadena: siguiente segmento desde el fin.
                // La línea NO hace auto-neutral: sigue armada hasta cerrar.
                if chainStart == nil {
                    chainStart = a
                    chainStartPoint = model.existingPoint(near: a, tolerance: Double(snapRadiusPlane) * 0.5)
                }
                chainLast = lineEnd
                chainCount += 1
                statusMessage = "Sigue con más segmentos o toca el primero para cerrar"
            }
        case .rectangle:
            commitRectangle(from: a, to: end)
            anchor = nil
            clearFeedback()
            armedTool = nil   // auto-neutral
            return
        case .circle:
            let r = end.distance(to: a)
            if r > 1e-3 {
                var added: CurveID?
                mutate { added = $0.addCircle(center: a, radius: r) }
                hotCurveID = added
                statusMessage = "Círculo ✓ — tócalo y arrastra para extruir"
            }
            anchor = nil
            clearFeedback()
            armedTool = nil   // auto-neutral
            return
        case .polygon:
            let r = end.distance(to: a)
            if r > 1e-3 { commitPolygon(center: a, radius: r) }
            anchor = nil
            clearFeedback()
            armedTool = nil   // auto-neutral
            return
        case .arc:
            // Flujo centro→inicio→fin. Si arcStart YA existe (3ª fase), este
            // drag eligió el FIN: confirma el arco. Si no, este drag eligió el
            // INICIO (radio) y el fin llegará después (drag o tap).
            if let s = arcStart {
                let v1 = s - a, v2 = end - a
                let ccw = v1.cross(v2) > 0
                var added: CurveID?
                mutate { added = $0.addArc(center: a, start: s, end: end, ccw: ccw) }
                hotCurveID = added
                anchor = nil; arcStart = nil
                clearFeedback()
                statusMessage = "Arco ✓"
            } else {
                arcStart = end
                statusMessage = "Toca o arrastra el punto final del arco"
                preview = nil
                previewPolyline = []
            }
            return
        case .spline, .trim:
            break
        }
        anchor = nil
        clearFeedback()
    }

    /// Muestrea un arco vivo centro→start→cursor: radio = |start−centro|,
    /// ángulos de start y cursor, sentido por el signo del cross, ~24 puntos.
    /// Preview REAL del arco (antes se veía una recta hasta el cursor).
    private func arcPreviewPolyline(center c: Vec2, start s: Vec2, cursor p: Vec2) -> [SIMD2<Float>] {
        let r = s.distance(to: c)
        guard r > 1e-6 else { return [] }
        let a0 = (s - c).angle
        let a1 = (p - c).angle
        let ccw = (s - c).cross(p - c) > 0
        var sweep = ccw ? (a1 - a0) : (a0 - a1)
        while sweep < 0 { sweep += 2 * .pi }
        while sweep > 2 * .pi { sweep -= 2 * .pi }
        let n = 24
        return (0...n).map { k in
            let t = Double(k) / Double(n)
            let ang = ccw ? a0 + sweep * t : a0 - sweep * t
            return (c + Vec2(cos(ang), sin(ang)) * r).simd
        }
    }

    /// Polilínea de preview de la figura entre `a` y el cursor.
    private func draftShape(from a: Vec2, to p: Vec2) -> [SIMD2<Float>] {
        switch activeTool {
        case .arc:
            // Con centro (anchor=a) y arcStart ya fijados: muestrea el arco real
            // hasta el cursor. Sin arcStart aún: recta centro→cursor (elige start).
            if let s = arcStart {
                return arcPreviewPolyline(center: a, start: s, cursor: p)
            }
            return [a.simd, p.simd]
        case .line:
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
        case .trim:
            return []   // trim no dibuja preview de figura
        }
    }

    // MARK: - Arrastre de puntos existentes (ajuste fino con topología)

    private var draggedPoint: PointID? = nil
    var isDraggingPoint: Bool { draggedPoint != nil }

    /// Intenta iniciar arrastre de un punto topológico cercano.
    @discardableResult
    func beginDrag(near raw: SIMD2<Float>) -> Bool {
        guard let pid = model.existingPoint(near: Vec2(raw),
                                            tolerance: Double(snapRadiusPlane)) else {
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
                if chainCount == 0 { chainLast = nil; chainStart = nil; chainStartPoint = nil }
                modelDidChange()
            } else {
                chainLast = nil; chainStart = nil; chainCount = 0; chainStartPoint = nil
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
                                    pointRadius: Double(snapRadiusPlane),
                                    curveRadius: Double(snapRadiusPlane),
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
        // Con índice explícito: borra ese trazo. Sin índice: borra TODO el
        // conjunto seleccionado (selección múltiple en neutral).
        if let i = index, i >= 0, i < model.curveOrder.count {
            let target = model.curveOrder[i]
            mutate { $0.removeCurve(target) }
            selectedCurveIDs.remove(target)
            statusMessage = "Trazo eliminado"
            return
        }
        let targets = selectedCurveIDs
        guard !targets.isEmpty else { return }
        mutate { m in for t in targets { m.removeCurve(t) } }
        selectedCurveIDs = []
        statusMessage = targets.count > 1 ? "\(targets.count) trazos eliminados" : "Trazo eliminado"
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

    // MARK: - Entrada numérica al dibujar (curva caliente / selección única)

    /// La curva que la barra puede editar numéricamente: la CALIENTE (recién
    /// dibujada), o la ÚNICA seleccionada. nil si no hay una clara.
    var editableCurveID: CurveID? {
        if let hot = hotCurveID, model.curves[hot] != nil { return hot }
        if selectedCurveIDs.count == 1 { return selectedCurveIDs.first }
        return nil
    }

    /// Tipo de la curva editable para que la barra decida qué campos mostrar.
    enum EditableKind: Equatable { case line, circle, arc, other }
    var editableKind: EditableKind? {
        guard let id = editableCurveID, let k = model.curves[id]?.kind else { return nil }
        switch k {
        case .line: return .line
        case .circle: return .circle
        case .arc: return .arc
        case .spline: return .other
        }
    }

    /// Longitud actual de la línea editable (o nil).
    var editableLineLength: Float? {
        guard let id = editableCurveID, let m = model.lineMetrics(id) else { return nil }
        return Float(m.length)
    }
    /// Ángulo actual (grados) de la línea editable (o nil).
    var editableLineAngle: Float? {
        guard let id = editableCurveID, let m = model.lineMetrics(id) else { return nil }
        return Float(m.angleDegrees)
    }
    /// Radio actual del círculo/arco editable (o nil).
    var editableRadius: Float? {
        guard let id = editableCurveID else { return nil }
        switch model.curves[id]?.kind {
        case .circle(_, let r): return Float(r)
        case .arc(let s, _, let c, _):
            guard let sp = model.position(of: s), let cp = model.position(of: c) else { return nil }
            return Float(sp.distance(to: cp))
        default: return nil
        }
    }

    /// Fija la longitud de la línea editable (mueve el endpoint; la topología
    /// conectada lo sigue).
    func setEditableLineLength(_ length: Float) {
        guard let id = editableCurveID else { return }
        mutate { $0.setLineLength(id, Double(max(1e-3, length))) }
    }
    /// Fija el ángulo (grados) de la línea editable.
    func setEditableLineAngle(_ degrees: Float) {
        guard let id = editableCurveID else { return }
        mutate { $0.setLineAngle(id, degrees: Double(degrees)) }
    }
    /// Fija el radio del círculo/arco editable. El círculo usa setCircleRadius;
    /// el arco mueve el punto START re-proyectando (el fixup del kernel recoloca
    /// el extremo final al nuevo radio).
    func setEditableRadius(_ r: Float) {
        guard let id = editableCurveID else { return }
        let radius = Double(max(1e-3, r))
        switch model.curves[id]?.kind {
        case .circle:
            mutate { $0.setCircleRadius(id, radius: radius) }
        case .arc(let s, _, let c, _):
            guard let sp = model.position(of: s), let cp = model.position(of: c) else { return }
            let dir = sp.distance(to: cp) > 1e-9 ? (sp - cp).normalized : Vec2(1, 0)
            mutate { $0.movePoint(s, to: cp + dir * radius) }
        default:
            break
        }
    }

    // MARK: - Geometría de construcción (helper)

    /// ¿TODOS los trazos seleccionados son de construcción? (para etiquetar el
    /// botón como "activo"). Falso si el conjunto está vacío.
    var selectionAllConstruction: Bool {
        guard !selectedCurveIDs.isEmpty else { return false }
        return selectedCurveIDs.allSatisfy { model.curves[$0]?.isConstruction ?? false }
    }

    /// Togglea el bit de construcción de los trazos seleccionados. Si ya son
    /// todos de construcción, los vuelve normales; si no, los marca a todos.
    func toggleConstructionForSelection() {
        let targets = selectedCurveIDs
        guard !targets.isEmpty else { return }
        let makeConstruction = !selectionAllConstruction
        mutate { m in
            for t in targets { m.setConstruction(t, makeConstruction) }
        }
        statusMessage = makeConstruction
            ? "Construcción ✓ — no cierra región, sigue como guía"
            : "Geometría normal ✓"
    }

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
