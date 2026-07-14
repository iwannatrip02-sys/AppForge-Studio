import SwiftUI
import OSLog
import CoreGraphics
import simd

private let logger = Logger(subsystem: "com.appforgestudio", category: "CADModeView")

enum CADModeTab: String, CaseIterable {
    case model = "Model"
    case parametric = "Parametric"

    var displayName: String {
        switch self {
        case .model: return "Modelar"
        case .parametric: return "Historial"
        }
    }
}

struct CADModeView: View {
    @ObservedObject var canvasVM: CanvasViewModel
    var renderer: SatinRenderer
    @ObservedObject var toolVM: ToolViewModel
    @ObservedObject var animationVM: AnimationEngine
    @StateObject private var sketchEngine = CADSketchEngine()
    @StateObject private var constraintEngine = ConstraintEngine()
    @StateObject private var groupAssemblyEngine = AssemblyEngine()
    @StateObject private var pushPullController = PushPullController()
    @StateObject private var selectionController = SelectionController()
    @StateObject private var sketch = SketchController()
    @StateObject private var drawingExportController = DrawingExportController()
    @StateObject private var featureReportController = FeatureReportController()
    @ObservedObject private var brepHistory = BRepHistory.shared
    @StateObject private var dimensionManager = DimensionManager()
    @StateObject private var livePreviewEngine = LivePreviewEngine()
    @StateObject private var assemblyMatesEngine = AssemblyMatesEngine()
    @StateObject private var projectSettings = ProjectSettings.shared

    /// Nombre reservado del modelo overlay de resaltado de cara.
    private static let faceHighlightName = "__faceHighlight"
    /// Nombre reservado del overlay de resaltado de arista.
    private static let edgeHighlightName = "__edgeHighlight"
    @EnvironmentObject var themeManager: ThemeManager

    /// Init explícito: los @State/@StateObject privados hacen privado el init
    /// memberwise, y el chrome (WorkspaceView) instancia esta vista desde otro archivo.
    init(canvasVM: CanvasViewModel, renderer: SatinRenderer,
         toolVM: ToolViewModel, animationVM: AnimationEngine) {
        self.canvasVM = canvasVM
        self.renderer = renderer
        self.toolVM = toolVM
        self.animationVM = animationVM
    }

    private var theme: AppTheme { themeManager.currentTheme }

    @State private var selectedTool: CADTool = .select
    @State private var selectedTab: CADModeTab = .model
    @State private var showMeasurements = false
    @State private var extrudedMesh: Mesh? = nil
    @State private var shellThickness: Float = 0.05
    @State private var filletRadius: Float = 0.05
    @State private var showStepExportAlert: Bool = false
    @State private var stepExportMessage: String = ""
    @State private var cursorScreenPosition: CGPoint = .zero
    @State private var snapPoints: [SnapPoint] = []
    @State private var showSnapOverlay: Bool = false
    @State private var showExtrudeSheet: Bool = false
    @State private var extrudeDistance: Float = 0.1
    /// Modo de la extrusión: false = añadir material (cuerpo nuevo o unión con el
    /// cuerpo objetivo), true = cortar material (resta booleana) — toggle Añadir/Cortar.
    @State private var extrudeCut: Bool = false
    @State private var isExtruding: Bool = false
    @State private var showCADTimeline: Bool = false
    @State private var csgStatusMessage: String = ""
    @State private var showDrawingExportBar: Bool = false
    @State private var showFeatureReport: Bool = false
    @State private var showShareSheet: Bool = false
    /// Presenta el panel de exportación multi-formato (`ExportView`) como sheet
    /// desde el chrome de CAD — antes solo se abría desde RenderMode.
    @State private var showExport: Bool = false
    /// Parámetros del patrón (antes hardcodeados count=3 / count=6): cantidad de
    /// copias del patrón LINEAL, factor de espaciado (× la diagonal del cuerpo) y
    /// cantidad del patrón CIRCULAR. NOTA de honestidad: `BRepModeling.circularPattern`
    /// reparte SIEMPRE sobre 360° completos (no acepta ángulo de arco parcial), así
    /// que no se expone un control de «ángulo» que el motor no honraría.
    @State private var patternLinearCount: Int = 3
    @State private var patternLinearSpacing: Double = 1.6
    @State private var patternCircularCount: Int = 6
    /// Dispara el flash "templado" (IDENTIDAD_FORGE §6) al confirmar push/pull.
    @State private var temperTick: Int = 0
    /// Medición por toques sobre el modelo REAL (A → B → distancia exacta).
    @State private var measurePointA: SIMD3<Float>? = nil
    @State private var measurePointB: SIMD3<Float>? = nil
    /// Radio del fillet contextual de arista (barra de selección).
    @State private var edgeFilletRadius: Double = 0.1
    /// Espejo del estado de rayos X del renderer (para el tinte del botón).
    @State private var xrayOn = false
    /// Herramienta Agujero (patrón universal: tocar cara = taladrar, encadenable).
    @State private var holeRadius: Double = 0.15
    @State private var holeDepth: Double = 0   // 0 = pasante
    /// Número de lados del polígono activo en el sketch (sincronizado con SketchController).
    @State private var polygonSidesUI: Int = 6
    /// Ángulo de revolución en grados (360 = completa).
    @State private var revolveAngleDeg: Double = 360
    /// Ø del Tubo (sweep por ruta) y altura de la Transición (loft).
    @State private var tubeDiameter: Double = 0.3
    @State private var loftHeight: Double = 1.5
    /// Grosor del Vaciado por cara tocada.
    @State private var shellThicknessTap: Double = 0.08
    /// Dirección de la pared del Vaciado: false = hacia adentro (default CAD).
    @State private var shellOutward = false
    /// Drag de CARA activo (Mover + cara seleccionada): la cara viaja por su
    /// normal — push/pull directo estilo Shapr3D (Incremento 4 v1).
    @State private var dragFace: (modelIndex: Int, faceIndex: Int, normal: SIMD3<Float>)? = nil
    /// Radio FINAL del fillet variable (0 = uniforme, usa solo el radio inicial).
    @State private var edgeFilletRadiusEnd: Double = 0
    /// Drag de REGIÓN de sketch activo (extruir por arrastre — LA mecánica).
    @State private var regionDrag: (verts: [SIMD2<Float>], start: SIMD2<Float>)? = nil
    @State private var regionDragHeight: Double = 0
    /// Altura de extrusión del perfil de sketch (editable).
    @State private var sketchExtrudeHeight: Double = 1.0
    /// Panel de Elementos visible (anatomía Shapr3D).
    @State private var showElements = true

    /// Grupos del rail vertical (anatomía Shapr3D: iconos que despliegan flyouts).
    enum ToolGroup: String, CaseIterable, Identifiable {
        case draw = "Dibujo"
        case form = "Formar"
        case combine = "Combinar"
        case primitives = "Primitivas"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .draw: return "pencil.and.outline"
            case .form: return "square.stack.3d.up"
            case .combine: return "circle.grid.cross"
            case .primitives: return "cube"
            }
        }
    }
    @State private var expandedGroup: ToolGroup? = nil

    private func tools(for group: ToolGroup) -> [CADTool] {
        switch group {
        case .draw: return sketchTools
        case .form: return [.pushPull, .hole, .extrude, .fillet, .chamfer, .shell]
        case .combine: return [.booleanUnion, .booleanSubtract, .booleanIntersect]
        case .primitives: return []
        }
    }
    /// Transformación directa en curso: índice del cuerpo arrastrado y acumulado
    /// del gesto en puntos de pantalla (se hornea al B-rep al soltar).
    @State private var dragModelIndex: Int? = nil
    @State private var dragAccum: SIMD2<Float> = .zero
    /// Eje restringido del gizmo durante el drag (nil = drag libre sobre el cuerpo).
    @State private var gizmoAxis: SIMD3<Float>? = nil
    /// Espacio de coordenadas del transform: false = ejes de MUNDO (global),
    /// true = ejes LOCALES del cuerpo (los ejes rotan con `model.rotation`).
    /// Cambia la matemática del gizmo y del drag (spec §Alcance / tarea 3).
    @State private var transformSpaceLocal: Bool = false
    /// Empujón numérico ADITIVO (en unidades de mundo) que el campo de la barra de
    /// transform añade al valor derivado del arrastre. El arrastre y el número son
    /// EL MISMO estado: el número edita este nudge, `transformParams` lo suma al
    /// escalar del drag, y `applyTransformPreview` refresca en vivo.
    @State private var transformNudge: Double = 0
    /// Último detente de snap emitido durante el drag (para disparar el tick háptico
    /// solo al CRUZAR a un nuevo incremento, no cada frame — tarea 2).
    @State private var lastSnapDetent: Double? = nil
    /// Lectura viva de la medida del transform en curso (distancia/ángulo/factor),
    /// mostrada en la guía de la barra durante el arrastre (tarea 4).
    @State private var transformReadout: String = ""

    private static let gizmoNames = ["__gizmoX", "__gizmoY", "__gizmoZ"]

    /// Objetivo activo de transformación (sub-objeto tocado > cuerpo escalado).
    /// Fuente única: resuelve la selección vía `TransformTargetResolver` para que
    /// el gizmo y el drag operen sobre cara/arista/vértice, no solo el cuerpo.
    private var activeTransformTarget: TransformTarget? {
        TransformTargetResolver.target(lastItem: selectionController.lastItem,
                                       bodyIndex: selectionController.bodyIndex)
    }

    /// Centro del gizmo: se ancla al CENTROIDE del objetivo activo (sub-objeto o
    /// cuerpo), no siempre al centro del cuerpo. Solo con una herramienta de
    /// transformación activa.
    private var activeGizmoCenter: SIMD3<Float>? {
        guard [.move, .rotate, .scale].contains(selectedTool),
              let target = activeTransformTarget else { return nil }
        return TransformTargetResolver.center(for: target, in: canvasVM.scene.models)
    }

    private var gizmoLength: Float {
        guard let idx = selectionController.bodyIndex,
              idx < canvasVM.scene.models.count else { return 1.0 }
        return bboxHalfDiagonal(of: canvasVM.scene.models[idx]) * 0.9 + 0.35
    }

    private func bboxCenter(of model: Model) -> SIMD3<Float> {
        var minP = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxP = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for v in model.meshes.first?.vertices ?? [] {
            minP = simd_min(minP, v.position)
            maxP = simd_max(maxP, v.position)
        }
        return minP.x <= maxP.x ? (minP + maxP) * 0.5 : .zero
    }

    private func bboxHalfDiagonal(of model: Model) -> Float {
        var minP = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxP = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for v in model.meshes.first?.vertices ?? [] {
            minP = simd_min(minP, v.position)
            maxP = simd_max(maxP, v.position)
        }
        return minP.x <= maxP.x ? simd_length(maxP - minP) * 0.5 : 0.8
    }

    /// Sincroniza los overlays de flechas del gizmo con la selección/herramienta.
    private func rebuildGizmoOverlays() {
        canvasVM.scene.models.removeAll { Self.gizmoNames.contains($0.name) }
        if let center = activeGizmoCenter {
            let len = gizmoLength
            let axes: [(SIMD3<Float>, SIMD4<Float>, String)] = [
                (SIMD3<Float>(1, 0, 0), SIMD4<Float>(0.97, 0.44, 0.44, 1), "__gizmoX"),
                (SIMD3<Float>(0, 1, 0), SIMD4<Float>(0.20, 0.83, 0.60, 1), "__gizmoY"),
                (SIMD3<Float>(0, 0, 1), SIMD4<Float>(0.30, 0.64, 1.00, 1), "__gizmoZ"),
            ]
            for (axis, color, name) in axes {
                let m = Model(name: name)
                // Rotar = ANILLOS alrededor de cada eje (como Shapr3D);
                // Mover/Escalar = flechas.
                if selectedTool == .rotate {
                    m.meshes = [GizmoBuilder.ringMesh(center: center, axis: axis,
                                                      radius: len * 0.75)]
                } else {
                    m.meshes = [GizmoBuilder.arrowMesh(center: center, axis: axis, length: len)]
                }
                m.color = color
                canvasVM.scene.addModel(m)
            }
        }
        canvasVM.objectWillChange.send()
    }

    /// Reconstruye los overlays del sketch: grid del plano de trabajo + relleno de
    /// regiones cerradas (S4 del BLUEPRINT — el "sombreado mágico" de Shapr3D).
    private func rebuildSketchOverlays() {
        canvasVM.scene.models.removeAll { $0.name == "__workPlaneGrid" || $0.name == "__sketchRegions" }

        guard isSketchTool else { return }

        // Grid del plano de trabajo activo
        let gridModel = Model.workPlaneGrid(plane: sketch.plane,
                                             step: Float(projectSettings.config.gridStep))
        gridModel.name = "__workPlaneGrid"
        canvasVM.scene.addModel(gridModel)

        // Regiones cerradas → relleno sombreado tocable
        let regions = SketchRegionDetector.detectRegions(
            in: sketch.entities, chain: sketch.chain
        )
        if !regions.isEmpty {
            let overlay = SketchRegionOverlay()
            let (fill, stroke) = overlay.generate(for: regions, on: sketch.plane)
            let regionModel = Model(name: "__sketchRegions")
            var meshes: [Mesh] = []
            if let fill = fill { meshes.append(fill) }
            if let stroke = stroke { meshes.append(stroke) }
            regionModel.meshes = meshes
            regionModel.color = SIMD4<Float>(1.0, 0.48, 0.27, 0.22)
            canvasVM.scene.addModel(regionModel)
        }

        canvasVM.objectWillChange.send()
    }

    private var isSketchTool: Bool {
        selectedTool.isSketchTool
    }

    private var transformTools: [CADTool] {
        [.select, .move, .rotate, .scale]
    }

    private var cadTools: [CADTool] {
        // Excluidos por PLACEBO (CATALOGO_HERRAMIENTAS §1): .loft (sin puente Wire,
        // F3), .loopCut y .bevel (operaban sobre índices hardcodeados → "formas
        // extrañas" en device; bisel real = Redondear/Chaflán selectivos), .sweep
        // (path hardcodeado). Regla: placebo detectado = placebo retirado.
        // .pushPull PRIMERO: es el flujo estrella (tap cara → boss/pocket).
        [.pushPull, .extrude, .booleanUnion, .booleanSubtract, .booleanIntersect, .fillet, .chamfer, .shell, .measure]
    }

    private var sketchTools: [CADTool] {
        // Sketch en viewport: línea (cadena), círculo, rectángulo, SPLINE, POLÍGONO.
        [.line, .circle, .rectangle, .spline, .polygon]
    }

    /// `id` alimenta la lógica (performAddPrimitive); `label` es lo visible.
    private var primitiveTools: [(id: String, label: String, icon: String)] {
        [("Box", "Caja", "cube"), ("Sphere", "Esfera", "globe"),
         ("Cylinder", "Cilindro", "cylinder"), ("Cone", "Cono", "cone"),
         ("Torus", "Toro", "torus")]
    }

    @State private var primitiveSize: Float = 1.0

    /// Primer modelo de la escena que conserva su B-rep vivo (nil si ninguno).
    /// Usado por la barra de planos y el botón de features para habilitar/deshabilitar.
    private var firstBRepModel: Model? {
        canvasVM.scene.models.first(where: { $0.cadShape != nil })
    }

    var body: some View {
        VStack(spacing: 0) {
            // El sketch vive EN el viewport (como Shapr3D) — la pantalla 2D
            // aparte (CADSketchView) era el paradigma equivocado.
            tabSelector
            if selectedTab == .model {
                    animationRow
                    parameterBar
                    brepHistoryBar
                    if selectedTool == .pushPull {
                        pushPullBar
                    }
                    if selectionController.hasSelection,
                       [.select, .move, .rotate, .scale].contains(selectedTool) {
                        selectionBar
                    }
                    if isSketchTool {
                        sketchBar
                    }
                    if selectedTool == .hole {
                        holeBar
                    }
                    if selectedTool == .shell {
                        shellBar
                    }
                    if showDrawingExportBar {
                        drawingExportBar
                    }
                    ZStack {
                        ContentView(canvasVM: canvasVM, renderer: renderer, onSurfaceHit: { hit in
                            if selectedTool == .pushPull {
                                pushPullController.selectFace(from: hit, in: canvasVM.scene.models)
                            } else if selectedTool == .measure {
                                // Medición sobre geometría real: primer toque = A,
                                // segundo = B, crea cota 3D persistente. Con SNAP a
                                // vértices/puntos medios y puntos VISIBLES donde tocas
                                // (barrido 2026-07-11: "todo es invisible, sin imán").
                                let snap = MeasureSnapService.snap(
                                    hit: hit, models: canvasVM.scene.models)
                                if snap.kind == .free {
                                    HapticService.shared.light()
                                } else {
                                    HapticService.shared.medium()  // imán capturó
                                }
                                if measurePointA == nil || measurePointB != nil {
                                    measurePointA = snap.position
                                    measurePointB = nil
                                    dimensionManager.removeActive()
                                    showMeasureDot(snap.position, name: "__measureDotA")
                                    clearMeasureDot(named: "__measureDotB")
                                } else {
                                    measurePointB = snap.position
                                    showMeasureDot(snap.position, name: "__measureDotB")
                                    if let a = measurePointA {
                                        let dist = simd_distance(a, snap.position)
                                        toolVM.measurementDistance = dist
                                        // Crear cota 3D persistente
                                        dimensionManager.addLinear(
                                            from: a, to: snap.position,
                                            label: projectSettings.config.format(Double(dist))
                                        )
                                        canvasVM.scene.cadHistory.beginOperation(
                                            "Medición: \(projectSettings.config.format(Double(dist)))",
                                            type: .sketchExtrude,
                                            params: ["distance": Double(dist)]
                                        )
                                    }
                                }
                            } else if selectedTool == .hole {
                                // AGUJERO (patrón universal): tocar la cara taladra
                                // perpendicular; la herramienta sigue activa (encadenable)
                                guard hit.modelIndex < canvasVM.scene.models.count,
                                      canvasVM.scene.models[hit.modelIndex].cadShape != nil
                                else { return }
                                let model = canvasVM.scene.models[hit.modelIndex]
                                BRepHistory.shared.recordChange(of: model)
                                let dir = -SIMD3<Double>(Double(hit.normal.x),
                                                         Double(hit.normal.y),
                                                         Double(hit.normal.z))
                                let p = SIMD3<Double>(Double(hit.position.x),
                                                      Double(hit.position.y),
                                                      Double(hit.position.z))
                                if BRepModeling.drill(model, at: p, direction: dir,
                                                      radius: holeRadius, depth: holeDepth) {
                                    HapticService.shared.medium()
                                    temperTick += 1
                                    canvasVM.objectWillChange.send()
                                } else {
                                    BRepHistory.shared.discardLast()
                                }
                            } else if selectedTool == .shell {
                                // VACIADO por toque (ingeniería inversa §2): la cara
                                // que tocas queda ABIERTA; grosor editable en la barra
                                guard hit.modelIndex < canvasVM.scene.models.count,
                                      let shape = canvasVM.scene.models[hit.modelIndex].cadShape,
                                      let faceIdx = BRepFacePicker.faceIndex(of: shape,
                                                                             nearest: hit.position)
                                else { return }
                                let model = canvasVM.scene.models[hit.modelIndex]
                                BRepHistory.shared.recordChange(of: model)
                                if BRepModeling.shell(model, thickness: shellThicknessTap,
                                                      openFaceIndex: faceIdx,
                                                      outward: shellOutward) {
                                    HapticService.shared.medium()
                                    temperTick += 1
                                    canvasVM.objectWillChange.send()
                                } else {
                                    BRepHistory.shared.discardLast()
                                }
                            } else if [.booleanUnion, .booleanSubtract, .booleanIntersect].contains(selectedTool) {
                                // Booleana por TOQUE (barrido 2026-07-11: los chevrones
                                // A/B eran inusables): tocar un cuerpo = pieza A, tocar
                                // otro = pieza B; Ejecutar queda habilitado en la barra.
                                HapticService.shared.light()
                                guard hit.modelIndex < canvasVM.scene.models.count else { return }
                                let name = canvasVM.scene.models[hit.modelIndex].name
                                if toolVM.csgShapeAIndex == nil {
                                    toolVM.csgShapeAIndex = hit.modelIndex
                                    selectionController.selectBodyFromPanel(
                                        index: hit.modelIndex, models: canvasVM.scene.models)
                                    csgStatusMessage = "A: \(name) — toca la pieza B"
                                } else if hit.modelIndex != toolVM.csgShapeAIndex {
                                    toolVM.csgShapeBIndex = hit.modelIndex
                                    selectionController.selectBodyFromPanel(
                                        index: hit.modelIndex, models: canvasVM.scene.models)
                                    csgStatusMessage = "A + B listas — pulsa Ejecutar"
                                }
                            } else if selectedTool == .select {
                                // Selección unificada (ÁREA 1): cuerpo → cara/arista
                                HapticService.shared.light()
                                selectionController.handleTap(hit: hit, models: canvasVM.scene.models)
                            }
                        },
                        // Tap 2 dedos = deshacer: primero el historial B-rep (features),
                        // si no hay, el de escena. Tap 3 dedos = rehacer.
                        onUndoGesture: {
                            HapticService.shared.light()
                            if BRepHistory.shared.canUndo {
                                if BRepHistory.shared.undo() { canvasVM.objectWillChange.send() }
                            } else {
                                canvasVM.undo()
                            }
                        },
                        onRedoGesture: {
                            HapticService.shared.light()
                            if BRepHistory.shared.canRedo {
                                if BRepHistory.shared.redo() { canvasVM.objectWillChange.send() }
                            } else {
                                canvasVM.redo()
                            }
                        },
                        // Transformación directa: arrastra el cuerpo con la
                        // herramienta activa → preview vivo → bake al B-rep al soltar
                        transformEnabled: [.move, .rotate, .scale].contains(selectedTool),
                        onTransformBegan: { hit in
                            HapticService.shared.light()
                            // Objetivo unificado (cara → push/pull, cuerpo → transform,
                            // arista/vértice → aviso honesto). El toque cae sobre un
                            // cuerpo concreto: restringe el drag de cara a ESE cuerpo.
                            // Sin sub-selección, resuelve al cuerpo tocado.
                            if activeTransformTarget == nil, selectionController.bodyIndex == nil {
                                dragAccum = .zero
                                dragFace = nil
                                dragModelIndex = hit.modelIndex
                                transformNudge = 0
                                lastSnapDetent = nil
                                transformReadout = ""
                                return
                            }
                            beginTransformDrag(hitModelIndex: hit.modelIndex)
                        },
                        onTransformChanged: { dx, dy in
                            dragAccum += SIMD2<Float>(dx, dy)
                            applyTransformPreview()
                        },
                        onTransformEnded: {
                            bakeTransform()
                        },
                        onEmptyTap: {
                            if selectedTool == .select { selectionController.deselect() }
                        },
                        gizmoCenter: activeGizmoCenter,
                        gizmoAxisLength: gizmoLength,
                        gizmoStyle: selectedTool == .rotate ? 1 : 0,
                        onGizmoDragBegan: { axis in
                            HapticService.shared.light()
                            gizmoAxis = axis
                            // El gizmo opera sobre el OBJETIVO resuelto (cara → push/pull
                            // por la normal, cuerpo → transform, arista/vértice → aviso
                            // honesto), no solo el cuerpo. Sin restricción de toque: el
                            // gizmo ya está anclado al sub-objeto activo.
                            beginTransformDrag(hitModelIndex: nil)
                        },
                        // Sketch en viewport: taps = puntos; drag de PENCIL = trazo vivo
                        sketchInputEnabled: isSketchTool,
                        onSketchTap: { p in
                            HapticService.shared.light()
                            // LA mecánica Shapr3D (device 2026-07-13): tap DENTRO
                            // de una región cerrada la SELECCIONA — antes seguía
                            // encadenando geometría encima de la figura.
                            let dPoint = sketch.nearestEditablePointDistance(to: p)
                                ?? .greatestFiniteMagnitude
                            if dPoint > SketchController.snapRadius * 0.8,
                               sketch.selectRegion(at: p) {
                                HapticService.shared.medium()
                                return
                            }
                            sketch.tap(at: p)
                        },
                        onSketchDragBegan: { p in
                            regionDrag = nil
                            let dPoint = sketch.nearestEditablePointDistance(to: p)
                                ?? .greatestFiniteMagnitude
                            // 1) Punto MUY cerca → ajuste fino (radio estrecho: antes
                            //    el centro del círculo robaba el drag de toda el área
                            //    y "picarlo adentro lo deformaba").
                            if dPoint < SketchController.snapRadius * 0.8,
                               sketch.beginDrag(near: p) {
                                HapticService.shared.medium()
                                return
                            }
                            // 2) Dentro de una región cerrada → EXTRUIR POR ARRASTRE
                            if let verts = sketch.region(at: p) {
                                regionDrag = (verts: verts, start: p)
                                regionDragHeight = 0
                                sketch.selectRegion(at: p)
                                HapticService.shared.medium()
                                return
                            }
                            // 3) Punto cercano (radio normal) o trazo libre
                            if sketch.beginDrag(near: p) {
                                HapticService.shared.medium()
                            } else {
                                sketch.pencilDragBegan(at: p)
                            }
                        },
                        onSketchDragChanged: { p in
                            if let rd = regionDrag {
                                // Altura = avance sobre el eje v del plano (arrastrar
                                // hacia arriba en pantalla = crecer). Preview fantasma.
                                let h = Double(max(0, p.y - rd.start.y))
                                regionDragHeight = h
                                updateRegionGhost(verts: rd.verts, height: Float(h))
                                sketch.hint(String(format: "Altura %.2f — suelta para crear", h))
                                return
                            }
                            if sketch.isDraggingPoint {
                                sketch.drag(to: p)
                            } else {
                                sketch.pencilDragChanged(to: p)
                            }
                        },
                        onSketchDragEnded: { p in
                            HapticService.shared.light()
                            if regionDrag != nil {
                                finishRegionDragExtrude()
                                return
                            }
                            if sketch.isDraggingPoint {
                                sketch.endDrag()
                            } else {
                                sketch.pencilDragEnded(at: p)
                            }
                        },
                        sketchPlaneOrigin: sketch.plane.origin,
                        sketchPlaneNormal: sketch.plane.normal,
                        sketchPlaneU: sketch.plane.u,
                        sketchPlaneV: sketch.plane.v,
                        onSketchFaceTap: { hit in handleSketchFaceTap(hit) })
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        // Sketch 2D NÍTIDO en pantalla (líneas finas, puntos,
                        // cotas vivas, relleno de perfiles) — estilo Shapr3D.
                        SketchCanvasOverlay(sketch: sketch, canvasVM: canvasVM)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)

                        // Cotas 3D en viewport (estilo Shapr3D Drawings)
                        if dimensionManager.showDimensions || selectedTool == .measure {
                            MeasurementOverlay(dimensionManager: dimensionManager,
                                              canvasVM: canvasVM)
                                .ignoresSafeArea()
                                .allowsHitTesting(false)
                        }

                        // Preview fantasma de operación activa (extrude/fillet en vivo)
                        if livePreviewEngine.state.isActive,
                           let previewMesh = livePreviewEngine.previewMesh {
                            // El preview se inyecta como modelo overlay temporal
                            Color.clear
                                .onAppear {
                                    let previewModel = Model(name: "__livePreview")
                                    previewModel.meshes = [previewMesh]
                                    previewModel.color = SIMD4<Float>(1.0, 0.48, 0.27, 0.45)
                                    if let edges = livePreviewEngine.previewEdges {
                                        previewModel.edgesMesh = edges
                                    }
                                    canvasVM.scene.models.removeAll { $0.name == "__livePreview" }
                                    canvasVM.scene.addModel(previewModel)
                                    canvasVM.objectWillChange.send()
                                }
                                .onDisappear {
                                    canvasVM.scene.models.removeAll { $0.name == "__livePreview" }
                                    canvasVM.objectWillChange.send()
                                }
                        }

                        // Chrome flotante izquierdo: panel de Elementos arriba,
                        // RAIL de herramientas con flyouts al centro (Shapr3D)
                        VStack(alignment: .leading, spacing: AppTheme.space2) {
                            if showElements {
                                ElementsPanel(canvasVM: canvasVM,
                                              selectionController: selectionController,
                                              sketch: sketch,
                                              renderer: renderer)
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                            }
                            toolRail
                            Spacer()
                        }
                        .padding(.leading, AppTheme.space2)
                        .padding(.top, AppTheme.space2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .topLeading)
                    }
                    .animation(AppTheme.animDefault, value: showElements)
                    .animation(AppTheme.animSnappy, value: expandedGroup)
                    // (El doble tap = encuadrar vive en MetalView — gesto universal.)
                    bottomBar
            } else {
                parametricView
            }
        }
        .onChange(of: selectedTool) { newTool in
            if newTool != .pushPull { pushPullController.clear() }
            // Las herramientas de transformación CONSERVAN la selección de cuerpo
            // (Shapr3D: seleccionas y luego eliges qué hacerle); el resto la limpia.
            if newTool != .select && ![.move, .rotate, .scale].contains(newTool) {
                selectionController.deselect()
            }
            if newTool != .measure {
                measurePointA = nil; measurePointB = nil
                dimensionManager.removeActive()
                clearMeasureDots()
            }
            // Herramienta de dibujo → configurar el sketch en viewport
            // beginTool descarta el dibujo en curso → una nueva línea empieza
            // LIMPIA, no continúa la cadena anterior (bug reportado en device).
            switch newTool {
            case .line: sketch.beginTool(.line)
            case .rectangle: sketch.beginTool(.rectangle)
            case .circle: sketch.beginTool(.circle)
            case .spline: sketch.beginTool(.spline)
            case .polygon: sketch.beginTool(.polygon)
            default: break
            }
            executeCADTool(newTool, canvasVM: canvasVM, toolVM: toolVM)
            rebuildGizmoOverlays()
            rebuildSketchOverlays()
        }
        .onChange(of: sketch.entities.count) { _ in rebuildSketchOverlays() }
        .onChange(of: sketch.chain.count) { _ in rebuildSketchOverlays() }
        .onChange(of: selectionController.outlinedModelId) { newId in
            renderer.outlinedModelId = newId
            canvasVM.objectWillChange.send()
        }
        .onChange(of: selectionController.bodyIndex) { _ in
            rebuildGizmoOverlays()
        }
        .onChange(of: pushPullController.highlightMesh) { newMesh in
            // Sincronizar el overlay de resaltado de cara con la selección actual
            canvasVM.scene.models.removeAll { $0.name == Self.faceHighlightName }
            if let mesh = newMesh {
                let overlay = Model(name: Self.faceHighlightName)
                overlay.meshes = [mesh]
                overlay.color = SIMD4<Float>(1.0, 0.48, 0.27, 1.0)  // brasa: selección activa (IDENTIDAD_FORGE §2)
                canvasVM.scene.addModel(overlay)
            }
            canvasVM.objectWillChange.send()
        }
        .onChange(of: canvasVM.scene.cadHistory.recomputeRequested?.fromNodeID) { nodeID in
            // Recompute paramétrico: una feature editada → reconstruir geometría downstream
            guard let nodeID = nodeID, let node = canvasVM.scene.cadHistory.findNode(with: nodeID) else { return }
            logger.info("[Parametric] recompute requested from '\(node.operation.description)'")
            // Notificar al usuario que el modelo se está reconstruyendo
            temperTick += 1
            // La reconstrucción OCCT real ocurre vía BRepHistory + operaciones en CADModeView
            // El árbol de features es el registro; la geometría se actualiza al re-ejecutar
        }
        .onChange(of: selectionController.highlightMesh) { newMesh in
            // Overlay de cara/arista seleccionada (brasa = activo; "__" = no tocable)
            canvasVM.scene.models.removeAll { $0.name == Self.edgeHighlightName }
            if let mesh = newMesh {
                let overlay = Model(name: Self.edgeHighlightName)
                overlay.meshes = [mesh]
                overlay.color = SIMD4<Float>(1.0, 0.48, 0.27, 1.0)
                canvasVM.scene.addModel(overlay)
            }
            canvasVM.objectWillChange.send()
        }
        .sheet(isPresented: $showMeasurements) {
            NavigationView {
                List {
                    Text(String(format: "Longitud: %.2f mm", toolVM.measurementDistance))
                    Text(String(format: "Area: %.2f mm²", toolVM.measurementArea))
                    Text(String(format: "Volumen: %.3f mm³", toolVM.measurementVolume))
                }.navigationTitle("Mediciones")
            }
        }
        .alert("STEP Export", isPresented: $showStepExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(stepExportMessage)
        }
        .sheet(isPresented: $showCADTimeline) {
            CADTimelineView(historyTree: sketchEngine.historyTree)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showFeatureReport) {
            FeatureReportView(controller: featureReportController)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showExport) {
            // Panel de exportación multi-formato reutilizado tal cual de RenderMode.
            ExportView(
                exportVM: ExportViewModel(exportService: ExportService(device: renderer.device)),
                canvasVM: canvasVM
            )
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = drawingExportController.exportURL {
                ShareSheet(items: [url])
            }
        }
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            // Toggle del panel de Elementos
            Button(action: { HapticService.shared.light(); showElements.toggle() }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13))
                    .foregroundColor(showElements ? theme.accent : theme.textSecondary)
                    .frame(width: 34, height: 26)
            }
            .accessibilityLabel("Panel de elementos")
            ForEach(CADModeTab.allCases, id: \.self) { tab in
                Button(action: { HapticService.shared.light(); selectedTab = tab }) {
                    Text(tab.displayName)
                        .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(selectedTab == tab ? theme.accent.opacity(0.15) : Color.clear)
                        .foregroundColor(selectedTab == tab ? theme.accent : theme.textSecondary)
                        .cornerRadius(theme.cornerRadiusSmall)
                }
            }
            Spacer()
        }
        .background(theme.surface)
    }

    /// Undo/redo de operaciones B-rep (features, push/pull). Visible cuando hay historial.
    @ViewBuilder
    private var brepHistoryBar: some View {
        if brepHistory.canUndo || brepHistory.canRedo {
            HStack(spacing: 14) {
                Button {
                    HapticService.shared.light()
                    if brepHistory.undo() { canvasVM.objectWillChange.send() }
                } label: {
                    Label("Deshacer", systemImage: "arrow.uturn.backward")
                        .font(.caption2)
                }
                .disabled(!brepHistory.canUndo)

                Button {
                    HapticService.shared.light()
                    if brepHistory.redo() { canvasVM.objectWillChange.send() }
                } label: {
                    Label("Rehacer", systemImage: "arrow.uturn.forward")
                        .font(.caption2)
                }
                .disabled(!brepHistory.canRedo)

                Spacer()
                Text("\(brepHistory.undoCount) ops")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(theme.surfaceSecondary)
        }
    }

    /// Barra del push/pull interactivo: estado de selección + distancia + aplicar.
    /// Distancia positiva añade material (boss); negativa excava (pocket).
    private var pushPullBar: some View {
        HStack(spacing: 10) {
            Image(systemName: pushPullController.hasSelection ? "square.stack.3d.up.fill" : "hand.tap")
                .foregroundColor(pushPullController.hasSelection ? theme.accent : theme.textSecondary)
            Text(pushPullController.statusMessage)
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
            Spacer()
            Slider(value: $pushPullController.distance, in: -2.0...2.0)
                .frame(width: 130)
                .disabled(!pushPullController.hasSelection)
            // Valor EDITABLE: toca y escribe la distancia exacta (precisión CAD)
            NumericField(value: $pushPullController.distance, range: -2.0...2.0)
                .disabled(!pushPullController.hasSelection)
            Button(pushPullController.distance >= 0 ? "Añadir" : "Excavar") {
                HapticService.shared.medium()
                if pushPullController.apply() {
                    canvasVM.objectWillChange.send()
                    temperTick += 1  // el metal se templó: operación sólida
                }
            }
            .font(.caption.bold())
            .foregroundColor(pushPullController.distance >= 0 ? theme.accent : AppTheme.accentMuted)
            .disabled(!pushPullController.hasSelection)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary)
        .tempered(trigger: temperTick)
    }

    /// Barra del Agujero: Ø y profundidad editables, encadenable (patrón §0
    /// de INGENIERIA_INVERSA_CAD: la herramienta no te expulsa al terminar).
    private var holeBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.circle")
                .foregroundColor(theme.accent)
            Text("Toca una cara para taladrar ⊥ (encadenable)")
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
            Spacer()
            Text("Ø").font(.caption2).foregroundColor(theme.textSecondary)
            NumericField(value: Binding(get: { holeRadius * 2 },
                                        set: { holeRadius = $0 / 2 }),
                         range: 0.02...4)
            Text("Prof.").font(.caption2).foregroundColor(theme.textSecondary)
            NumericField(value: $holeDepth, range: 0...20)
            Text(holeDepth == 0 ? "pasante" : "ciego")
                .font(.caption2)
                .foregroundColor(AppTheme.steel)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary)
        .tempered(trigger: temperTick)
    }

    /// Barra del Vaciado: tocas la cara que queda ABIERTA, grosor editable.
    private var shellBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.dashed")
                .foregroundColor(theme.accent)
            Text("Toca la cara que quedará ABIERTA")
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
            Spacer()
            // Dirección de la pared (device 2026-07-11: siempre crecía hacia afuera;
            // en CAD el vaciado conserva el contorno exterior por defecto)
            Picker("", selection: $shellOutward) {
                Text("Adentro").tag(false)
                Text("Afuera").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
            Text("Grosor").font(.caption2).foregroundColor(theme.textSecondary)
            NumericField(value: $shellThicknessTap, range: 0.01...2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary)
        .tempered(trigger: temperTick)
    }

    // MARK: - Sketch en viewport (barra + overlays + producción de sólidos)

    /// Barra del sketch: estado, deshacer punto, limpiar; con perfil cerrado
    /// aparecen altura editable + Extruir + Revolucionar (sólidos B-rep REALES).
    private var sketchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil.and.outline")
                .foregroundColor(theme.accent)
            Text(sketch.statusMessage.isEmpty ? "Toca el plano para dibujar (Pencil: traza directo)"
                                              : sketch.statusMessage)
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
            Spacer()
            Button(action: { HapticService.shared.light(); sketch.undoLast() }) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 13))
            }
            .accessibilityLabel("Deshacer punto")
            Button(action: { HapticService.shared.heavy(); sketch.clear() }) {
                Image(systemName: "trash").font(.system(size: 12)).foregroundColor(theme.error)
            }
            .accessibilityLabel("Borrar boceto")

            // Plano sobre cara activo → botón para volver al suelo (TAREA 2)
            if sketch.plane != .floor {
                Button(action: { HapticService.shared.light(); sketch.resetPlaneToFloor() }) {
                    Label("Plano: suelo", systemImage: "square.on.square.dashed")
                        .font(.caption2)
                }
                .accessibilityLabel("Plano de boceto: suelo")
            }

            // Edición de la entidad seleccionada (TAREA 3): parámetros in-situ
            if let idx = sketch.selectedEntityIndex, idx < sketch.entities.count {
                sketchEntityEditControls(index: idx)
            } else if selectedTool == .polygon {
                Text("Lados").font(.caption2).foregroundColor(theme.textSecondary)
                // Stepper numérico para lados del polígono (3-12)
                Stepper(value: $polygonSidesUI, in: 3...12) {
                    Text("\(polygonSidesUI)")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundColor(theme.accent)
                        .frame(width: 20)
                }
                .onChange(of: polygonSidesUI) { v in sketch.polygonSides = v }
            }
            if sketch.splineChain.count >= 2 {
                Button("Fin spline") {
                    HapticService.shared.medium()
                    sketch.finishSpline()
                }
                .font(.caption.bold())
            }
            if sketch.hasExtrudableArea {
                NumericField(value: $sketchExtrudeHeight, range: 0.05...20)
                Button("Extruir") { performSketchExtrude() }
                    .font(.caption.bold())
                NumericField(value: $revolveAngleDeg, range: 5...360, format: "%.0f°")
                Button("Revolucionar") { performSketchRevolve() }
                    .font(.caption)
            }
            if sketch.hasOpenPath {
                Text("Ø").font(.caption2).foregroundColor(theme.textSecondary)
                NumericField(value: $tubeDiameter, range: 0.02...4)
                Button("Tubo") { performSketchTube() }
                    .font(.caption.bold())
            }
            if sketch.hasTwoProfiles {
                Text("↑").font(.caption2).foregroundColor(theme.textSecondary)
                NumericField(value: $loftHeight, range: 0.1...20)
                Button("Transición") { performSketchLoft() }
                    .font(.caption.bold())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary)
        .tempered(trigger: temperTick)
    }

    // (Los overlays 3D del sketch fueron reemplazados por SketchCanvasOverlay:
    //  líneas 2D nítidas en pantalla, como Shapr3D — los tubos 3D se veían
    //  gordos, con quiebres y "contaminantes", feedback device con referencia.)

    /// Controles de edición de la entidad seleccionada (TAREA 3): círculo → R;
    /// polígono → R y Lados; rect → W y H; con botones Eliminar y ✕ (deseleccionar).
    @ViewBuilder
    private func sketchEntityEditControls(index: Int) -> some View {
        // Círculo / polígono: radio editable
        if let r = sketch.selectedRadius {
            Text("R").font(.caption2).foregroundColor(theme.textSecondary)
            NumericField(value: Binding(get: { Double(r) },
                                        set: { sketch.editSelectedRadius(Float($0)) }),
                         range: 0.02...20)
        }
        // Polígono: lados
        if let sides = sketch.selectedSides {
            Text("Lados").font(.caption2).foregroundColor(theme.textSecondary)
            Stepper(value: Binding(get: { sides },
                                   set: { sketch.editSelectedSides($0) }), in: 3...12) {
                Text("\(sides)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundColor(theme.accent)
                    .frame(width: 20)
            }
        }
        // Rect: W y H (recalcula b desde a)
        if let size = sketch.selectedRectSize {
            Text("W").font(.caption2).foregroundColor(theme.textSecondary)
            NumericField(value: Binding(get: { Double(size.w) },
                                        set: { sketch.editSelectedRectSize(w: Float($0), h: size.h) }),
                         range: 0.02...40)
            Text("H").font(.caption2).foregroundColor(theme.textSecondary)
            NumericField(value: Binding(get: { Double(size.h) },
                                        set: { sketch.editSelectedRectSize(w: size.w, h: Float($0)) }),
                         range: 0.02...40)
        }
        Button(role: .destructive) {
            HapticService.shared.heavy()
            sketch.deleteEntity()
        } label: {
            Label("Eliminar", systemImage: "trash").font(.caption)
                .foregroundColor(theme.error)
        }
        Button(action: { HapticService.shared.light(); sketch.deselectEntity() }) {
            Image(systemName: "xmark.circle.fill").foregroundColor(theme.textSecondary)
        }
        .accessibilityLabel("Deseleccionar entidad")
    }

    /// Tap sobre una cara PLANA de un sólido con herramienta de dibujo activa:
    /// planta el plano de trabajo SOBRE la cara (mecánica Shapr3D). Construye la
    /// base ortonormal (u, v) desde la normal del hit.
    private func handleSketchFaceTap(_ hit: SurfaceHit) {
        guard hit.modelIndex < canvasVM.scene.models.count,
              let shape = canvasVM.scene.models[hit.modelIndex].cadShape else { return }
        // Verificar planitud de la cara vía la Face B-rep (isPlanar existe en Face).
        var planar = true
        if let faceIdx = BRepFacePicker.faceIndex(of: shape, nearest: hit.position) {
            let faces = shape.faces()
            if faceIdx >= 0, faceIdx < faces.count {
                planar = faces[faceIdx].isPlanar
            }
        }
        guard planar else {
            sketch.hint("La cara no es plana — no se puede plantar el boceto")
            return
        }
        let normal = simd_normalize(hit.normal)
        // Referencia para el eje u: (0,1,0), o (1,0,0) si es (casi) paralela a la normal.
        let refA = SIMD3<Float>(0, 1, 0)
        let refB = SIMD3<Float>(1, 0, 0)
        let ref = abs(simd_dot(normal, refA)) > 0.98 ? refB : refA
        let u = simd_normalize(simd_cross(normal, ref))
        let v = simd_cross(normal, u)
        sketch.plane = SketchController.WorkPlane(origin: hit.position, u: u, v: v, normal: normal)
        HapticService.shared.medium()
        sketch.hint("Plano de boceto en la cara ✓ — dibuja")
    }

    private func performSketchExtrude() {
        HapticService.shared.medium()
        guard let model = sketch.extrudeClosedArea(height: sketchExtrudeHeight) else { return }
        canvasVM.saveState()
        canvasVM.scene.addModel(model)
        sketch.clear()
        canvasVM.scene.cadHistory.pushOperation(
            CADOperation(type: .sketchExtrude, description: "Extrusión desde boceto",
                         parameters: ["altura": sketchExtrudeHeight]))
        temperTick += 1
        canvasVM.objectWillChange.send()
    }

    private func performSketchTube() {
        HapticService.shared.medium()
        guard let model = sketch.tubeAlongPath(radius: tubeDiameter / 2) else { return }
        canvasVM.saveState()
        canvasVM.scene.addModel(model)
        sketch.clear()
        canvasVM.scene.cadHistory.pushOperation(
            CADOperation(type: .sketchSweep, description: "Tubo por ruta",
                         parameters: ["diámetro": tubeDiameter]))
        temperTick += 1
        canvasVM.objectWillChange.send()
    }

    private func performSketchLoft() {
        HapticService.shared.medium()
        guard let model = sketch.loftProfiles(height: loftHeight) else { return }
        canvasVM.saveState()
        canvasVM.scene.addModel(model)
        sketch.clear()
        canvasVM.scene.cadHistory.pushOperation(
            CADOperation(type: .sketchLoft, description: "Transición (loft)",
                         parameters: ["altura": loftHeight]))
        temperTick += 1
        canvasVM.objectWillChange.send()
    }

    private func performSketchRevolve() {
        HapticService.shared.medium()
        guard let model = sketch.revolveProfile(angle: revolveAngleDeg * .pi / 180) else {
            return
        }
        canvasVM.saveState()
        canvasVM.scene.addModel(model)
        sketch.clear()
        canvasVM.scene.cadHistory.pushOperation(
            CADOperation(type: .sketchRevolve, description: "Revolución desde boceto",
                         parameters: [:]))
        temperTick += 1
        canvasVM.objectWillChange.send()
    }

    // MARK: - Extrusión de región por ARRASTRE (LA mecánica Shapr3D)

    /// Fantasma del prisma mientras arrastras: abanico desde el centroide para la
    /// tapa (regiones convexas/estrelladas — suficiente para preview; el bake usa
    /// el B-rep exacto) + paredes. Naranja translúcido como los live previews.
    private func updateRegionGhost(verts: [SIMD2<Float>], height: Float) {
        guard verts.count >= 3, height > 0.005 else { return }
        let o = sketch.plane.origin, u = sketch.plane.u
        let v = sketch.plane.v, n = sketch.plane.normal
        func world(_ p: SIMD2<Float>, _ h: Float) -> SIMD3<Float> {
            o + u * p.x + v * p.y + n * h
        }
        let c2 = verts.reduce(SIMD2<Float>(0, 0), +) / Float(verts.count)
        var vx: [Vertex] = []
        var ix: [UInt32] = []
        func add(_ p: SIMD3<Float>, _ normal: SIMD3<Float>) -> UInt32 {
            vx.append(Vertex(position: p, normal: normal, uv: .zero))
            return UInt32(vx.count - 1)
        }
        // Tapa superior (abanico centroide) + paredes por segmento
        let topC = add(world(c2, height), n)
        for i in 0..<verts.count {
            let a = verts[i], b = verts[(i + 1) % verts.count]
            let ta = add(world(a, height), n)
            let tb = add(world(b, height), n)
            ix.append(contentsOf: [topC, ta, tb])
            // Pared del segmento a-b
            let wall = simd_normalize(simd_cross(world(b, 0) - world(a, 0), n))
            let ba = add(world(a, 0), wall), bb = add(world(b, 0), wall)
            let wta = add(world(a, height), wall), wtb = add(world(b, height), wall)
            ix.append(contentsOf: [ba, bb, wta, bb, wtb, wta])
        }
        canvasVM.scene.models.removeAll { $0.name == "__regionPreview" }
        let ghost = Model(name: "__regionPreview")
        ghost.meshes = [Mesh(vertices: vx, indices: ix)]
        ghost.color = SIMD4<Float>(1.0, 0.48, 0.27, 0.45)
        canvasVM.scene.addModel(ghost)
        canvasVM.objectWillChange.send()
    }

    /// Suelta el drag de región: crea el sólido B-rep REAL con la altura arrastrada.
    private func finishRegionDragExtrude() {
        defer {
            regionDrag = nil
            canvasVM.scene.models.removeAll { $0.name == "__regionPreview" }
            canvasVM.objectWillChange.send()
        }
        guard let rd = regionDrag, regionDragHeight > 0.02 else {
            sketch.hint("Región lista — arrastra desde adentro para extruir")
            return
        }
        guard let model = sketch.extrudeRegion(vertices: rd.verts,
                                               height: regionDragHeight) else {
            sketch.hint("No se pudo extruir esta región")
            return
        }
        canvasVM.saveState()
        canvasVM.scene.addModel(model)
        canvasVM.scene.cadHistory.pushOperation(
            CADOperation(type: .sketchExtrude, description: "Extrusión por arrastre",
                         parameters: ["altura": regionDragHeight]))
        HapticService.shared.medium()
        temperTick += 1
        sketch.deselectRegion()
        sketch.hint("Sólido creado ✓ — la región sigue ahí para repetir")
        canvasVM.objectWillChange.send()
    }

    /// Punto de medición VISIBLE en el viewport (naranja acento): sabes exactamente
    /// dónde quedó el toque y si el imán capturó una esquina/punto medio.
    private func showMeasureDot(_ p: SIMD3<Float>, name: String) {
        canvasVM.scene.models.removeAll { $0.name == name }
        let dot = Model(name: name)
        dot.meshes = [BRepVertexPicker.highlightDot(at: p, size: 0.035)]
        dot.color = SIMD4<Float>(1.0, 0.48, 0.27, 1.0)
        canvasVM.scene.addModel(dot)
        canvasVM.objectWillChange.send()
    }

    private func clearMeasureDot(named name: String) {
        canvasVM.scene.models.removeAll { $0.name == name }
    }

    private func clearMeasureDots() {
        canvasVM.scene.models.removeAll { $0.name.hasPrefix("__measureDot") }
    }

    /// Aplica una operación de caras (defeature, etc.) a TODAS las caras
    /// seleccionadas, agrupadas por modelo (espejo de applyToSelectedEdges).
    private func applyToSelectedFaces(_ op: (Model, [Int]) -> Bool) {
        HapticService.shared.medium()
        var grouped: [Int: [Int]] = [:]
        for case .face(let m, let f) in selectionController.items {
            grouped[m, default: []].append(f)
        }
        var anyOK = false
        for (modelIndex, faces) in grouped {
            guard modelIndex < canvasVM.scene.models.count else { continue }
            let model = canvasVM.scene.models[modelIndex]
            BRepHistory.shared.recordChange(of: model)
            if op(model, faces) {
                anyOK = true
            } else {
                BRepHistory.shared.discardLast()
            }
        }
        if anyOK {
            selectionController.deselect()
            canvasVM.objectWillChange.send()
            temperTick += 1
        }
    }

    /// Aplica una operación de aristas (fillet/chamfer) a TODAS las aristas
    /// seleccionadas, agrupadas por modelo — una sola op OCCT por modelo para que
    /// las esquinas compartidas se resuelvan juntas (multi-selección real).
    private func applyToSelectedEdges(_ op: (Model, [Int]) -> Bool) {
        HapticService.shared.medium()
        var grouped: [Int: [Int]] = [:]
        for case .edge(let m, let e) in selectionController.items {
            grouped[m, default: []].append(e)
        }
        var anyOK = false
        for (modelIndex, edges) in grouped {
            guard modelIndex < canvasVM.scene.models.count else { continue }
            let model = canvasVM.scene.models[modelIndex]
            BRepHistory.shared.recordChange(of: model)
            if op(model, edges) {
                anyOK = true
            } else {
                BRepHistory.shared.discardLast()
            }
        }
        if anyOK {
            selectionController.deselect()
            canvasVM.objectWillChange.send()
            temperTick += 1
        }
    }

    /// Aplica el patrón LINEAL con los parámetros vivos (cantidad + espaciado).
    /// El espaciado es `patternLinearSpacing` × la diagonal del cuerpo + holgura,
    /// a lo largo de X — mismo eje que el default histórico.
    private func applyLinearPattern(modelIndex: Int) {
        HapticService.shared.medium()
        guard modelIndex < canvasVM.scene.models.count else { return }
        let model = canvasVM.scene.models[modelIndex]
        let width = Double(bboxHalfDiagonal(of: model)) * patternLinearSpacing + 0.4
        let copies = BRepModeling.linearPattern(of: model, count: patternLinearCount,
                                                spacing: SIMD3<Double>(width, 0, 0))
        guard !copies.isEmpty else { return }
        canvasVM.saveState()
        copies.forEach { canvasVM.scene.addModel($0) }
        temperTick += 1
        canvasVM.objectWillChange.send()
    }

    /// Aplica el patrón CIRCULAR con la cantidad viva, alrededor del eje Y por el
    /// origen (mismo default que antes). El motor reparte sobre 360° completos.
    private func applyCircularPattern(modelIndex: Int) {
        HapticService.shared.medium()
        guard modelIndex < canvasVM.scene.models.count else { return }
        let model = canvasVM.scene.models[modelIndex]
        let copies = BRepModeling.circularPattern(of: model, count: patternCircularCount,
                                                  axisOrigin: .zero,
                                                  axisDirection: SIMD3<Double>(0, 1, 0))
        guard !copies.isEmpty else { return }
        canvasVM.saveState()
        copies.forEach { canvasVM.scene.addModel($0) }
        temperTick += 1
        canvasVM.objectWillChange.send()
    }

    /// Barra contextual por SELECCIÓN (menú adaptativo, BLUEPRINT S2): ofrece
    /// exactamente lo que aplica a lo seleccionado — cuerpo/cara/arista.
    @ViewBuilder
    private var selectionBar: some View {
        HStack(spacing: 10) {
            Image(systemName: selectionIcon)
                .foregroundColor(theme.accent)
            Text(selectionController.statusMessage)
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
            Spacer()

            // ---- Cuerpo escalado: acciones de cuerpo entero ----
            if let modelIndex = selectionController.bodyIndex {
                Button("Reflejar") {
                    HapticService.shared.medium()
                    guard modelIndex < canvasVM.scene.models.count else { return }
                    if let copy = BRepModeling.mirroredCopy(of: canvasVM.scene.models[modelIndex]) {
                        canvasVM.saveState()
                        canvasVM.scene.addModel(copy)
                        temperTick += 1
                        canvasVM.objectWillChange.send()
                    }
                }
                .font(.caption)

                // Patrón LINEAL con parámetros (cantidad + espaciado) en un popover
                // compacto — antes ×3 y espaciado fijos.
                Menu {
                    Stepper("Copias: \(patternLinearCount)",
                            value: $patternLinearCount, in: 2...24)
                    Stepper(String(format: "Espaciado: %.1f×", patternLinearSpacing),
                            value: $patternLinearSpacing, in: 0.5...5.0, step: 0.1)
                    Button("Aplicar patrón lineal") { applyLinearPattern(modelIndex: modelIndex) }
                } label: {
                    Label("Patrón ↹", systemImage: "rectangle.grid.1x2")
                        .font(.caption)
                }

                // Patrón CIRCULAR con cantidad configurable (arco: siempre 360°).
                Menu {
                    Stepper("Copias: \(patternCircularCount)",
                            value: $patternCircularCount, in: 2...36)
                    Button("Aplicar patrón circular") { applyCircularPattern(modelIndex: modelIndex) }
                } label: {
                    Label("Patrón ○", systemImage: "circle.grid.cross")
                        .font(.caption)
                }

                Button(role: .destructive) {
                    HapticService.shared.heavy()
                    guard modelIndex < canvasVM.scene.models.count else { return }
                    canvasVM.saveState()
                    canvasVM.scene.models.remove(at: modelIndex)
                    selectionController.deselect()
                    canvasVM.objectWillChange.send()
                } label: {
                    Label("Eliminar", systemImage: "trash")
                        .font(.caption)
                        .foregroundColor(theme.error)
                }
            } else {
                // ---- Caras/aristas (multi): acciones directas + escalar ----
                if case .face? = selectionController.lastItem {
                    Button("Push/Pull") {
                        HapticService.shared.medium()
                        if let hit = selectionController.lastHit {
                            selectedTool = .pushPull
                            toolVM.selectedTool = .pushPull
                            pushPullController.selectFace(from: hit, in: canvasVM.scene.models)
                        }
                    }
                    .font(.caption.bold())
                    // DEFEATURE (ingeniería inversa — Shapr3D no lo tiene): elimina
                    // las caras seleccionadas (agujero/fillet/bolsillo) y OCCT sana
                    // el sólido reconectando la topología.
                    Button("Quitar") {
                        applyToSelectedFaces { model, faces in
                            BRepModeling.removeFaces(model, faceIndices: faces)
                        }
                    }
                    .font(.caption.bold())
                }
                if case .edge? = selectionController.lastItem {
                    Slider(value: $edgeFilletRadius, in: 0.01...0.5)
                        .frame(width: 110)
                    NumericField(value: $edgeFilletRadius, range: 0.01...0.5)
                    // Radio FINAL opcional → fillet VARIABLE a lo largo de la arista
                    // (transición suave inicial→final, nivel Fusion). 0 = uniforme.
                    Text("→").font(.caption2).foregroundColor(theme.textSecondary)
                    NumericField(value: $edgeFilletRadiusEnd, range: 0...0.5)
                    // Multi-arista REAL (barrido 2026-07-11: antes solo operaba la
                    // última): ambas acciones toman TODAS las aristas seleccionadas.
                    Button("Redondear") {
                        let end = edgeFilletRadiusEnd
                        applyToSelectedEdges { model, edges in
                            if end > 0.009, abs(end - edgeFilletRadius) > 1e-4 {
                                return BRepModeling.filletEdgesVariable(
                                    model, edgeIndices: edges,
                                    startRadius: edgeFilletRadius, endRadius: end)
                            }
                            return BRepModeling.filletEdges(model, edgeIndices: edges,
                                                            radius: edgeFilletRadius)
                        }
                    }
                    .font(.caption.bold())
                    Button("Chaflán") {
                        applyToSelectedEdges { model, edges in
                            BRepModeling.chamferEdges(model, edgeIndices: edges,
                                                      distance: Double(edgeFilletRadius))
                        }
                    }
                    .font(.caption.bold())
                }
                // Escalar la selección al cuerpo completo (mover/duplicar/eliminar)
                Button("Cuerpo") {
                    HapticService.shared.light()
                    selectionController.escalateToBody(models: canvasVM.scene.models)
                }
                .font(.caption)
            }

            Button(action: { selectionController.deselect() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(theme.textSecondary)
            }
            .accessibilityLabel("Deseleccionar")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary)
        .tempered(trigger: temperTick)
    }

    private var selectionIcon: String {
        if selectionController.bodyIndex != nil { return "cube" }
        switch selectionController.lastItem {
        case .face?: return "square.fill.on.square"
        case .edge?: return "angle"
        case .vertex?: return "circle.fill"
        case nil: return "hand.tap"
        }
    }

    /// Barra contextual de exportación de planos (DXF/PDF): selector de vista + botones de formato.
    /// Aparece cuando el usuario activa el botón de plano en el animationRow.
    /// El share sheet se presenta automáticamente tras un export exitoso.
    private var drawingExportBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: drawingExportController.exportURL != nil
                      ? "checkmark.circle.fill" : "doc.viewfinder")
                    .foregroundColor(drawingExportController.exportURL != nil
                                     ? theme.success : theme.accent)
                Text(drawingExportController.statusMessage)
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
                Spacer()
                if drawingExportController.isBusy {
                    ProgressView().controlSize(.mini)
                }
            }
            HStack(spacing: 8) {
                Text("Vista:").font(.caption2).foregroundColor(theme.textSecondary)
                Picker("Vista", selection: $drawingExportController.selectedView) {
                    ForEach(DrawingExportService.StandardView.allCases, id: \.self) { v in
                        Text(v.displayName).tag(v)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: drawingExportController.selectedView) { _ in
                    // Limpiar URL anterior cuando el usuario cambia la vista proyectada
                    drawingExportController.reset()
                }
                Spacer()
                Button("DXF") {
                    HapticService.shared.medium()
                    if let model = firstBRepModel {
                        let ok = drawingExportController.exportDXF(model: model)
                        if ok { showShareSheet = true }
                    }
                }
                .font(.caption.bold())
                .disabled(drawingExportController.isBusy || firstBRepModel == nil)

                Button("PDF") {
                    HapticService.shared.medium()
                    if let model = firstBRepModel {
                        let ok = drawingExportController.exportPDF(model: model)
                        if ok { showShareSheet = true }
                    }
                }
                .font(.caption.bold())
                .disabled(drawingExportController.isBusy || firstBRepModel == nil)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary)
    }

    private var parametricView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Historial de operaciones")
                    .font(.caption)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text("\(canvasVM.scene.cadHistory.getActiveOperationChain().count) ops")
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(theme.surfaceSecondary)

            List {
                ForEach(canvasVM.scene.cadHistory.getActiveOperationChain(), id: \.id) { op in
                    HStack {
                        Circle()
                            .fill(op.id == canvasVM.scene.cadHistory.currentNode?.operation.id ? theme.accent : theme.textSecondary)
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(op.description)
                                .font(.system(size: 11))
                                .foregroundColor(op.id == canvasVM.scene.cadHistory.currentNode?.operation.id ? theme.textPrimary : theme.textSecondary)
                            if !op.parameters.isEmpty {
                                Text(op.parameters.map { "\($0.key): \(String(format: "%.2f", $0.value))" }.joined(separator: ", "))
                                    .font(.system(size: 8))
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        Spacer()
                        Text(op.timestamp, style: .time)
                            .font(.system(size: 8))
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
            .listStyle(.plain)

            Divider()
            ConstraintOverlayView(
                constraintManager: sketchEngine.constraintManager,
                snapPoints: snapPoints,
                activeSnapPoint: constraintEngine.currentSnapPoint
            )
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Rail vertical de herramientas (anatomía Shapr3D)

    /// Columna izquierda: transformaciones siempre visibles + grupos con FLYOUT
    /// animado (Dibujo/Formar/Combinar/Primitivas) + Medir. La tira horizontal
    /// de chips murió aquí.
    private var toolRail: some View {
        HStack(alignment: .top, spacing: AppTheme.space1) {
            VStack(spacing: 2) {
                ForEach(transformTools, id: \.self) { tool in
                    railToolButton(tool)
                }
                Rectangle().fill(theme.border).frame(width: 22, height: 1)
                    .padding(.vertical, 3)
                ForEach(ToolGroup.allCases) { group in
                    Button(action: {
                        HapticService.shared.light()
                        expandedGroup = (expandedGroup == group) ? nil : group
                    }) {
                        Image(systemName: group.icon)
                            .font(.system(size: 15))
                            .frame(width: 40, height: 38)
                            .foregroundColor(expandedGroup == group ? theme.accent
                                                                     : theme.textSecondary)
                            .toolbarGlow(active: expandedGroup == group)
                    }
                    .accessibilityLabel(group.rawValue)
                }
                Rectangle().fill(theme.border).frame(width: 22, height: 1)
                    .padding(.vertical, 3)
                railToolButton(.measure)
            }
            .padding(5)
            .glassPanel()

            if let group = expandedGroup {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.rawValue.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.1)
                        .foregroundColor(AppTheme.textTertiary)
                        .padding(.horizontal, 8).padding(.top, 4)
                    if group == .primitives {
                        ForEach(primitiveTools.indices, id: \.self) { idx in
                            let prim = primitiveTools[idx]
                            flyoutButton(icon: prim.icon, label: prim.label,
                                         active: false) {
                                performAddPrimitive(prim.id)
                            }
                        }
                    } else {
                        ForEach(tools(for: group), id: \.self) { tool in
                            flyoutButton(icon: tool.icon, label: tool.displayName,
                                         active: selectedTool == tool) {
                                activate(tool)
                            }
                        }
                    }
                }
                .padding(5)
                .glassPanel()
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }

    /// Botón de rail (icono solo, 40pt) para herramientas siempre visibles.
    private func railToolButton(_ tool: CADTool) -> some View {
        Button(action: { activate(tool) }) {
            Image(systemName: tool.icon)
                .font(.system(size: 15, weight: selectedTool == tool ? .medium : .regular))
                .frame(width: 40, height: 38)
                .foregroundColor(selectedTool == tool ? theme.accent : theme.textSecondary)
                .toolbarGlow(active: selectedTool == tool)
        }
        .accessibilityLabel(tool.displayName)
    }

    /// Botón de flyout (icono + etiqueta) con estética calma.
    private func flyoutButton(icon: String, label: String, active: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: { HapticService.shared.light(); action() }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 12, weight: active ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .frame(width: 148, alignment: .leading)
            .foregroundColor(active ? theme.accent : theme.textPrimary)
            .background(active ? theme.accent.opacity(0.12) : Color.clear)
            .cornerRadius(AppTheme.radiusSM)
        }
    }

    /// Activación central de herramienta (rail y flyouts): un solo camino.
    private func activate(_ tool: CADTool) {
        HapticService.shared.light()
        selectedTool = tool
        toolVM.selectedTool = tool
        if [.booleanUnion, .booleanSubtract, .booleanIntersect].contains(tool) {
            startCSGOperation(tool)
        } else if tool == .extrude {
            // Extruir desde el flyout Formar: si hay área cerrada (perfil o
            // región por intersección) la extruye; si no, guía al usuario.
            if sketch.hasExtrudableArea {
                performSketchExtrude()
            } else {
                sketch.hint("Dibuja un perfil o área cerrada y toca «Extruir»")
            }
        } else if ![.select, .move, .rotate, .scale, .pushPull, .hole, .shell, .extrude].contains(tool),
                  !tool.isSketchTool, tool != .measure {
            executeSelectedTool()
        }
        expandedGroup = nil   // el flyout se recoge al elegir
    }

    // (toolButton horizontal eliminado: el rail vertical con flyouts es el
    //  único camino de activación — activate(_:).)

    private func executeSelectedTool() {
        // Objetivo: el CUERPO seleccionado; sin selección, el primero (legacy).
        // Antes las barras "Aplicar" pegaban SIEMPRE a models[0] — con varios
        // cuerpos en escena la operación caía en uno que no estabas mirando.
        let idx = selectionController.bodyIndex ?? 0
        guard idx < canvasVM.scene.models.count else { return }
        let model = canvasVM.scene.models[idx]

        // Ruta B-rep REAL para las barras globales (fillet/chamfer/shell).
        if model.cadShape != nil, [.fillet, .chamfer, .shell].contains(selectedTool) {
            BRepHistory.shared.recordChange(of: model)
            let ok: Bool
            switch selectedTool {
            case .fillet:
                ok = BRepModeling.fillet(model, radius: Double(toolVM.filletRadius))
            case .chamfer:
                ok = BRepModeling.chamfer(model, distance: Double(toolVM.chamferRadius))
            default:
                ok = BRepModeling.shell(model, thickness: Double(toolVM.shellThickness),
                                        outward: shellOutward)
            }
            if ok {
                HapticService.shared.medium()
                temperTick += 1
            } else {
                BRepHistory.shared.discardLast()
                selectionController.showHint("La operación falló en \(model.name)")
            }
            canvasVM.objectWillChange.send()
            return
        }

        // Legacy malla (modelos sin B-rep)
        guard var mutableMesh = model.meshes.first else { return }
        toolVM.executeTool(mesh: &mutableMesh)
        if !model.meshes.isEmpty {
            model.meshes[0] = mutableMesh
        }
        canvasVM.objectWillChange.send()
    }

    @ViewBuilder
    private var parameterBar: some View {
        VStack(spacing: 0) {
            switch selectedTool {
            case .extrude:
                HStack {
                    Text("Dist:").font(.caption).foregroundColor(theme.textPrimary)
                    Slider(value: $extrudeDistance, in: 0.01...2.0)
                        .frame(width: 120)
                    Text(String(format: "%.2f", extrudeDistance))
                        .font(.caption).foregroundColor(theme.textPrimary).frame(width: 35)
                    // Añadir vs Cortar: solo relevante con un cuerpo objetivo seleccionado
                    // (booleano). Sin objetivo, la extrusión siempre AÑADE (cuerpo nuevo).
                    Picker("", selection: $extrudeCut) {
                        Text("Añadir").tag(false)
                        Text("Cortar").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                    .disabled(selectionController.bodyIndex == nil)
                    Spacer()
                    if isExtruding {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Extruir") {
                            performExtrusion()
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(sketch.entities.isEmpty)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(theme.surfaceSecondary)
            case .fillet:
                HStack {
                    Text("Radio:").font(.caption).foregroundColor(theme.textPrimary)
                    Slider(value: $toolVM.filletRadius, in: 0.01...0.5)
                        .frame(width: 120)
                    Text(String(format: "%.2f", toolVM.filletRadius))
                        .font(.caption).foregroundColor(theme.textPrimary).frame(width: 35)
                    Spacer()
                    Button("Aplicar") { executeSelectedTool() }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(theme.surfaceSecondary)
            case .chamfer:
                HStack {
                    // Chaflán = corte plano por DISTANCIA (no radio — eso es Redondear)
                    Text("Distancia:").font(.caption).foregroundColor(theme.textPrimary)
                    Slider(value: $toolVM.chamferRadius, in: 0.01...0.5)
                        .frame(width: 120)
                    Text(String(format: "%.2f", toolVM.chamferRadius))
                        .font(.caption).foregroundColor(theme.textPrimary).frame(width: 35)
                    Spacer()
                    Button("Aplicar") { executeSelectedTool() }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(theme.surfaceSecondary)
            case .shell:
                HStack {
                    Text("Grosor:").font(.caption).foregroundColor(theme.textPrimary)
                    Slider(value: $toolVM.shellThickness, in: 0.005...0.2)
                        .frame(width: 120)
                    Text(String(format: "%.3f", toolVM.shellThickness))
                        .font(.caption).foregroundColor(theme.textPrimary).frame(width: 40)
                    Spacer()
                    Button("Aplicar") { executeSelectedTool() }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(theme.surfaceSecondary)
            case .loft:
                HStack {
                    Text("Loft entre 2 perfiles (copia desplazada en Z)")
                        .font(.caption).foregroundColor(theme.textPrimary)
                    Spacer()
                    Button("Ejecutar") { executeSelectedTool() }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(theme.surfaceSecondary)
            case .sweep:
                HStack {
                    Text("Altura:").font(.caption).foregroundColor(theme.textPrimary)
                    Slider(value: $toolVM.sweepHeight, in: 0.1...2.0)
                        .frame(width: 120)
                    Text(String(format: "%.2f", toolVM.sweepHeight))
                        .font(.caption).foregroundColor(theme.textPrimary).frame(width: 35)
                    Spacer()
                    Button("Aplicar") { executeSelectedTool() }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(theme.surfaceSecondary)
            case .booleanUnion, .booleanSubtract, .booleanIntersect:
                csgParameterBar
            case .measure:
                // Medición sobre el visor real (MeasureTool legacy tenía su propio
                // mini-viewport con cámara falsa y congelaba la app — eliminado).
                HStack(spacing: 10) {
                    Image(systemName: "ruler")
                        .foregroundColor(AppTheme.steel)
                    Text(measurePointB != nil ? "Distancia medida"
                         : (measurePointA != nil ? "Toca el punto B en el modelo"
                                                 : "Toca el punto A en el modelo"))
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    if measurePointA != nil, measurePointB != nil {
                        Text(String(format: "%.2f mm", toolVM.measurementDistance))
                            .font(.caption.monospacedDigit().bold())
                            .foregroundColor(AppTheme.steel)
                        Button(action: { measurePointA = nil; measurePointB = nil }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12))
                        }
                        .accessibilityLabel("Reiniciar medición")
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(theme.surfaceSecondary)
            default:
                EmptyView()
            }
        }
    }

    /// Fila de utilidades: agrupar, historial, exports, features. Los booleanos
    /// viven SOLO en el toolbar de herramientas (antes había una segunda copia aquí
    /// con comportamiento distinto — dos caminos para la misma acción es un bug de UX).
    private var animationRow: some View {
        HStack {
            // Menú Archivo compacto (New / Save)
            Menu {
                Button(action: { newProject() }) {
                    Label("Nuevo proyecto", systemImage: "doc.badge.plus")
                }
                Button(action: { saveProject() }) {
                    Label("Guardar", systemImage: "square.and.arrow.down")
                }
                .disabled(canvasVM.scene.models.isEmpty)
                Button(action: { exportToSTEP() }) {
                    Label("Exportar STEP", systemImage: "square.and.arrow.up")
                }
                .disabled(canvasVM.scene.models.isEmpty)
                Button(action: { showExport = true }) {
                    Label("Exportar...", systemImage: "square.and.arrow.up.on.square")
                }
                .disabled(canvasVM.scene.models.isEmpty)
                Divider()
                Button(action: { showShareSheet = true }) {
                    Label("Compartir...", systemImage: "paperplane")
                }
                .disabled(drawingExportController.exportURL == nil)
            } label: {
                Image(systemName: "doc")
                    .font(.system(size: 12))
                    .foregroundColor(theme.accent)
            }
            .accessibilityLabel("Archivo")

            Rectangle().fill(theme.border).frame(width: 1, height: 16)

            Button(action: { performGroupAssembly() }) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 11))
                    .foregroundColor(canvasVM.scene.models.count >= 2 ? theme.accent : theme.textSecondary)
            }
            .disabled(canvasVM.scene.models.count < 2)
            .help("Agrupar ensamblaje")
            .accessibilityLabel("Agrupar ensamblaje")

            Spacer()

            Button(action: { showCADTimeline = true }) {
                Image(systemName: "timeline.selection")
                    .font(.system(size: 11))
                    .foregroundColor(theme.accent)
            }
            .help("Timeline CAD")

            Button(action: { exportToSTEP() }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11))
                    .foregroundColor(theme.accent)
            }
            .disabled(canvasVM.scene.models.isEmpty)

            Button(action: {
                HapticService.shared.light()
                if showDrawingExportBar { drawingExportController.reset() }
                showDrawingExportBar.toggle()
            }) {
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 11))
                    .foregroundColor(showDrawingExportBar ? theme.accent
                                     : (firstBRepModel != nil ? theme.textPrimary : theme.textSecondary))
            }
            .disabled(firstBRepModel == nil)
            .help("Exportar plano DXF / PDF")

            Button(action: {
                HapticService.shared.light()
                if let model = firstBRepModel {
                    featureReportController.analyze(model: model)
                    showFeatureReport = true
                }
            }) {
                Image(systemName: "wand.and.rays")
                    .font(.system(size: 11))
                    .foregroundColor(firstBRepModel != nil ? theme.accent : theme.textSecondary)
            }
            .disabled(firstBRepModel == nil)
            .help("Reconocer features de fabricación")
        }.padding(.horizontal, 6).padding(.vertical, 2)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Toggle("Snap", isOn: $toolVM.gridSnapEnabled).toggleStyle(.switch).font(.caption)
            // ("Guías" eliminado: su overlay dependía del snap-drag legacy retirado;
            //  el snap real vive dentro del sketch — regla anti-placebo.)
            // Rayos X: cuerpos translúcidos, aristas visibles (look Shapr3D)
            Button(action: {
                HapticService.shared.light()
                renderer.xrayEnabled.toggle()
                xrayOn = renderer.xrayEnabled
                canvasVM.objectWillChange.send()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 11))
                    Text("Rayos X").font(.caption2)
                }
                .foregroundColor(xrayOn ? theme.accent : theme.textSecondary)
            }
            .accessibilityLabel("Modo rayos X")
            Spacer()
            Button("Mediciones") { showMeasurements.toggle() }.font(.caption)
        }.padding(.horizontal).padding(.vertical, 4).background(theme.surface)
    }

    // MARK: - File Operations

    private func newProject() {
        HapticService.shared.medium()
        canvasVM.saveState()
        canvasVM.scene.models.removeAll { !$0.name.hasPrefix("__") }
        canvasVM.scene.cadHistory.clear()
        brepHistory.clear()
        sketch.clear()
        dimensionManager.clearAll()
        selectionController.deselect()
        canvasVM.objectWillChange.send()
    }

    private func saveProject() {
        HapticService.shared.medium()
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let name = "AppForge_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
            .replacingOccurrences(of: "/", with: "-")
        do {
            let url = try ProjectPersistenceService.shared.saveProject(
                name: name,
                scene: canvasVM.scene,
                config: projectSettings.config,
                to: docs
            )
            stepExportMessage = "Proyecto guardado: \(url.lastPathComponent)"
            showStepExportAlert = true
            ProjectPersistenceService.shared.markProjectOpened(url)
        } catch {
            stepExportMessage = "Error al guardar: \(error.localizedDescription)"
            showStepExportAlert = true
        }
    }

    /// Exporta la escena como STEP usando la primera entidad B-rep encontrada.
    private func exportToSTEP() {
        let lines = sketchEngine.getSketchLines()

        if lines.isEmpty {
            var modelLines: [(CGPoint, CGPoint)] = []
            for model in canvasVM.scene.models {
                for mesh in model.meshes {
                    let verts = mesh.vertices
                    for i in stride(from: 0, to: verts.count - 1, by: 2) {
                        if i + 1 < verts.count {
                            let p1 = CGPoint(x: CGFloat(verts[i].position.x), y: CGFloat(verts[i].position.y))
                            let p2 = CGPoint(x: CGFloat(verts[i + 1].position.x), y: CGFloat(verts[i + 1].position.y))
                            modelLines.append((p1, p2))
                        }
                    }
                }
            }

            if modelLines.isEmpty {
                stepExportMessage = "No sketch lines available to export"
                showStepExportAlert = true
                return
            }

            let exportService = ExportServiceSTEP()

            guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let outputURL = documentsDir.appendingPathComponent("export_\(UUID().uuidString.prefix(8)).stp")

            do {
                _ = try exportService.exportToSTEP(sketchLines: modelLines, outputURL: outputURL)
                stepExportMessage = "STEP exported to \(outputURL.lastPathComponent)"
                showStepExportAlert = true
            } catch {
                stepExportMessage = "Export failed: \(error.localizedDescription)"
                showStepExportAlert = true
            }
        } else {
            let exportService = ExportServiceSTEP()

            guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let outputURL = documentsDir.appendingPathComponent("sketch_\(UUID().uuidString.prefix(8)).stp")

            do {
                _ = try exportService.exportToSTEP(sketchLines: lines, outputURL: outputURL)
                stepExportMessage = "STEP exported to \(outputURL.lastPathComponent)"
                showStepExportAlert = true
            } catch {
                stepExportMessage = "Export failed: \(error.localizedDescription)"
                showStepExportAlert = true
            }
        }
    }

    /// Extruye la región cerrada ACTIVA del sketch vivo (`SketchController`) a un
    /// sólido B-rep REAL y lo commitea a la escena. Reemplaza el no-op muerto que
    /// pasaba por `CADSketchEngine`. Sigue el contrato puro Agente 2→1:
    /// `extrudedShapeForActiveRegion` da el prisma; esta capa decide el commit:
    ///   · sin cuerpo objetivo → cuerpo NUEVO.
    ///   · con cuerpo seleccionado (`selectionController.bodyIndex`) → booleano
    ///     Añadir (unión) o Cortar (resta) según el toggle `extrudeCut`.
    private func performExtrusion() {
        guard !sketch.entities.isEmpty else {
            sketch.hint("Dibuja una región cerrada para extruir")
            return
        }
        let distance = Double(extrudeDistance)
        guard let shape = sketch.extrudedShapeForActiveRegion(distance: distance),
              let mesh = OCCTBridge.toMesh(shape, quality: .medium) else {
            sketch.hint("No hay región cerrada válida para extruir")
            return
        }

        // Sólido resultante de la extrusión (el prisma).
        let solid = Model(name: "Extrusión_\(UUID().uuidString.prefix(6))")
        solid.cadShape = shape
        solid.meshes = [mesh]
        solid.edgesMesh = OCCTBridge.edgesMesh(shape)

        canvasVM.saveState()

        // ¿Hay cuerpo objetivo seleccionado? → booleano Añadir/Cortar contra él.
        if let bi = selectionController.bodyIndex, bi < canvasVM.scene.models.count,
           canvasVM.scene.models[bi].cadShape != nil {
            let target = canvasVM.scene.models[bi]
            let op: CADOperationType = extrudeCut ? .booleanSubtract : .booleanUnion
            if let result = BRepModeling.boolean(op, target, solid) {
                result.color = target.color
                canvasVM.scene.models[bi] = result
                selectionController.deselect()
                finishExtrudeCommit(cut: extrudeCut, distance: distance,
                                    message: extrudeCut ? "Corte aplicado ✓" : "Material añadido ✓")
                return
            }
            // El booleano falló (geometría degenerada): cae a cuerpo nuevo honesto.
            sketch.hint("El booleano falló — se creó como cuerpo independiente")
        }

        // Cuerpo nuevo (sin objetivo o tras fallo del booleano).
        canvasVM.scene.addModel(solid)
        finishExtrudeCommit(cut: false, distance: distance, message: "Sólido creado ✓")
    }

    /// Cierre común del commit de extrusión: historia paramétrica + feedback.
    private func finishExtrudeCommit(cut: Bool, distance: Double, message: String) {
        canvasVM.scene.cadHistory.pushOperation(
            CADOperation(type: .sketchExtrude,
                         description: cut ? "Extrusión (cortar)" : "Extrusión (añadir)",
                         parameters: ["altura": distance]))
        HapticService.shared.medium()
        temperTick += 1
        selectedTool = .select
        sketch.deselectRegion()
        sketch.hint(message)
        canvasVM.objectWillChange.send()
    }

    private func cycleTool(direction: Int) {
        let allTools: [CADTool] = [.select, .move, .rotate, .scale,
                                    .extrude, .loopCut, .bevel, .booleanUnion, .booleanSubtract,
                                    .booleanIntersect, .fillet, .chamfer, .shell, .loft, .sweep, .measure,
                                    .line, .circle, .rectangle, .arc, .dimension, .constraint]
        guard let currentIndex = allTools.firstIndex(of: selectedTool) else { return }
        let newIndex = (currentIndex + direction + allTools.count) % allTools.count
        selectedTool = allTools[newIndex]
        toolVM.selectedTool = selectedTool
        HapticService.shared.selection()
    }

    // MARK: - Transformación directa (Mover/Rotar/Escalar)

    /// Parámetros del gesto acumulado, interpretados según herramienta y eje del
    /// gizmo (nil = libre). Fuente única de verdad para preview Y bake.
    ///
    /// El escalar activo (distancia / ángulo / factor) = valor derivado del ARRASTRE
    /// (`transformRawScalar`) + el empujón numérico de la barra (`transformNudge`),
    /// cuantizado por snap si `toolVM.gridSnapEnabled`. Arrastre y número son el
    /// mismo estado (tareas 1-2). El `axis` respeta el toggle local/global (tarea 3).
    private func transformParams(for model: Model) -> (delta: SIMD3<Float>, angle: Float, axis: SIMD3<Float>, factor: Float, center: SIMD3<Float>) {
        let axis = constrainedAxis(for: model)
        let scalar = transformScalar(for: model)   // ya incluye nudge + snap

        let delta: SIMD3<Float>
        let angle: Float
        let factor: Float
        switch selectedTool {
        case .move:
            if let a = axis {
                delta = a * Float(scalar)
            } else {
                // Libre (sin eje): mueve en el plano de cámara con el bruto del gesto.
                let cam = canvasVM.scene.camera
                let forward = simd_normalize(cam.target - cam.position)
                let right = simd_normalize(simd_cross(forward, cam.up))
                let up = simd_cross(right, forward)
                let k = simd_length(cam.position - cam.target) * 0.0011
                delta = right * dragAccum.x * k - up * dragAccum.y * k
            }
            angle = 0
            factor = 1
        case .rotate:
            delta = .zero
            angle = Float(scalar)   // radianes
            factor = 1
        case .scale:
            delta = .zero
            angle = 0
            factor = max(0.05, min(20, Float(scalar)))
        default:
            delta = .zero; angle = 0; factor = 1
        }
        let rotAxis = axis ?? SIMD3<Float>(0, 1, 0)
        return (delta, angle, rotAxis, factor, bboxCenter(of: model))
    }

    /// Eje sobre el que opera el transform, YA resuelto a MUNDO. En modo global es
    /// el eje del gizmo tal cual; en modo LOCAL se rota por `model.rotation` (los
    /// ejes viajan con el cuerpo — tarea 3). `nil` = drag libre (sin restricción).
    private func constrainedAxis(for model: Model) -> SIMD3<Float>? {
        guard let axis = gizmoAxis else { return nil }
        if transformSpaceLocal {
            return simd_normalize(model.rotation.act(axis))
        }
        return axis
    }

    /// Valor BRUTO del arrastre (sin nudge, sin snap), en unidades naturales de la
    /// herramienta: distancia de mundo (mover), radianes (rotar), factor (escalar).
    /// Es la proyección del gesto en pantalla — idéntica a la matemática histórica.
    private func transformRawScalar(for model: Model) -> Double {
        let cam = canvasVM.scene.camera
        let forward = simd_normalize(cam.target - cam.position)
        let right = simd_normalize(simd_cross(forward, cam.up))
        let up = simd_cross(right, forward)
        let dist = simd_length(cam.position - cam.target)
        let k = dist * 0.0011

        switch selectedTool {
        case .move:
            guard let axis = constrainedAxis(for: model) else {
                return Double(simd_length(dragAccum) * k)
            }
            var axisScreen = SIMD2<Float>(simd_dot(axis, right), -simd_dot(axis, up))
            let l = simd_length(axisScreen)
            axisScreen = l > 0.15 ? axisScreen / l : SIMD2<Float>(1, 0)
            return Double(simd_dot(dragAccum, axisScreen) * k)
        case .rotate:
            guard let axis = constrainedAxis(for: model) else {
                return Double(dragAccum.x * 0.008)
            }
            var axisScreen = SIMD2<Float>(simd_dot(axis, right), -simd_dot(axis, up))
            let l = simd_length(axisScreen)
            if l > 0.15 {
                axisScreen /= l
                let perp = SIMD2<Float>(-axisScreen.y, axisScreen.x)
                return Double(simd_dot(dragAccum, perp) * 0.008)
            }
            return Double(dragAccum.x * 0.008)
        case .scale:
            return Double(1 + dragAccum.y * -0.004)
        default:
            return 0
        }
    }

    /// Escalar EFECTIVO aplicado = bruto del arrastre + nudge numérico, cuantizado
    /// por snap. Es lo que ve el campo numérico Y lo que se hornea. Un solo estado.
    private func transformScalar(for model: Model) -> Double {
        let raw = transformRawScalar(for: model)
        switch selectedTool {
        case .scale:
            // El factor combina multiplicativamente con el nudge (1 = neutro).
            let f = raw * (1 + transformNudge)
            return snapTransformScalar(f)
        default:
            return snapTransformScalar(raw + transformNudge)
        }
    }

    /// Cuantiza el escalar activo a incrementos redondos si el snap está activo
    /// (tarea 2). Mover → paso de rejilla; rotar → `angleSnapDegrees`; escalar →
    /// factores de 0.25. Snap REAL: modifica el valor que se aplica, no un placebo.
    private func snapTransformScalar(_ value: Double) -> Double {
        guard toolVM.gridSnapEnabled else { return value }
        switch selectedTool {
        case .move:
            let step = max(0.01, projectSettings.config.gridStep)
            return (value / step).rounded() * step
        case .rotate:
            let deg = projectSettings.config.angleSnapDegrees > 0
                ? projectSettings.config.angleSnapDegrees : 15.0
            let stepRad = deg * .pi / 180
            return (value / stepRad).rounded() * stepRad
        case .scale:
            let step = 0.25
            return max(0.05, (value / step).rounded() * step)
        default:
            return value
        }
    }

    /// Dispara un tick háptico de selección al CRUZAR a un nuevo detente de snap
    /// durante el arrastre (tarea 2). Solo con el snap activo; no-op si el valor
    /// no cambió de incremento (evita zumbido continuo).
    private func fireSnapTickIfCrossed(_ snapped: Double) {
        guard toolVM.gridSnapEnabled else { lastSnapDetent = nil; return }
        if lastSnapDetent == nil || abs(snapped - (lastSnapDetent ?? snapped)) > 1e-9 {
            if lastSnapDetent != nil { HapticService.shared.selection() }
            lastSnapDetent = snapped
        }
    }

    /// Texto de la medida viva del transform (guía de la barra, tarea 4).
    private func transformReadoutText(for model: Model) -> String {
        let s = transformScalar(for: model)
        switch selectedTool {
        case .move:   return String(format: "%+.2f", s)
        case .rotate: return String(format: "%+.1f°", s * 180 / .pi)
        case .scale:  return String(format: "×%.2f", s)
        default:      return ""
        }
    }

    /// Prepara el estado de arrastre de transformación a partir del OBJETIVO
    /// resuelto (`TransformTargetResolver`), no del `bodyIndex` a secas. Fuente
    /// única para el drag directo (onTransformBegan) y para el drag del gizmo
    /// (onGizmoDragBegan):
    ///   · cara   → arma `dragFace` (push/pull real por la normal al soltar).
    ///   · cuerpo → arma `dragModelIndex` (transform de cuerpo entero).
    ///   · arista/vértice → SIN geometría fingida (`supportsRealGeometry==false`):
    ///     ancla el gizmo/numérico pero avisa honestamente y no mueve el sólido.
    /// `hitModelIndex` (si lo hay) restringe: solo se arma el drag de cara cuando
    /// el toque cae sobre el mismo cuerpo de la cara seleccionada.
    private func beginTransformDrag(hitModelIndex: Int?) {
        dragAccum = .zero
        dragFace = nil
        dragModelIndex = nil
        transformNudge = 0        // nuevo gesto: parte del número neutro
        lastSnapDetent = nil
        transformReadout = ""

        guard selectedTool == .move || selectedTool == .rotate || selectedTool == .scale,
              let target = activeTransformTarget else { return }

        // Ops de SUB-OBJETO con deformación local propia (tarea 6): escalar una CARA
        // (ensanchar su contorno) o mover una ARISTA/VÉRTICE. NO se escala/mueve el
        // cuerpo entero. No hay preview TRS fiel de una edición local (recomputar OCCT
        // por frame sería caro): se muestra la lectura viva y se hornea al soltar,
        // igual que el push/pull de cara. `subObjectDrag` evita tocar el cuerpo.
        let isFaceScale = (selectedTool == .scale && { if case .face = target { return true }; return false }())
        let isEdgeVertexMove = (selectedTool == .move && (target.isEdge || target.isVertex))
        if isFaceScale || isEdgeVertexMove {
            // Sub-objeto: NO se arma dragFace/dragModelIndex (no se toca el cuerpo);
            // la edición local (scaleFaceWire/moveEdge/moveVertex) se hornea al soltar
            // en bakeTransform → bakeSubObjectEdit, que ramifica por `target.isSubObject`.
            return
        }

        // ROTAR / ESCALAR el CUERPO padre SÍ es geometría real. Se transforma el
        // cuerpo entero (comportamiento honesto y útil, no fingido).
        if selectedTool == .rotate || selectedTool == .scale {
            dragModelIndex = target.modelIndex
            return
        }

        // MOVER: cara → push/pull real; cuerpo → transform; arista/vértice → honesto.
        switch target {
        case .body(let m):
            dragModelIndex = m

        case .face(let m, let f):
            guard hitModelIndex == nil || hitModelIndex == m,
                  m < canvasVM.scene.models.count,
                  let shape = canvasVM.scene.models[m].cadShape,
                  f < shape.faces().count,
                  let n = shape.faces()[f].normal else {
                selectionController.showHint("Esta cara no se puede empujar aquí")
                return
            }
            dragFace = (m, f, SIMD3<Float>(Float(n.x), Float(n.y), Float(n.z)))

        case .edge, .vertex:
            // supportsRealGeometry == false: estado honesto, cero geometría fingida.
            selectionController.showHint(
                "Mover aristas/puntos aún no deforma el sólido — selecciona «Cuerpo» o una cara")
        }
    }

    /// Preview vivo vía TRS del modelo (el renderer sincroniza model.transform
    /// por frame). Al soltar, bakeTransform lo hornea al B-rep y resetea el TRS.
    /// Pivote en el centro c: T(c)·Op·T(−c) ⇒ position compensada.
    private func applyTransformPreview() {
        // Drag de CARA: ghost del highlight viajando por la normal + distancia viva
        // en la barra (preview honesto sin recomputar OCCT por frame).
        if let df = dragFace, selectedTool == .move,
           df.modelIndex < canvasVM.scene.models.count {
            let model = canvasVM.scene.models[df.modelIndex]
            let d = simd_dot(transformParams(for: model).delta, df.normal)
            if let overlay = canvasVM.scene.models.first(where: { $0.name == Self.edgeHighlightName }) {
                overlay.position = df.normal * d
            }
            fireSnapTickIfCrossed(transformScalar(for: model))
            transformReadout = String(format: "%+.2f", d)
            selectionController.showHint(String(format: "Mover cara · %+.2f", d))
            canvasVM.objectWillChange.send()
            return
        }
        guard let idx = dragModelIndex, idx < canvasVM.scene.models.count else { return }
        let model = canvasVM.scene.models[idx]
        let p = transformParams(for: model)
        // Snap tick al cruzar detente + lectura viva de la guía (tareas 2 y 4).
        fireSnapTickIfCrossed(transformScalar(for: model))
        transformReadout = transformReadoutText(for: model)
        switch selectedTool {
        case .move:
            model.position = p.delta
        case .rotate:
            let q = simd_quatf(angle: p.angle, axis: p.axis)
            model.rotation = q
            model.position = p.center - q.act(p.center)
        case .scale:
            model.scale = SIMD3<Float>(repeating: p.factor)
            model.position = p.center * (1 - p.factor)
        default:
            return
        }
        // El gizmo VIAJA con el cuerpo durante el drag (feedback: 'los gizmos
        // no giran con el elemento') — mismo TRS a los overlays de flechas/anillos.
        // Los overlays de resaltado (cara/arista seleccionada) siguen el MISMO TRS
        // para que no queden puntos/aristas fantasma en la posición vieja (spec §4:
        // overlays atómicos con el cuerpo durante el drag).
        for name in Self.gizmoNames + [Self.faceHighlightName, Self.edgeHighlightName] {
            if let g = canvasVM.scene.models.first(where: { $0.name == name }) {
                g.position = model.position
                g.rotation = model.rotation
                g.scale = model.scale
            }
        }
        canvasVM.objectWillChange.send()
    }

    private func resetPreviewTRS(_ model: Model) {
        model.position = .zero
        model.rotation = simd_quatf(real: 1, imag: .zero)
        model.scale = SIMD3<Float>(1, 1, 1)
    }

    /// Hornea la transformación al B-rep (fuente de verdad: picking y booleanas
    /// siguen exactos) o, si el modelo no tiene B-rep, a los vértices de la malla.
    private func bakeTransform() {
        // Drag de CARA: hornear el push/pull real (BRepFeat prism) con la distancia
        // proyectada del gesto sobre la normal capturada al empezar.
        if let df = dragFace, selectedTool == .move {
            dragFace = nil
            canvasVM.scene.models.first(where: { $0.name == Self.edgeHighlightName })?.position = .zero
            // Limpia el estado de arrastre (eje + acumulador) para que el SIGUIENTE
            // gesto empiece desde identidad — sin arrastrar el offset del anterior.
            defer { dragAccum = .zero; gizmoAxis = nil; transformNudge = 0; lastSnapDetent = nil; transformReadout = "" }
            guard df.modelIndex < canvasVM.scene.models.count else { return }
            let model = canvasVM.scene.models[df.modelIndex]
            let d = Double(simd_dot(transformParams(for: model).delta, df.normal))
            guard abs(d) > 1e-4 else {
                selectionController.showHint("Sin desplazamiento")
                return
            }
            BRepHistory.shared.recordChange(of: model)
            let ok = BRepModeling.applyFeature(to: model) { shape in
                BRepModeling.pushPullFace(shape, faceIndex: df.faceIndex, distance: d)
            }
            if ok {
                HapticService.shared.medium()
                selectionController.deselect()
                temperTick += 1
            } else {
                BRepHistory.shared.discardLast()
                selectionController.showHint("La cara no se pudo mover (geometría no compatible)")
            }
            canvasVM.objectWillChange.send()
            return
        }

        // Sub-objeto con op de deformación propia (tarea 6): cara + ESCALAR →
        // `SubObjectEditEngine.scaleFaceWire`; arista/vértice + MOVER → moveEdge/
        // moveVertex. El engine devuelve `nil` cuando OCCT no llega → estado honesto,
        // cero geometría falsa. Intercepta ANTES del transform de cuerpo entero.
        if let target = activeTransformTarget, target.isSubObject,
           bakeSubObjectEdit(target: target) {
            return
        }

        guard let idx = dragModelIndex, idx < canvasVM.scene.models.count else { return }
        let model = canvasVM.scene.models[idx]
        let p = transformParams(for: model)
        let preview = model.transform
        resetPreviewTRS(model)
        dragModelIndex = nil

        if model.cadShape != nil {
            BRepHistory.shared.recordChange(of: model)
            let ok: Bool
            switch selectedTool {
            case .move:
                ok = BRepModeling.translate(model, by: SIMD3<Double>(Double(p.delta.x), Double(p.delta.y), Double(p.delta.z)))
            case .rotate:
                ok = BRepModeling.rotate(model,
                                         axis: SIMD3<Double>(Double(p.axis.x), Double(p.axis.y), Double(p.axis.z)),
                                         angle: Double(p.angle),
                                         center: SIMD3<Double>(Double(p.center.x), Double(p.center.y), Double(p.center.z)))
            case .scale:
                ok = BRepModeling.scaleUniform(model, factor: Double(p.factor),
                                               center: SIMD3<Double>(Double(p.center.x), Double(p.center.y), Double(p.center.z)))
            default:
                ok = false
            }
            if ok {
                HapticService.shared.medium()
                temperTick += 1  // el metal se templó
            } else {
                BRepHistory.shared.discardLast()
            }
        } else {
            // Malla sin B-rep (esculpida/importada): hornear a los vértices
            canvasVM.saveState()
            for mi in model.meshes.indices {
                for vi in model.meshes[mi].vertices.indices {
                    let pos = model.meshes[mi].vertices[vi].position
                    let world = preview * SIMD4<Float>(pos.x, pos.y, pos.z, 1)
                    model.meshes[mi].vertices[vi].position = SIMD3<Float>(world.x, world.y, world.z)
                }
                // Rotación/escala mueven las normales: recalcular desde triángulos
                let positions = model.meshes[mi].vertices.map { $0.position }
                let normals = OCCTBridge.computeVertexNormals(positions: positions,
                                                              indices: model.meshes[mi].indices)
                for vi in model.meshes[mi].vertices.indices where vi < normals.count {
                    model.meshes[mi].vertices[vi].normal = normals[vi]
                }
            }
            model.geometryVersion += 1
            HapticService.shared.medium()
        }
        dragAccum = .zero
        gizmoAxis = nil
        transformNudge = 0
        lastSnapDetent = nil
        transformReadout = ""
        // El cuerpo se horneó a una nueva posición: el resaltado construido ANTES
        // del bake yace en la geometría vieja → sería fantasma. Se retira (spec §4:
        // sin puntos/aristas fantasma). El usuario re-toca para re-resaltar sobre
        // la geometría nueva; no se re-arma silenciosamente sobre datos movidos.
        canvasVM.scene.models.removeAll {
            $0.name == Self.faceHighlightName || $0.name == Self.edgeHighlightName
        }
        rebuildGizmoOverlays()  // el centro del cuerpo cambió con el bake
        canvasVM.objectWillChange.send()
    }

    /// Hornea una edición de SUB-OBJETO vía el contrato `SubObjectEditEngine` (tarea 6):
    ///   · cara + ESCALAR  → `scaleFaceWire` (ensancha el contorno de la cara — REAL
    ///     para prismas; `nil` en el resto).
    ///   · arista + MOVER  → `moveEdge`  (hoy `nil` honesto en OCCTSwift v1.8.8).
    ///   · vértice + MOVER → `moveVertex` (hoy `nil` honesto).
    /// Devuelve `true` si CONSUMIÓ el gesto (aplicado o rechazado con aviso honesto);
    /// `false` si no aplica (deja que el bake de cuerpo tome el relevo).
    /// `nil` del engine = OCCT no llega → mensaje real, CERO geometría fingida.
    private func bakeSubObjectEdit(target: TransformTarget) -> Bool {
        let m = target.modelIndex
        guard m < canvasVM.scene.models.count else { return false }
        let model = canvasVM.scene.models[m]
        // El preview aplicó un TRS de cuerpo entero (beginTransformDrag arma
        // dragModelIndex); revertirlo antes de la edición local real.
        resetPreviewTRS(model)

        func cleanup() {
            dragModelIndex = nil
            dragAccum = .zero; gizmoAxis = nil
            transformNudge = 0; lastSnapDetent = nil; transformReadout = ""
            canvasVM.scene.models.removeAll {
                $0.name == Self.faceHighlightName || $0.name == Self.edgeHighlightName
            }
            rebuildGizmoOverlays()
            canvasVM.objectWillChange.send()
        }

        switch target {
        case .face(_, let faceIndex) where selectedTool == .scale:
            let factor = Double(transformParams(for: model).factor)
            guard abs(factor - 1.0) > 1e-3 else { cleanup(); return true }
            BRepHistory.shared.recordChange(of: model)
            let ok = BRepModeling.applyFeature(to: model) { shape in
                SubObjectEditEngine.scaleFaceWire(shape, faceIndex: faceIndex, factor: factor)
            }
            if ok {
                HapticService.shared.medium()
                temperTick += 1
                selectionController.deselect()
            } else {
                BRepHistory.shared.discardLast()
                selectionController.showHint(
                    "Escalar esta cara aún no es posible aquí (solo caras de prismas)")
            }
            cleanup()
            return true

        case .edge(_, let edgeIndex) where selectedTool == .move:
            let d = transformParams(for: model).delta
            let delta = SIMD3<Double>(Double(d.x), Double(d.y), Double(d.z))
            guard simd_length(delta) > 1e-4 else { cleanup(); return true }
            if let shape = model.cadShape,
               let newShape = SubObjectEditEngine.moveEdge(shape, edgeIndex: edgeIndex, delta: delta),
               let mesh = OCCTBridge.toMesh(newShape, quality: .medium) {
                BRepHistory.shared.recordChange(of: model)
                model.cadShape = newShape
                model.meshes = [mesh]
                model.geometryVersion += 1
                HapticService.shared.medium(); temperTick += 1
                selectionController.deselect()
            } else {
                // moveEdge devolvió nil: OCCT v1.8.8 no lo soporta — estado honesto.
                selectionController.showHint(
                    "Mover aristas aún no deforma el sólido — usa «Cuerpo» o empuja una cara")
            }
            cleanup()
            return true

        case .vertex(_, let vertexIndex) where selectedTool == .move:
            let d = transformParams(for: model).delta
            let delta = SIMD3<Double>(Double(d.x), Double(d.y), Double(d.z))
            guard simd_length(delta) > 1e-4 else { cleanup(); return true }
            if let shape = model.cadShape,
               let newShape = SubObjectEditEngine.moveVertex(shape, vertexIndex: vertexIndex, delta: delta),
               let mesh = OCCTBridge.toMesh(newShape, quality: .medium) {
                BRepHistory.shared.recordChange(of: model)
                model.cadShape = newShape
                model.meshes = [mesh]
                model.geometryVersion += 1
                HapticService.shared.medium(); temperTick += 1
                selectionController.deselect()
            } else {
                selectionController.showHint(
                    "Mover puntos aún no deforma el sólido — usa «Cuerpo» o empuja una cara")
            }
            cleanup()
            return true

        default:
            // Sub-objeto SIN op de sub-objeto (p.ej. cara + rotar): que el cuerpo
            // entero tome el relevo (rotar/escalar el cuerpo padre SÍ es real).
            return false
        }
    }

    // (performBoolean y sus 3 wrappers eliminados 2026-07-08: eran el segundo camino
    // de booleanos — actuaban sobre "los dos primeros modelos" sin selección, con
    // comportamiento distinto al toolbar. Dos caminos para la misma acción es un bug
    // de UX. El flujo canónico es startCSGOperation → performCSGWithSelectedShapes.)

    private func performGroupAssembly() {
        guard canvasVM.scene.models.count >= 2 else { return }
        let modelIDs = canvasVM.scene.models.map { $0.id }
        groupAssemblyEngine.createAssembly(name: "Group_\(UUID().uuidString.prefix(8))", modelIDs: modelIDs)
        sketchEngine.logOperation(type: .booleanUnion, description: "Assembly agrupado (\(modelIDs.count) modelos)")
    }

    // MARK: - Primitive Creation (F3.T2)

    private func performAddPrimitive(_ type: String) {
        let size = Double(primitiveSize)
        let occt = OCCTEngine.shared

        let shape: CADShape?
        let opDescription: String

        switch type {
        case "Box":
            shape = occt.box(width: size, height: size, depth: size)
            opDescription = "Box \(String(format: "%.1f", size))mm"
        case "Sphere":
            shape = occt.sphere(radius: size * 0.5)
            opDescription = "Sphere r=\(String(format: "%.1f", size * 0.5))mm"
        case "Cylinder":
            shape = occt.cylinder(radius: size * 0.5, height: size)
            opDescription = "Cylinder r=\(String(format: "%.1f", size * 0.5)) h=\(String(format: "%.1f", size))mm"
        case "Cone":
            shape = occt.cone(bottomRadius: size * 0.5, topRadius: 0, height: size)
            opDescription = "Cone r=\(String(format: "%.1f", size * 0.5)) h=\(String(format: "%.1f", size))mm"
        case "Torus":
            shape = occt.torus(majorRadius: size * 0.5, minorRadius: size * 0.15)
            opDescription = "Torus R=\(String(format: "%.1f", size * 0.5)) r=\(String(format: "%.1f", size * 0.15))mm"
        default:
            return
        }

        guard let rawShape = shape else {
            csgStatusMessage = "No se pudo crear la primitiva"
            return
        }
        // Colocar JUNTO a lo existente, no encima: antes toda primitiva nacía en
        // el origen, unas DENTRO de otras (feedback: "no puedo sumar elementos" —
        // sí se creaban, pero quedaban ocultas dentro del cubo inicial).
        let slot = Double(canvasVM.scene.models.count)
        let placedShape = rawShape.translated(by: SIMD3<Double>(slot * (size + 0.6), 0, 0)) ?? rawShape

        guard let mesh = OCCTBridge.toMesh(placedShape, quality: .medium) else {
            csgStatusMessage = "No se pudo crear la primitiva"
            return
        }

        let name = "\(type)_\(UUID().uuidString.prefix(8))"
        let model = Model(name: name)
        model.meshes = [mesh]
        model.cadShape = placedShape  // retener B-rep: fuente de verdad para ops de ingeniería
        model.edgesMesh = OCCTBridge.edgesMesh(placedShape)  // aristas visibles

        canvasVM.scene.addModel(model)
        canvasVM.scene.cadHistory.pushOperation(
            CADOperation(type: .createPrimitive, description: opDescription,
                         parameters: ["size": Double(primitiveSize)])
        )
        canvasVM.objectWillChange.send()
        sketchEngine.logOperation(type: .createPrimitive, description: opDescription)
    }

    private func startCSGOperation(_ tool: CADTool) {
        toolVM.csgActiveOperation = tool
        toolVM.csgShapeAIndex = nil
        toolVM.csgShapeBIndex = nil
        csgStatusMessage = "Selecciona la pieza A"
    }

    private func resetCSGSelection() {
        toolVM.csgActiveOperation = nil
        toolVM.csgShapeAIndex = nil
        toolVM.csgShapeBIndex = nil
        csgStatusMessage = ""
        selectedTool = .select
        toolVM.selectedTool = .select
    }

    private func cycleCSGShape(_ which: String) {
        let count = canvasVM.scene.models.count
        guard count > 0 else { return }
        if which == "A" {
            let current = toolVM.csgShapeAIndex ?? -1
            var next = (current + 1) % count
            if next == toolVM.csgShapeBIndex { next = (next + 1) % count }
            toolVM.csgShapeAIndex = next
            csgStatusMessage = toolVM.csgShapeBIndex != nil ? "Listo para aplicar" : "Selecciona la pieza B"
        } else {
            let current = toolVM.csgShapeBIndex ?? -1
            var next = (current + 1) % count
            if next == toolVM.csgShapeAIndex { next = (next + 1) % count }
            toolVM.csgShapeBIndex = next
            csgStatusMessage = toolVM.csgShapeAIndex != nil ? "Listo para aplicar" : "Selecciona la pieza A"
        }
    }

    @MainActor
    private func performCSGWithSelectedShapes() {
        guard let idxA = toolVM.csgShapeAIndex,
              let idxB = toolVM.csgShapeBIndex,
              idxA < canvasVM.scene.models.count,
              idxB < canvasVM.scene.models.count,
              idxA != idxB,
              let meshA = canvasVM.scene.models[idxA].meshes.first,
              let meshB = canvasVM.scene.models[idxB].meshes.first
        else { return }

        csgStatusMessage = "Aplicando…"
        let operation = selectedTool

        let opType: CADOperationType
        switch operation {
        case .booleanUnion: opType = .booleanUnion
        case .booleanSubtract: opType = .booleanSubtract
        case .booleanIntersect: opType = .booleanIntersect
        default: return
        }

        let model: Model
        if let brepResult = BRepModeling.boolean(opType, canvasVM.scene.models[idxA],
                                                 canvasVM.scene.models[idxB]) {
            model = brepResult  // booleano B-rep real (OCCT)
        } else {
            // Fallback malla
            let engine = BooleanEngine()
            let result: Mesh
            switch operation {
            case .booleanSubtract: result = engine.booleanDifference(a: meshA, b: meshB)
            case .booleanIntersect: result = engine.booleanIntersection(a: meshA, b: meshB)
            default: result = engine.booleanUnion(a: meshA, b: meshB)
            }
            model = Model(name: "\(operation.rawValue)_\(UUID().uuidString.prefix(8))")
            model.meshes = [result]
        }
        canvasVM.scene.addModel(model)
        canvasVM.objectWillChange.send()
        sketchEngine.logOperation(type: .booleanUnion, description: "CSG \(operation.rawValue) de 2 modelos")
        resetCSGSelection()
    }

    @ViewBuilder
    private var csgParameterBar: some View {
        let modelCount = canvasVM.scene.models.count
        let shapeADisplay: String = {
            if let idx = toolVM.csgShapeAIndex, idx < modelCount {
                return canvasVM.scene.models[idx].name
            }
            return "---"
        }()
        let shapeBDisplay: String = {
            if let idx = toolVM.csgShapeBIndex, idx < modelCount {
                return canvasVM.scene.models[idx].name
            }
            return "---"
        }()
        let bothSelected = toolVM.csgShapeAIndex != nil && toolVM.csgShapeBIndex != nil

        let csgLabel: String = {
            switch selectedTool {
            case .booleanUnion: return "Unión"
            case .booleanSubtract: return "Resta"
            case .booleanIntersect: return "Intersección"
            default: return "Booleana"
            }
        }()
        let bgColor: Color = theme.surfaceSecondary

        VStack(spacing: 2) {
            HStack {
                Text("Booleana · \(csgLabel)")
                    .font(.caption).bold().foregroundColor(theme.textPrimary)
                Spacer()
                Text(csgStatusMessage)
                    .font(.caption2)
                    .foregroundColor(bothSelected ? theme.success : theme.warning)
            }
            HStack {
                Text("A:").font(.caption2).foregroundColor(theme.textSecondary)
                Button(action: { cycleCSGShape("A") }) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left").font(.system(size: 6))
                        Text(shapeADisplay)
                            .font(.caption)
                            .lineLimit(1)
                            .frame(minWidth: 50)
                        Image(systemName: "chevron.right").font(.system(size: 6))
                    }
                }
                .disabled(modelCount < 2)

                Text("B:").font(.caption2).foregroundColor(theme.textSecondary)
                Button(action: { cycleCSGShape("B") }) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left").font(.system(size: 6))
                        Text(shapeBDisplay)
                            .font(.caption)
                            .lineLimit(1)
                            .frame(minWidth: 50)
                        Image(systemName: "chevron.right").font(.system(size: 6))
                    }
                }
                .disabled(modelCount < 2)

                Spacer()

                Button("Ejecutar") { performCSGWithSelectedShapes() }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!bothSelected)

                Button(action: { resetCSGSelection() }) {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 3)
        .background(bgColor)
        .onAppear {
            if csgStatusMessage.isEmpty {
                csgStatusMessage = "Selecciona la pieza A"
            }
        }
    }
}

// MARK: - Panel de Elementos (izquierdo, colapsable — anatomía Shapr3D)

/// Árbol de la escena: cuerpos exactos ⬡ y mallas libres 〰, con ojo de
/// visibilidad, selección al tocar y estética de tarjeta flotante calma.
struct ElementsPanel: View {
    @ObservedObject var canvasVM: CanvasViewModel
    @ObservedObject var selectionController: SelectionController
    @ObservedObject var sketch: SketchController
    let renderer: SatinRenderer
    @EnvironmentObject var themeManager: ThemeManager

    private var visibleModels: [(Int, Model)] {
        canvasVM.scene.models.enumerated()
            .filter { !$0.element.name.hasPrefix("__") }
            .map { ($0.offset, $0.element) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ELEMENTOS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(AppTheme.textTertiary)
                .padding(.horizontal, AppTheme.space3)
                .padding(.vertical, AppTheme.space2)

            ScrollView {
                VStack(spacing: 1) {
                    ForEach(visibleModels, id: \.1.id) { index, model in
                        elementRow(index: index, model: model)
                    }

                    // Boceto activo: cada entidad dibujada como fila seleccionable.
                    if !sketch.entities.isEmpty {
                        Text("BOCETO")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.1)
                            .foregroundColor(AppTheme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppTheme.space3)
                            .padding(.top, AppTheme.space2)
                        ForEach(Array(sketch.entities.enumerated()), id: \.offset) { i, entity in
                            sketchRow(index: i, entity: entity)
                        }
                    }

                    if visibleModels.isEmpty && sketch.entities.isEmpty {
                        Text("La escena está vacía")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textTertiary)
                            .padding(.vertical, AppTheme.space4)
                    }
                }
            }
        }
        .frame(width: 190)
        .frame(maxHeight: 320)
        .glassPanel()
    }

    private func sketchIcon(_ e: SketchController.Entity) -> String {
        switch e {
        case .circle: return "circle"
        case .rect: return "rectangle"
        case .spline: return "scribble.variable"
        case .polygonEnt: return "pentagon"
        case .polyline: return "line.diagonal"
        }
    }

    @ViewBuilder
    private func sketchRow(index: Int, entity: SketchController.Entity) -> some View {
        let isSelected = sketch.selectedEntityIndex == index
        HStack(spacing: AppTheme.space2) {
            Image(systemName: sketchIcon(entity))
                .font(.system(size: 11))
                .foregroundColor(isSelected ? AppTheme.accentColor : AppTheme.clay)
                .frame(width: 16)
            Text(entity.displayName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? AppTheme.accentColor : AppTheme.textPrimaryColor)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, AppTheme.space3)
        .padding(.vertical, 7)
        .background(isSelected ? AppTheme.accentColor.opacity(0.10) : Color.clear)
        .cornerRadius(AppTheme.radiusSM)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticService.shared.light()
            sketch.selectedEntityIndex = isSelected ? nil : index
        }
    }

    @ViewBuilder
    private func elementRow(index: Int, model: Model) -> some View {
        let isSelected = selectionController.bodyIndex == index
        HStack(spacing: AppTheme.space2) {
            // Badge de material: ⬡ exacto (B-rep) / 〰 libre (malla)
            Image(systemName: model.cadShape != nil ? "hexagon" : "scribble.variable")
                .font(.system(size: 11))
                .foregroundColor(model.cadShape != nil ? AppTheme.steel : AppTheme.clay)
                .frame(width: 16)
            Text(model.name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? AppTheme.accentColor
                                 : (model.isVisible ? AppTheme.textPrimaryColor
                                                    : AppTheme.textTertiary))
                .lineLimit(1)
            Spacer()
            Button {
                HapticService.shared.light()
                model.isVisible.toggle()
                model.geometryVersion = Model.nextFreshVersion()
                canvasVM.objectWillChange.send()
            } label: {
                Image(systemName: model.isVisible ? "eye" : "eye.slash")
                    .font(.system(size: 11))
                    .foregroundColor(model.isVisible ? AppTheme.textSecondaryColor
                                                     : AppTheme.textTertiary)
            }
        }
        .padding(.horizontal, AppTheme.space3)
        .padding(.vertical, 7)
        .background(isSelected ? AppTheme.accentColor.opacity(0.10) : Color.clear)
        .cornerRadius(AppTheme.radiusSM)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticService.shared.light()
            selectionController.deselect()
            selectionController.selectBodyFromPanel(index: index,
                                                    models: canvasVM.scene.models)
        }
    }
}

// MARK: - Sketch 2D en pantalla (nítido, como Shapr3D)

/// Dibuja el sketch como GRÁFICOS 2D proyectados: líneas finas de ancho
/// constante, círculos PERFECTOS, puntos en cada vértice, cotas en vivo y
/// relleno translúcido en perfiles cerrados. Observa el sketch y la cámara:
/// se redibuja en tiempo real (nada de esperar rebuilds del renderer).
struct SketchCanvasOverlay: View {
    @ObservedObject var sketch: SketchController
    @ObservedObject var canvasVM: CanvasViewModel

    private let steel = Color(red: 0.56, green: 0.74, blue: 0.90)
    private let ember = Color(red: 1.0, green: 0.48, blue: 0.27)

    var body: some View {
        // Capturado en body (MainActor): el closure de Canvas es no-aislado
        // y no puede llamar métodos de SketchController directamente.
        let plane = sketch.plane
        return Canvas { ctx, size in
            let cam = canvasVM.scene.camera
            let aspect = Float(size.width / max(size.height, 1))
            let vm = SatinRenderer.viewMatrix(for: cam)
            let pm = SatinRenderer.projectionMatrix(for: cam, aspect: aspect)

            // Proyecta un punto 2D del boceto usando el plano de trabajo activo
            // (origin + u·x + v·y) — sobre cara arbitraria, no solo y=0.
            func proj(_ p: SIMD2<Float>) -> CGPoint? {
                let w = plane.origin + plane.u * p.x + plane.v * p.y
                let clip = pm * (vm * SIMD4<Float>(w.x, w.y, w.z, 1))
                guard clip.w > 0.001 else { return nil }
                return CGPoint(x: CGFloat((clip.x / clip.w + 1) * 0.5) * size.width,
                               y: CGFloat((1 - clip.y / clip.w) * 0.5) * size.height)
            }

            func strokePolyline(_ pts: [SIMD2<Float>], close: Bool,
                                color: Color, width: CGFloat) {
                let screen = pts.compactMap(proj)
                guard screen.count >= 2 else { return }
                var path = Path()
                path.move(to: screen[0])
                for p in screen.dropFirst() { path.addLine(to: p) }
                if close { path.closeSubpath() }
                ctx.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: width, lineCap: .round,
                                              lineJoin: .round))
            }

            func fillPolyline(_ pts: [SIMD2<Float>], color: Color) {
                let screen = pts.compactMap(proj)
                guard screen.count >= 3 else { return }
                var path = Path()
                path.move(to: screen[0])
                for p in screen.dropFirst() { path.addLine(to: p) }
                path.closeSubpath()
                ctx.fill(path, with: .color(color))
            }

            // Muestreo Catmull-Rom: la spline se VE suave (16 muestras/segmento)
            func smooth(_ pts: [SIMD2<Float>]) -> [SIMD2<Float>] {
                guard pts.count >= 3 else { return pts }
                var out: [SIMD2<Float>] = []
                for i in 0..<(pts.count - 1) {
                    let p0 = pts[max(i - 1, 0)], p1 = pts[i]
                    let p2 = pts[i + 1], p3 = pts[min(i + 2, pts.count - 1)]
                    for k in 0..<16 {
                        let t = Float(k) / 16
                        let t2 = t * t, t3 = t2 * t
                        let a = p1 * 2
                        let b = (p2 - p0) * t
                        let c = (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2
                        let d = (p1 * 3 - p0 - p2 * 3 + p3) * t3
                        out.append((a + b + c + d) * 0.5)
                    }
                }
                out.append(pts[pts.count - 1])
                return out
            }

            func circlePts(_ c: SIMD2<Float>, _ r: Float) -> [SIMD2<Float>] {
                (0...72).map { k in
                    let t = Float(k) / 72 * 2 * .pi
                    return c + SIMD2(cos(t), sin(t)) * r
                }
            }

            func dot(_ p: SIMD2<Float>, color: Color, r: CGFloat = 4) {
                guard let s = proj(p) else { return }
                let rect = CGRect(x: s.x - r, y: s.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white))
                ctx.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 1.5)
            }

            func label(_ text: String, at p: SIMD2<Float>, color: Color = ember) {
                guard let s = proj(p) else { return }
                ctx.draw(Text(text).font(.system(size: 11, weight: .medium,
                                                 design: .monospaced))
                            .foregroundColor(color),
                         at: CGPoint(x: s.x, y: s.y - 14))
            }

            // ---- Retícula ligera del plano de trabajo (solo si no es el suelo) ----
            // 11×11 líneas locales, paso 0.5, extensión ±2.5 alrededor del origen.
            if plane != .floor {
                let ext: Float = 2.5, step: Float = 0.5
                var grid = Path()
                var k: Float = -ext
                while k <= ext + 1e-3 {
                    if let a = proj(SIMD2(k, -ext)), let b = proj(SIMD2(k, ext)) {
                        grid.move(to: a); grid.addLine(to: b)
                    }
                    if let a = proj(SIMD2(-ext, k)), let b = proj(SIMD2(ext, k)) {
                        grid.move(to: a); grid.addLine(to: b)
                    }
                    k += step
                }
                ctx.stroke(grid, with: .color(steel.opacity(0.15)), lineWidth: 1)
            }

            // ---- Entidades confirmadas (acero) con relleno de perfil + cotas permanentes ----
            // La entidad seleccionada se pinta en brasa (ember) — feedback de edición.
            for (entIndex, e) in sketch.entities.enumerated() {
                let stroke = entIndex == sketch.selectedEntityIndex ? ember : steel
                switch e {
                case .polyline(let pts, let closed):
                    if closed { fillPolyline(pts, color: ember.opacity(0.10)) }
                    strokePolyline(pts, close: closed, color: stroke, width: 2)
                    for p in pts { dot(p, color: stroke, r: 3) }
                    // Cotas: longitud de cada lado en su punto medio (≤6 lados)
                    if closed && pts.count >= 3 && pts.count <= 6 {
                        for i in 0..<pts.count {
                            let a = pts[i], b = pts[(i + 1) % pts.count]
                            let mid = (a + b) * 0.5
                            label(String(format: "%.2f", simd_distance(a, b)),
                                  at: mid, color: steel)
                        }
                    }
                case .rect(let a, let b):
                    let corners = [a, SIMD2(b.x, a.y), b, SIMD2(a.x, b.y)]
                    fillPolyline(corners, color: ember.opacity(0.10))
                    strokePolyline(corners, close: true, color: steel, width: 2)
                    for p in corners { dot(p, color: steel, r: 3) }
                    // Cota rect: "W×H" en el centro
                    let center2D = (a + b) * 0.5
                    label(String(format: "%.2f × %.2f", abs(b.x - a.x), abs(b.y - a.y)),
                          at: center2D, color: steel)
                case .circle(let c, let r):
                    fillPolyline(circlePts(c, r), color: ember.opacity(0.10))
                    strokePolyline(circlePts(c, r), close: true, color: steel, width: 2)
                    dot(c, color: steel, r: 3)
                    // Cota círculo: "R x.xx" junto al centro
                    label(String(format: "R %.2f", r), at: c, color: steel)
                case .spline(let pts):
                    strokePolyline(smooth(pts), close: false, color: steel, width: 2)
                    for p in pts { dot(p, color: steel, r: 3) }
                case .polygonEnt(let c, let r, let sides):
                    let verts = SketchController.Entity.polygonVerts(center: c, radius: r, sides: sides)
                    fillPolyline(verts, color: ember.opacity(0.10))
                    strokePolyline(verts, close: true, color: steel, width: 2)
                    for p in verts { dot(p, color: steel, r: 3) }
                    dot(c, color: steel, r: 2)
                    // Cota central: "R x.xx · N lados"
                    label(String(format: "R %.2f · %d lados", r, sides), at: c, color: steel)
                    // Cotas laterales: longitud de cada lado (≤6 lados)
                    if sides <= 6 {
                        for i in 0..<sides {
                            let pa = verts[i], pb = verts[(i + 1) % sides]
                            let mid = (pa + pb) * 0.5
                            label(String(format: "%.2f", simd_distance(pa, pb)),
                                  at: mid, color: steel)
                        }
                    }
                }
            }

            // Spline en curso (puntos de control + curva viva en brasa)
            if sketch.splineChain.count >= 2 {
                var livePts = sketch.splineChain
                if let pv = sketch.preview { livePts.append(pv) }
                strokePolyline(smooth(livePts), close: false, color: ember, width: 2.5)
            }
            for p in sketch.splineChain { dot(p, color: ember) }

            // ---- Cadena en curso + trazo vivo (brasa) con COTAS ----
            if sketch.chain.count >= 2 {
                strokePolyline(sketch.chain, close: false, color: ember, width: 2.5)
            }
            for p in sketch.chain { dot(p, color: ember) }
            if let a = sketch.anchor { dot(a, color: ember) }

            if let pv = sketch.preview {
                let from: SIMD2<Float>? = sketch.chain.last ?? sketch.anchor
                if let f = from, simd_distance(f, pv) > 1e-4 {
                    switch sketch.activeTool {
                    case .line:
                        strokePolyline([f, pv], close: false, color: ember, width: 2.5)
                        label(String(format: "%.2f", simd_distance(f, pv)),
                              at: (f + pv) * 0.5)
                    case .rectangle:
                        let corners = [f, SIMD2(pv.x, f.y), pv, SIMD2(f.x, pv.y)]
                        strokePolyline(corners, close: true, color: ember, width: 2.5)
                        label(String(format: "%.2f × %.2f",
                                     abs(pv.x - f.x), abs(pv.y - f.y)),
                              at: (f + pv) * 0.5)
                    case .circle:
                        let r = simd_distance(f, pv)
                        strokePolyline(circlePts(f, r), close: true,
                                       color: ember, width: 2.5)
                        strokePolyline([f, pv], close: false,
                                       color: ember.opacity(0.4), width: 1)
                        label(String(format: "R %.2f", r), at: pv)
                    case .polygon:
                        let r = simd_distance(f, pv)
                        let polyVerts = SketchController.Entity.polygonVerts(
                            center: f, radius: r, sides: sketch.polygonSides)
                        fillPolyline(polyVerts, color: ember.opacity(0.10))
                        strokePolyline(polyVerts, close: true, color: ember, width: 2.5)
                        label(String(format: "R %.2f · %d lados", r, sketch.polygonSides),
                              at: pv)
                    default:
                        break
                    }
                    dot(pv, color: ember)
                }
            }
        }
    }
}

struct PencilForceOverlay: UIViewRepresentable {
    var onPencilForce: ((CGFloat, CGPoint) -> Void)?

    func makeUIView(context: Context) -> PencilForceView {
        let view = PencilForceView()
        view.onPencilForce = onPencilForce
        view.isUserInteractionEnabled = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PencilForceView, context: Context) {
        uiView.onPencilForce = onPencilForce
    }
}

class PencilForceView: UIView {
    var onPencilForce: ((CGFloat, CGPoint) -> Void)?
    private let feedbackGen = UIImpactFeedbackGenerator(style: .light)

    override init(frame: CGRect) {
        super.init(frame: frame)
        feedbackGen.prepare()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        feedbackGen.prepare()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first, touch.type == .pencil else { return }
        let force = max(0, min(1, touch.force / touch.maximumPossibleForce))
        let location = touch.location(in: self)
        onPencilForce?(force, location)

        if force > 0.5 {
            feedbackGen.impactOccurred(intensity: CGFloat(force))
        }

        if let coalesced = event?.coalescedTouches(for: touch) {
            for ct in coalesced {
                let cforce = max(0, min(1, ct.force / ct.maximumPossibleForce))
                let cloc = ct.location(in: self)
                onPencilForce?(cforce, cloc)
            }
        }
    }
}

// MARK: - Share Sheet (UIActivityViewController wrapper)

/// Envuelve UIActivityViewController para presentarlo como sheet de SwiftUI.
/// Usado por la barra de exportación de planos para compartir el archivo generado.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - CAD Tool Execution

@MainActor
private func executeCADTool(_ tool: CADTool, canvasVM: CanvasViewModel, toolVM: ToolViewModel) {
    guard let firstModel = canvasVM.scene.models.first,
          let firstMesh = firstModel.meshes.first else { return }
    var mutableMesh = firstMesh

    // Ruta B-rep real (OCCT) cuando el modelo conserva su CADShape.
    if firstModel.cadShape != nil {
        let applied: Bool
        switch tool {
        case .fillet, .chamfer, .shell:
            BRepHistory.shared.recordChange(of: firstModel)
            switch tool {
            case .fillet:
                applied = BRepModeling.fillet(firstModel, radius: Double(toolVM.filletRadius))
            case .chamfer:
                applied = BRepModeling.chamfer(firstModel, distance: Double(toolVM.chamferRadius))
            default:
                applied = BRepModeling.shell(firstModel, thickness: Double(toolVM.shellThickness))
            }
            if !applied { BRepHistory.shared.discardLast() }
        default:
            applied = false
        }
        if applied {
            canvasVM.objectWillChange.send()
            return
        }
        // Si la feature B-rep no aplica o falla, continuar con la ruta de malla.
    }

    switch tool {
    case .fillet, .chamfer:
        // PLACEBO RETIRADO (barrido device 2026-07-11): operaba sobre indices[0]/[1]
        // de la malla — una arista arbitraria e invisible. Sin B-rep no hay
        // fillet/chamfer honesto; el flujo real es seleccionar aristas →
        // Redondear/Chaflán de la barra de selección.
        logger.warning("fillet/chamfer sin B-rep: sin efecto (placebo retirado)")
        return

    case .shell:
        let engine = ShellEngine()
        _ = engine.computeShell(faceIndex: 0, thickness: toolVM.shellThickness, mesh: &mutableMesh)

    case .loft:
        // TODO(F3): LoftEngine.loft(profiles:solid:quality:) expects [Wire], not [Vertex].
        // Vertex→Wire bridging not yet implemented. No-op until F3.
        logger.warning("TODO(F3): Loft operation skipped — Wire bridging needed")

    case .sweep:
        let engine = SweepEngine()
        let profile = mutableMesh.vertices
        let sweepHeight = toolVM.sweepHeight
        let path: [(position: SIMD3<Float>, tangent: SIMD3<Float>)] = [
            (SIMD3<Float>(0, 0, 0), SIMD3<Float>(0, 0, 1)),
            (SIMD3<Float>(0.05, 0, sweepHeight * 0.5), SIMD3<Float>(0, 0.2, 1)),
            (SIMD3<Float>(0, 0, sweepHeight), SIMD3<Float>(0, 0, 1))
        ]
        let sweptMesh = engine.computeSweep(profile: profile, path: path, segments: 12)
        if !sweptMesh.vertices.isEmpty {
            let model = Model(name: "Sweep_\(UUID().uuidString.prefix(8))")
            model.meshes = [sweptMesh]
            canvasVM.scene.addModel(model)
        }

    case .booleanUnion, .booleanSubtract, .booleanIntersect:
        toolVM.csgActiveOperation = tool
        toolVM.csgShapeAIndex = nil
        toolVM.csgShapeBIndex = nil

    default:
        break
    }

    if !canvasVM.scene.models.isEmpty {
        canvasVM.scene.models[0].meshes[0] = mutableMesh
    }
    canvasVM.objectWillChange.send()
}
