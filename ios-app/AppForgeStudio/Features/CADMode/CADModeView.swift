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
    @StateObject private var edgeFilletController = EdgeFilletController()
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

    private var isSketchTool: Bool {
        selectedTool.isSketchTool
    }

    private var transformTools: [CADTool] {
        [.select, .move, .rotate, .scale]
    }

    private var cadTools: [CADTool] {
        // .loft excluido: LoftEngine espera [Wire] y el puente Vertex→Wire no existe
        // aún (F3) — no se muestran herramientas sin efecto real.
        // .pushPull PRIMERO: es el flujo estrella (tap cara → boss/pocket) y estuvo
        // INALCANZABLE hasta 2026-07-08 (no aparecía en ninguna lista del toolbar).
        [.pushPull, .extrude, .loopCut, .bevel, .booleanUnion, .booleanSubtract, .booleanIntersect, .fillet, .chamfer, .shell, .sweep, .measure]
    }

    private var sketchTools: [CADTool] {
        [.line, .circle, .rectangle, .arc, .dimension, .constraint]
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
            if isSketchTool {
                CADSketchView(sketchEngine: sketchEngine, meshResult: $extrudedMesh)
                    .onAppear {
                        sketchEngine.resolveConstraints(scene: canvasVM.scene)
                    }
                    .onChange(of: extrudedMesh) { newMesh in
                        if let mesh = newMesh {
                            let name = "Extruded_\(UUID().uuidString.prefix(8))"
                            let model = Model(name: name)
                            model.meshes = [mesh]
                            canvasVM.scene.addModel(model)
                            canvasVM.objectWillChange.send()
                            selectedTool = .select
                            // Reconnect constraint system after scene modification
                            sketchEngine.resolveConstraints(scene: canvasVM.scene)
                        }
                    }
            } else {
                tabSelector
                if selectedTab == .model {
                    toolbarSection
                    parameterBar
                    brepHistoryBar
                    if selectedTool == .pushPull {
                        pushPullBar
                    }
                    if edgeFilletController.hasSelection {
                        edgeFilletBar
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
                                // Menú adaptativo (BLUEPRINT S2): tocar cerca de una
                                // arista la selecciona y ofrece redondear; lejos, limpia.
                                if edgeFilletController.selectEdge(from: hit, in: canvasVM.scene.models) {
                                    HapticService.shared.light()
                                }
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
                        })
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        SnapGuideOverlay(
                            snapPoints: snapPoints,
                            cursorScreenPosition: cursorScreenPosition,
                            isActive: showSnapOverlay && toolVM.gridSnapEnabled
                        )
                        PencilForceOverlay { force, location in
                            if force > 0.7 && !sketchEngine.entities.isEmpty && !isExtruding {
                                extrudeDistance = Float(force) * 2.0
                                performExtrusion()
                            }
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                cursorScreenPosition = value.location
                                let worldPos = SIMD3<Float>(
                                    Float(value.location.x / 300 - 0.5) * 4,
                                    Float(1 - value.location.y / 400 - 0.5) * 3,
                                    0
                                )
                                let direction = SIMD3<Float>(0, 0, -1)
                                constraintEngine.scene = canvasVM.scene
                                let found = constraintEngine.findSnapPoints(
                                    position: worldPos,
                                    direction: direction
                                )
                                snapPoints = found
                                showSnapOverlay = !found.isEmpty
                            }
                            .onEnded { _ in
                                constraintEngine.clearSnapState()
                                snapPoints = []
                                showSnapOverlay = false
                            }
                    )
                    // (El doble tap = encuadrar vive en MetalView — gesto universal.)
                    bottomBar
                } else {
                    parametricView
                }
            }
        }
        .onChange(of: selectedTool) { newTool in
            if newTool != .pushPull { pushPullController.clear() }
            if newTool != .select { edgeFilletController.clear() }
            if newTool != .measure { measurePointA = nil; measurePointB = nil }
            executeCADTool(newTool, canvasVM: canvasVM, toolVM: toolVM)
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
        .onChange(of: edgeFilletController.highlightMesh) { newMesh in
            // Overlay del tubo de arista seleccionada (brasa, no tocable por "__")
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
            Text(String(format: "%+.2f", pushPullController.distance))
                .font(.caption2.monospacedDigit())
                .frame(width: 44)
                .foregroundColor(pushPullController.distance >= 0 ? theme.accent : .orange)
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

    /// Barra contextual de arista (menú adaptativo, BLUEPRINT S2): aparece al tocar
    /// una arista con Select; radio en vivo + Redondear (fillet B-rep selectivo).
    private var edgeFilletBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "angle")
                .foregroundColor(theme.accent)
            Text(edgeFilletController.statusMessage)
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
            Spacer()
            Slider(value: $edgeFilletController.radius, in: 0.01...0.5)
                .frame(width: 130)
            Text(String(format: "%.2f", edgeFilletController.radius))
                .font(.caption2.monospacedDigit())
                .frame(width: 40)
                .foregroundColor(theme.accent)
            Button("Redondear") {
                HapticService.shared.medium()
                if edgeFilletController.applyFillet() {
                    canvasVM.objectWillChange.send()
                    temperTick += 1
                }
            }
            .font(.caption.bold())
            Button(action: { edgeFilletController.clear() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(theme.textSecondary)
            }
            .accessibilityLabel("Cancelar selección de arista")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary)
        .tempered(trigger: temperTick)
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
            // Etiqueta explícita: era un icono-misterio (feedback de device)
            Button(action: { HapticService.shared.light(); showSnapOverlay.toggle() }) {
                HStack(spacing: 3) {
                    Image(systemName: showSnapOverlay ? "scope" : "dot.scope")
                        .font(.system(size: 11))
                    Text("Guías").font(.caption2)
                }
                .foregroundColor(showSnapOverlay ? theme.accent : theme.textSecondary)
            }
            .accessibilityLabel("Mostrar guías de snap")
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
