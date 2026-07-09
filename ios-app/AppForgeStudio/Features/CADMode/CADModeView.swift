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
    @StateObject private var assemblyEngine = AssemblyEngine()
    @StateObject private var pushPullController = PushPullController()
    @StateObject private var selectionController = SelectionController()
    @StateObject private var sketch = SketchController()
    @StateObject private var drawingExportController = DrawingExportController()
    @StateObject private var featureReportController = FeatureReportController()
    @ObservedObject private var brepHistory = BRepHistory.shared

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
    @State private var isExtruding: Bool = false
    @State private var showCADTimeline: Bool = false
    @State private var csgStatusMessage: String = ""
    @State private var showDrawingExportBar: Bool = false
    @State private var showFeatureReport: Bool = false
    @State private var showShareSheet: Bool = false
    /// Dispara el flash "templado" (IDENTIDAD_FORGE §6) al confirmar push/pull.
    @State private var temperTick: Int = 0
    /// Medición por toques sobre el modelo REAL (A → B → distancia exacta).
    @State private var measurePointA: SIMD3<Float>? = nil
    @State private var measurePointB: SIMD3<Float>? = nil
    /// Radio del fillet contextual de arista (barra de selección).
    @State private var edgeFilletRadius: Double = 0.1
    /// Espejo del estado de rayos X del renderer (para el tinte del botón).
    @State private var xrayOn = false
    /// Altura de extrusión del perfil de sketch (editable).
    @State private var sketchExtrudeHeight: Double = 1.0
    /// Panel de Elementos visible (anatomía Shapr3D).
    @State private var showElements = true
    /// Transformación directa en curso: índice del cuerpo arrastrado y acumulado
    /// del gesto en puntos de pantalla (se hornea al B-rep al soltar).
    @State private var dragModelIndex: Int? = nil
    @State private var dragAccum: SIMD2<Float> = .zero
    /// Eje restringido del gizmo durante el drag (nil = drag libre sobre el cuerpo).
    @State private var gizmoAxis: SIMD3<Float>? = nil

    private static let gizmoNames = ["__gizmoX", "__gizmoY", "__gizmoZ"]

    /// Centro del gizmo: cuerpo escalado + herramienta de transformación activa.
    private var activeGizmoCenter: SIMD3<Float>? {
        guard [.move, .rotate, .scale].contains(selectedTool),
              let idx = selectionController.bodyIndex,
              idx < canvasVM.scene.models.count else { return nil }
        return bboxCenter(of: canvasVM.scene.models[idx])
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
        // v1 del sketch en viewport: línea (cadena), círculo, rectángulo.
        // Arco/cota/restricción llegan con la ola 2 del sketch (no placebo).
        [.line, .circle, .rectangle]
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
                    toolbarSection
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
                    if showDrawingExportBar {
                        drawingExportBar
                    }
                    ZStack {
                        ContentView(canvasVM: canvasVM, renderer: renderer, onSurfaceHit: { hit in
                            if selectedTool == .pushPull {
                                pushPullController.selectFace(from: hit, in: canvasVM.scene.models)
                            } else if selectedTool == .measure {
                                // Medición sobre geometría real: primer toque = A,
                                // segundo = B, tercero reinicia.
                                HapticService.shared.light()
                                if measurePointA == nil || measurePointB != nil {
                                    measurePointA = hit.position
                                    measurePointB = nil
                                } else {
                                    measurePointB = hit.position
                                    if let a = measurePointA {
                                        toolVM.measurementDistance = simd_distance(a, hit.position)
                                    }
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
                            dragModelIndex = hit.modelIndex
                            dragAccum = .zero
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
                            dragModelIndex = selectionController.bodyIndex
                            dragAccum = .zero
                        },
                        // Sketch en viewport: taps = puntos; drag de PENCIL = trazo vivo
                        sketchInputEnabled: isSketchTool,
                        onSketchTap: { p in
                            HapticService.shared.light()
                            sketch.tap(at: p)
                        },
                        onSketchDragBegan: { p in
                            sketch.pencilDragBegan(at: p)
                        },
                        onSketchDragChanged: { p in
                            sketch.pencilDragChanged(to: p)
                        },
                        onSketchDragEnded: { p in
                            HapticService.shared.light()
                            sketch.pencilDragEnded(at: p)
                        })
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        // Sketch 2D NÍTIDO en pantalla (líneas finas, puntos,
                        // cotas vivas, relleno de perfiles) — estilo Shapr3D.
                        SketchCanvasOverlay(sketch: sketch, canvasVM: canvasVM)
                            .allowsHitTesting(false)

                        // Panel de Elementos flotante (anatomía Shapr3D)
                        if showElements {
                            VStack {
                                HStack {
                                    ElementsPanel(canvasVM: canvasVM,
                                                  selectionController: selectionController,
                                                  renderer: renderer)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .padding(.leading, AppTheme.space2)
                            .padding(.top, AppTheme.space2)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                    .animation(AppTheme.animDefault, value: showElements)
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
            if newTool != .measure { measurePointA = nil; measurePointB = nil }
            // Herramienta de dibujo → configurar el sketch en viewport
            switch newTool {
            case .line: sketch.activeTool = .line
            case .rectangle: sketch.activeTool = .rectangle
            case .circle: sketch.activeTool = .circle
            default: break
            }
            executeCADTool(newTool, canvasVM: canvasVM, toolVM: toolVM)
            rebuildGizmoOverlays()
        }
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

            if sketch.hasClosedProfile {
                NumericField(value: $sketchExtrudeHeight, range: 0.05...20)
                Button("Extruir") { performSketchExtrude() }
                    .font(.caption.bold())
                Button("Revolucionar") { performSketchRevolve() }
                    .font(.caption)
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

    private func performSketchExtrude() {
        HapticService.shared.medium()
        guard let model = sketch.extrudeProfile(height: sketchExtrudeHeight) else { return }
        canvasVM.saveState()
        canvasVM.scene.addModel(model)
        sketch.clear()
        canvasVM.scene.cadHistory.pushOperation(
            CADOperation(type: .createShape, description: "Extrusión desde boceto",
                         parameters: ["altura": sketchExtrudeHeight]))
        temperTick += 1
        canvasVM.objectWillChange.send()
    }

    private func performSketchRevolve() {
        HapticService.shared.medium()
        guard let model = sketch.revolveProfile() else {
            return
        }
        canvasVM.saveState()
        canvasVM.scene.addModel(model)
        sketch.clear()
        canvasVM.scene.cadHistory.pushOperation(
            CADOperation(type: .createShape, description: "Revolución desde boceto",
                         parameters: [:]))
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

                Button("Patrón ×3") {
                    HapticService.shared.medium()
                    guard modelIndex < canvasVM.scene.models.count else { return }
                    let model = canvasVM.scene.models[modelIndex]
                    let width = Double(bboxHalfDiagonal(of: model)) * 1.6 + 0.4
                    let copies = BRepModeling.linearPattern(of: model, count: 3,
                                                            spacing: SIMD3<Double>(width, 0, 0))
                    if !copies.isEmpty {
                        canvasVM.saveState()
                        copies.forEach { canvasVM.scene.addModel($0) }
                        temperTick += 1
                        canvasVM.objectWillChange.send()
                    }
                }
                .font(.caption)

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
                }
                if case .edge(let modelIndex, let edgeIndex)? = selectionController.lastItem {
                    Slider(value: $edgeFilletRadius, in: 0.01...0.5)
                        .frame(width: 110)
                    NumericField(value: $edgeFilletRadius, range: 0.01...0.5)
                    Button("Redondear") {
                        HapticService.shared.medium()
                        guard modelIndex < canvasVM.scene.models.count else { return }
                        let model = canvasVM.scene.models[modelIndex]
                        BRepHistory.shared.recordChange(of: model)
                        if BRepModeling.filletEdge(model, edgeIndex: edgeIndex,
                                                   radius: edgeFilletRadius) {
                            selectionController.deselect()
                            canvasVM.objectWillChange.send()
                            temperTick += 1
                        } else {
                            BRepHistory.shared.discardLast()
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

    private var toolbarSection: some View {
        VStack(spacing: 2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    Button(action: { HapticService.shared.light(); canvasVM.scene.cadHistory.undo() }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!canvasVM.scene.cadHistory.canUndo)
                    .accessibilityLabel("Deshacer")
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                    Button(action: { HapticService.shared.light(); canvasVM.scene.cadHistory.redo() }) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!canvasVM.scene.cadHistory.canRedo)
                    .accessibilityLabel("Rehacer")
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                    ForEach(transformTools, id: \.self) { tool in
                        toolButton(tool)
                    }
                    theme.border.frame(width: 1, height: 20).padding(.horizontal, 4)
                    ForEach(cadTools, id: \.self) { tool in
                        toolButton(tool)
                    }
                    theme.border.frame(width: 1, height: 20).padding(.horizontal, 4)
                    // --- Primitivas B-rep (nacen exactas; se escalan con la herramienta) ---
                    ForEach(primitiveTools.indices, id: \.self) { idx in
                        let prim = primitiveTools[idx]
                        Button(action: {
                            HapticService.shared.light()
                            performAddPrimitive(prim.id)
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: prim.icon)
                                    .font(.system(size: 15))
                                Text(prim.label)
                                    .font(.system(size: 8, weight: .medium))
                                    .lineLimit(1)
                            }
                            .frame(width: 56, height: 40)
                            .foregroundColor(theme.textSecondary)
                            .toolbarGlow(active: false)
                        }
                        .accessibilityLabel("Agregar \(prim.label)")
                        .dynamicTypeSize(...DynamicTypeSize.xLarge)
                    }
                    theme.border.frame(width: 1, height: 20).padding(.horizontal, 4)
                    ForEach(sketchTools, id: \.self) { tool in
                        toolButton(tool)
                    }
                }.padding(.horizontal, 6).padding(.vertical, 4)
            }
            animationRow
        }
        .background(theme.surface)
    }

    private func toolButton(_ tool: CADTool) -> some View {
        Button(action: {
            HapticService.shared.light()
            selectedTool = tool
            toolVM.selectedTool = tool
            if tool == .booleanUnion || tool == .booleanSubtract || tool == .booleanIntersect {
                startCSGOperation(tool)
            } else if tool != .select && tool != .move && tool != .rotate && tool != .scale && tool != .pushPull {
                // Select/transform/pushPull son MODOS (esperan un toque en geometría);
                // el resto ejecuta al instante.
                executeSelectedTool()
            }
        }) {
            VStack(spacing: 2) {
                Image(systemName: tool.icon)
                    .font(.system(size: 15, weight: selectedTool == tool ? .medium : .regular))
                Text(tool.displayName)
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(1)
            }
            .frame(width: 56, height: 40)
            .foregroundColor(selectedTool == tool ? theme.accent : theme.textSecondary)
            .toolbarGlow(active: selectedTool == tool)
        }
        .accessibilityLabel("Herramienta \(tool.displayName)")
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private func executeSelectedTool() {
        guard let firstMesh = canvasVM.scene.models.first?.meshes.first else { return }
        var mutableMesh = firstMesh
        toolVM.executeTool(mesh: &mutableMesh)
        if !canvasVM.scene.models.isEmpty {
            canvasVM.scene.models[0].meshes[0] = mutableMesh
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
                        .disabled(sketchEngine.entities.isEmpty)
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
                    Text("Radio:").font(.caption).foregroundColor(theme.textPrimary)
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

    private func performExtrusion() {
        guard !sketchEngine.entities.isEmpty else { return }
        isExtruding = true

        sketchEngine.closeProfile()
        sketchEngine.logOperation(type: .extrude, description: "Extrusion de sketch", parameters: ["distance": Double(extrudeDistance)])

        DispatchQueue.global(qos: .userInitiated).async {
            // TODO(F3): re-wire extrudeSketch — ExtrusionEngine renamed to CADShapeExtrusionEngine
            // which uses Wire/CADShape API; SketchEntity→Wire bridging needed.
            // For now, extrusion is a no-op that compiles.
            let mesh: Mesh? = nil

            DispatchQueue.main.async {
                isExtruding = false
                if let mesh = mesh {
                    extrudedMesh = mesh
                    selectedTool = .select
                }
            }
        }
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
    private func transformParams(for model: Model) -> (delta: SIMD3<Float>, angle: Float, axis: SIMD3<Float>, factor: Float, center: SIMD3<Float>) {
        let cam = canvasVM.scene.camera
        let forward = simd_normalize(cam.target - cam.position)
        let right = simd_normalize(simd_cross(forward, cam.up))
        let up = simd_cross(right, forward)
        let dist = simd_length(cam.position - cam.target)
        let k = dist * 0.0011

        let delta: SIMD3<Float>
        let rotAxis: SIMD3<Float>
        if let axis = gizmoAxis {
            // Restringido: el drag se proyecta sobre la dirección del eje EN PANTALLA
            // (arrastrar a lo largo de la flecha mueve; perpendicular no hace nada).
            var axisScreen = SIMD2<Float>(simd_dot(axis, right), -simd_dot(axis, up))
            let l = simd_length(axisScreen)
            axisScreen = l > 0.15 ? axisScreen / l : SIMD2<Float>(1, 0)
            let amount = simd_dot(dragAccum, axisScreen) * k
            delta = axis * amount
            rotAxis = axis
        } else {
            delta = right * dragAccum.x * k - up * dragAccum.y * k
            rotAxis = SIMD3<Float>(0, 1, 0)
        }
        // Rotación: el drag PERPENDICULAR a la proyección del eje gira alrededor
        // de él (tangente del anillo). Sin gizmo: horizontal = eje Y (natural).
        let angle: Float
        if let axis = gizmoAxis {
            var axisScreen = SIMD2<Float>(simd_dot(axis, right), -simd_dot(axis, up))
            let l = simd_length(axisScreen)
            if l > 0.15 {
                axisScreen /= l
                let perp = SIMD2<Float>(-axisScreen.y, axisScreen.x)
                angle = simd_dot(dragAccum, perp) * 0.008
            } else {
                // Eje mirando a cámara: el anillo es un círculo en pantalla —
                // drag horizontal gira (convención estándar).
                angle = dragAccum.x * 0.008
            }
        } else {
            angle = dragAccum.x * 0.008
        }
        let factor = max(0.05, min(20, 1 + dragAccum.y * -0.004))
        return (delta, angle, rotAxis, factor, bboxCenter(of: model))
    }

    /// Preview vivo vía TRS del modelo (el renderer sincroniza model.transform
    /// por frame). Al soltar, bakeTransform lo hornea al B-rep y resetea el TRS.
    /// Pivote en el centro c: T(c)·Op·T(−c) ⇒ position compensada.
    private func applyTransformPreview() {
        guard let idx = dragModelIndex, idx < canvasVM.scene.models.count else { return }
        let model = canvasVM.scene.models[idx]
        let p = transformParams(for: model)
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
        for name in Self.gizmoNames {
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
        rebuildGizmoOverlays()  // el centro del cuerpo cambió con el bake
        canvasVM.objectWillChange.send()
    }

    // (performBoolean y sus 3 wrappers eliminados 2026-07-08: eran el segundo camino
    // de booleanos — actuaban sobre "los dos primeros modelos" sin selección, con
    // comportamiento distinto al toolbar. Dos caminos para la misma acción es un bug
    // de UX. El flujo canónico es startCSGOperation → performCSGWithSelectedShapes.)

    private func performGroupAssembly() {
        guard canvasVM.scene.models.count >= 2 else { return }
        let modelIDs = canvasVM.scene.models.map { $0.id }
        assemblyEngine.createAssembly(name: "Group_\(UUID().uuidString.prefix(8))", modelIDs: modelIDs)
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
            CADOperation(type: .createShape, description: opDescription,
                         parameters: ["size": Double(primitiveSize)])
        )
        canvasVM.objectWillChange.send()
        sketchEngine.logOperation(type: .createShape, description: opDescription)
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
                    if visibleModels.isEmpty {
                        Text("La escena está vacía")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textTertiary)
                            .padding(.vertical, AppTheme.space4)
                    }
                }
            }
        }
        .frame(width: 190)
        .frame(maxHeight: 380)
        .glassPanel()
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
        Canvas { ctx, size in
            let cam = canvasVM.scene.camera
            let aspect = Float(size.width / max(size.height, 1))
            let vm = SatinRenderer.viewMatrix(for: cam)
            let pm = SatinRenderer.projectionMatrix(for: cam, aspect: aspect)

            func proj(_ p: SIMD2<Float>) -> CGPoint? {
                let clip = pm * (vm * SIMD4<Float>(p.x, 0, p.y, 1))
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

            func label(_ text: String, at p: SIMD2<Float>) {
                guard let s = proj(p) else { return }
                ctx.draw(Text(text).font(.system(size: 11, weight: .medium,
                                                 design: .monospaced))
                            .foregroundColor(ember),
                         at: CGPoint(x: s.x, y: s.y - 14))
            }

            // ---- Entidades confirmadas (acero) con relleno de perfil ----
            for e in sketch.entities {
                switch e {
                case .polyline(let pts, let closed):
                    if closed { fillPolyline(pts, color: ember.opacity(0.10)) }
                    strokePolyline(pts, close: closed, color: steel, width: 2)
                    for p in pts { dot(p, color: steel, r: 3) }
                case .rect(let a, let b):
                    let corners = [a, SIMD2(b.x, a.y), b, SIMD2(a.x, b.y)]
                    fillPolyline(corners, color: ember.opacity(0.10))
                    strokePolyline(corners, close: true, color: steel, width: 2)
                    for p in corners { dot(p, color: steel, r: 3) }
                case .circle(let c, let r):
                    fillPolyline(circlePts(c, r), color: ember.opacity(0.10))
                    strokePolyline(circlePts(c, r), close: true, color: steel, width: 2)
                    dot(c, color: steel, r: 3)
                }
            }

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
    case .fillet:
        // Mesh-based fillet ≈ bevel with segments (FilletEngine works on B-rep CADShape, not Mesh)
        let engine = BevelEngine()
        if mutableMesh.indices.count >= 6 {
            let e0 = Int(mutableMesh.indices[0])
            let e1 = Int(mutableMesh.indices[1])
            let radius = toolVM.filletRadius
            _ = engine.bevel(mesh: &mutableMesh, edgeIndices: [(e0, e1)], bevelSize: radius, segments: 4)
        }

    case .chamfer:
        let engine = ChamferEngine()
        if mutableMesh.indices.count >= 6 {
            let e0 = Int(mutableMesh.indices[0])
            let e1 = Int(mutableMesh.indices[1])
            let dist = toolVM.chamferRadius
            _ = engine.computeChamfer(edges: [(e0, e1)], distance: dist, mesh: &mutableMesh)
        }

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
