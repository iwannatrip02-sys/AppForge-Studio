import SwiftUI
import OSLog
import CoreGraphics

private let logger = Logger(subsystem: "com.appforgestudio", category: "CADModeView")

enum CADModeTab: String, CaseIterable {
    case model = "Model"
    case parametric = "Parametric"
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
    @EnvironmentObject var themeManager: ThemeManager

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

    private var isSketchTool: Bool {
        selectedTool.isSketchTool
    }

    private var transformTools: [CADTool] {
        [.select, .move, .rotate, .scale]
    }

    private var cadTools: [CADTool] {
        [.extrude, .loopCut, .bevel, .booleanUnion, .booleanSubtract, .booleanIntersect, .fillet, .chamfer, .shell, .loft, .sweep, .measure]
    }

    private var sketchTools: [CADTool] {
        [.line, .circle, .rectangle, .arc, .dimension, .constraint]
    }

    private var primitiveTools: [(label: String, icon: String)] {
        [("Box", "cube"), ("Sphere", "globe"), ("Cylinder", "cylinder"), ("Cone", "cone"), ("Torus", "torus")]
    }

    @State private var primitiveSize: Float = 1.0

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
                    if selectedTool == .pushPull {
                        pushPullBar
                    }
                    ZStack {
                        ContentView(canvasVM: canvasVM, renderer: renderer, onSurfaceHit: { hit in
                            if selectedTool == .pushPull {
                                pushPullController.selectFace(from: hit, in: canvasVM.scene.models)
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
                    .onTapGesture(count: 2) {
                        HapticService.shared.medium()
                        canvasVM.resetView()
                        canvasVM.objectWillChange.send()
                    }
                    bottomBar
                } else {
                    parametricView
                }
            }
        }
        .onChange(of: selectedTool) { newTool in
            executeCADTool(newTool, canvasVM: canvasVM, toolVM: toolVM)
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
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(CADModeTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 10))
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(selectedTab == tab ? theme.accent : theme.surfaceSecondary)
                        .foregroundColor(theme.textPrimary)
                }
            }
            Spacer()
        }
        .background(theme.surface)
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
                }
            }
            .font(.caption.bold())
            .disabled(!pushPullController.hasSelection)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary)
    }

    private var parametricView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Operation Timeline")
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
                    // --- Primitive creation buttons (F3.T2) ---
                    ForEach(primitiveTools.indices, id: \.self) { idx in
                        let prim = primitiveTools[idx]
                        Button(action: {
                            HapticService.shared.light()
                            performAddPrimitive(prim.label)
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: prim.icon)
                                    .font(.system(size: 8))
                                Text(prim.label)
                                    .font(.system(size: 9))
                            }
                            .padding(.horizontal, 5).padding(.vertical, 3)
                            .background(theme.surfaceSecondary)
                            .foregroundColor(theme.textPrimary).cornerRadius(theme.cornerRadiusSmall)
                        }
                        .accessibilityLabel("Agregar \(prim.label)")
                        .dynamicTypeSize(...DynamicTypeSize.xLarge)
                    }
                    // --- Size slider for primitives ---
                    Slider(value: $primitiveSize, in: 0.2...3.0)
                        .frame(width: 80)
                    Text(String(format: "%.1f", primitiveSize))
                        .font(.system(size: 8))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 22)
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
            } else if tool != .select && tool != .move && tool != .rotate && tool != .scale {
                executeSelectedTool()
            }
        }) {
            Text(tool.rawValue)
                .font(.system(size: 9))
                .padding(.horizontal, 5).padding(.vertical, 3)
                .background(selectedTool == tool ? theme.accent : theme.surfaceSecondary)
                .foregroundColor(theme.textPrimary).cornerRadius(theme.cornerRadiusSmall)
        }
        .accessibilityLabel("Herramienta \(tool.rawValue)")
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
                MeasureTool(toolVM: toolVM, canvasVM: canvasVM)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(theme.surfaceSecondary)
            default:
                EmptyView()
            }
        }
    }

    private var animationRow: some View {
        HStack {
            Button(action: {
                let clip = AnimationClip(name: "CAD_" + UUID().uuidString.prefix(8), duration: 2.0)
                animationVM.registerClip(clip)
                animationVM.selectedClipName = clip.name
            }) {
                Image(systemName: "play.rectangle")
                    .foregroundColor(canvasVM.scene.models.isEmpty ? theme.textSecondary : theme.accent)
            }
            .disabled(canvasVM.scene.models.isEmpty)
            Text(animationVM.isPlaying ? "Playing" : "Anim").font(.system(size: 9))

            theme.border.frame(width: 1, height: 16).padding(.horizontal, 3)

            Button(action: { performBooleanUnion() }) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 11))
                    .foregroundColor(canvasVM.scene.models.count >= 2 ? .cyan : theme.textSecondary)
            }
            .disabled(canvasVM.scene.models.count < 2)
            .help("Boolean Union")

            Button(action: { performBooleanSubtract() }) {
                Image(systemName: "square.slash")
                    .font(.system(size: 11))
                    .foregroundColor(canvasVM.scene.models.count >= 2 ? .orange : theme.textSecondary)
            }
            .disabled(canvasVM.scene.models.count < 2)
            .help("Boolean Subtract")

            Button(action: { performBooleanIntersect() }) {
                Image(systemName: "square.on.circle")
                    .font(.system(size: 11))
                    .foregroundColor(canvasVM.scene.models.count >= 2 ? .purple : theme.textSecondary)
            }
            .disabled(canvasVM.scene.models.count < 2)
            .help("Boolean Intersect")

            Button(action: { performGroupAssembly() }) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 11))
                    .foregroundColor(canvasVM.scene.models.count >= 2 ? .green : theme.textSecondary)
            }
            .disabled(canvasVM.scene.models.count < 2)
            .help("Agrupar Assembly")

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
        }.padding(.horizontal, 6).padding(.vertical, 2)
    }

    private var bottomBar: some View {
        HStack {
            Toggle("Snap", isOn: $toolVM.gridSnapEnabled).toggleStyle(.switch).font(.caption)
            Button(action: { showSnapOverlay.toggle() }) {
                Image(systemName: showSnapOverlay ? "scope" : "dot.scope")
                    .font(.system(size: 11))
                    .foregroundColor(showSnapOverlay ? theme.accent : theme.textSecondary)
            }
            .help("Toggle snap guides")
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

    @MainActor
    private func performBooleanUnion() {
        performBoolean(.booleanUnion, description: "Union de 2 modelos", namePrefix: "Union")
    }

    @MainActor
    private func performBooleanSubtract() {
        performBoolean(.booleanSubtract, description: "Diferencia de 2 modelos", namePrefix: "Subtract")
    }

    @MainActor
    private func performBooleanIntersect() {
        performBoolean(.booleanIntersect, description: "Interseccion de 2 modelos", namePrefix: "Intersect")
    }

    /// Booleano entre los dos primeros modelos: B-rep real (OCCT) si ambos lo tienen,
    /// fallback al motor de mallas si no.
    @MainActor
    private func performBoolean(_ op: CADOperationType, description: String, namePrefix: String) {
        guard canvasVM.scene.models.count >= 2 else { return }
        let modelA = canvasVM.scene.models[0]
        let modelB = canvasVM.scene.models[1]

        sketchEngine.logOperation(type: op, description: description)

        if let brepResult = BRepModeling.boolean(op, modelA, modelB) {
            canvasVM.scene.addModel(brepResult)
            canvasVM.objectWillChange.send()
            return
        }

        // Fallback malla (modelos importados/esculpidos sin B-rep)
        let meshA = modelA.meshes.first ?? Mesh()
        let meshB = modelB.meshes.first ?? Mesh()
        guard !meshA.vertices.isEmpty, !meshB.vertices.isEmpty else { return }
        let engine = BooleanEngine()
        let result: Mesh
        switch op {
        case .booleanSubtract: result = engine.booleanDifference(a: meshA, b: meshB)
        case .booleanIntersect: result = engine.booleanIntersection(a: meshA, b: meshB)
        default: result = engine.booleanUnion(a: meshA, b: meshB)
        }
        let model = Model(name: "\(namePrefix)_\(UUID().uuidString.prefix(8))")
        model.meshes = [result]
        canvasVM.scene.addModel(model)
        canvasVM.objectWillChange.send()
    }

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

        guard let validShape = shape,
              let mesh = OCCTBridge.toMesh(validShape, quality: .medium) else {
            csgStatusMessage = "Failed to create \(type)"
            return
        }

        let name = "\(type)_\(UUID().uuidString.prefix(8))"
        let model = Model(name: name)
        model.meshes = [mesh]
        model.cadShape = validShape  // retener B-rep: fuente de verdad para ops de ingeniería

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
        csgStatusMessage = "Select Shape A"
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
            csgStatusMessage = toolVM.csgShapeBIndex != nil ? "Ready to execute" : "Select Shape B"
        } else {
            let current = toolVM.csgShapeBIndex ?? -1
            var next = (current + 1) % count
            if next == toolVM.csgShapeAIndex { next = (next + 1) % count }
            toolVM.csgShapeBIndex = next
            csgStatusMessage = toolVM.csgShapeAIndex != nil ? "Ready to execute" : "Select Shape A"
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

        csgStatusMessage = "Applying..."
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
            case .booleanUnion: return "Union"
            case .booleanSubtract: return "Subtract"
            case .booleanIntersect: return "Intersect"
            default: return "CSG"
            }
        }()
        let bgColor: Color = theme.surfaceSecondary

        VStack(spacing: 2) {
            HStack {
                Text("CSG \(csgLabel)")
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
                csgStatusMessage = "Select Shape A"
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
        case .fillet:
            applied = BRepModeling.fillet(firstModel, radius: Double(toolVM.filletRadius))
        case .chamfer:
            applied = BRepModeling.chamfer(firstModel, distance: Double(toolVM.chamferRadius))
        case .shell:
            applied = BRepModeling.shell(firstModel, thickness: Double(toolVM.shellThickness))
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
