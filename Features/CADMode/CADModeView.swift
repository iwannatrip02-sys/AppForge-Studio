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
                            let model = Model(name: name, meshes: [mesh])
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
                    ZStack {
                        ContentView(canvasVM: canvasVM, renderer: renderer)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        SnapGuideOverlay(
                            snapPoints: snapPoints,
                            cursorScreenPosition: cursorScreenPosition,
                            isActive: showSnapOverlay && toolVM.gridSnapEnabled
                        )
                        PencilForceOverlay { force, location in
                            if force > 0.7 && !sketchEngine.entities.isEmpty && !isExtruding {
                                extrudeDistance = force * 2.0
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
            .onChange(of: selectedTool) { newTool in
                executeCADTool(newTool, canvasVM: canvasVM, toolVM: toolVM)
            }
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
                        .background(selectedTab == tab ? Color.blue : theme.surfaceSecondary)
                        .foregroundColor(theme.textPrimary)
                }
            }
            Spacer()
        }
        .background(theme.surface)
    }

    private var parametricView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Operation Timeline")
                    .font(.caption)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text("\(canvasVM.scene.cadHistory.getAllOperations().count) ops")
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(theme.surfaceSecondary)

            List {
                ForEach(canvasVM.scene.cadHistory.getAllOperations(), id: \.id) { node in
                    HStack {
                        Circle()
                            .fill(node.id == canvasVM.scene.cadHistory.current.id ? Color.blue : Color.gray)
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.operation)
                                .font(.system(size: 11))
                                .foregroundColor(node.id == canvasVM.scene.cadHistory.current.id ? theme.textPrimary : theme.textSecondary)
                            if !node.params.isEmpty {
                                Text(node.params.map { "\($0.key): \(String(format: "%.2f", $0.value))" }.joined(separator: ", "))
                                    .font(.system(size: 8))
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        Spacer()
                        Text(node.timestamp, style: .time)
                            .font(.system(size: 8))
                            .foregroundColor(theme.textSecondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        canvasVM.scene.cadHistory.reset(to: node)
                        canvasVM.objectWillChange.send()
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
            if tool != .select && tool != .move && tool != .rotate && tool != .scale {
                executeSelectedTool()
            }
        }) {
            Text(tool.rawValue)
                .font(.system(size: 9))
                .padding(.horizontal, 5).padding(.vertical, 3)
                .background(selectedTool == tool ? Color.blue : theme.surfaceSecondary)
                .foregroundColor(theme.textPrimary).cornerRadius(5)
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
                .background(Color.blue.opacity(0.15))
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
                .background(Color.blue.opacity(0.15))
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
                .background(Color.orange.opacity(0.15))
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
                .background(Color.green.opacity(0.15))
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
                .background(Color.purple.opacity(0.15))
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
                .background(Color.yellow.opacity(0.12))
            case .booleanUnion:
                HStack {
                    Text("Union con copia desplazada +0.15 en X")
                        .font(.caption).foregroundColor(theme.textPrimary)
                    Spacer()
                    Button("Ejecutar") { executeSelectedTool() }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Color.cyan.opacity(0.12))
            case .measure:
                MeasureTool(toolVM: toolVM, canvasVM: canvasVM)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Color.mint.opacity(0.12))
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
                    .foregroundColor(canvasVM.scene.models.isEmpty ? theme.textSecondary : .blue)
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
                    .foregroundColor(.blue)
            }
            .help("Timeline CAD")

            Button(action: { exportToSTEP() }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
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
                    .foregroundColor(showSnapOverlay ? .blue : theme.textSecondary)
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
            let mesh = ExtrusionEngine.extrudeSketch(sketchEngine.entities, points: sketchEngine.points, distance: extrudeDistance)

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

    private func performBooleanUnion() {
        guard canvasVM.scene.models.count >= 2 else { return }
        let meshA = canvasVM.scene.models[0].meshes.first ?? Mesh()
        let meshB = canvasVM.scene.models[1].meshes.first ?? Mesh()
        guard !meshA.vertices.isEmpty, !meshB.vertices.isEmpty else { return }

        sketchEngine.logOperation(type: .booleanUnion, description: "Union de 2 modelos")

        DispatchQueue.global(qos: .userInitiated).async {
            let engine = BooleanEngine()
            let result = engine.booleanUnion(a: meshA, b: meshB)
            DispatchQueue.main.async {
                let model = Model(name: "Union_\(UUID().uuidString.prefix(8))", meshes: [result])
                canvasVM.scene.addModel(model)
                canvasVM.objectWillChange.send()
            }
        }
    }

    private func performBooleanSubtract() {
        guard canvasVM.scene.models.count >= 2 else { return }
        let meshA = canvasVM.scene.models[0].meshes.first ?? Mesh()
        let meshB = canvasVM.scene.models[1].meshes.first ?? Mesh()
        guard !meshA.vertices.isEmpty, !meshB.vertices.isEmpty else { return }

        sketchEngine.logOperation(type: .booleanSubtract, description: "Diferencia de 2 modelos")

        DispatchQueue.global(qos: .userInitiated).async {
            let engine = BooleanEngine()
            let result = engine.booleanDifference(a: meshA, b: meshB)
            DispatchQueue.main.async {
                let model = Model(name: "Subtract_\(UUID().uuidString.prefix(8))", meshes: [result])
                canvasVM.scene.addModel(model)
                canvasVM.objectWillChange.send()
            }
        }
    }

    private func performBooleanIntersect() {
        guard canvasVM.scene.models.count >= 2 else { return }
        let meshA = canvasVM.scene.models[0].meshes.first ?? Mesh()
        let meshB = canvasVM.scene.models[1].meshes.first ?? Mesh()
        guard !meshA.vertices.isEmpty, !meshB.vertices.isEmpty else { return }

        sketchEngine.logOperation(type: .booleanIntersect, description: "Interseccion de 2 modelos")

        DispatchQueue.global(qos: .userInitiated).async {
            let engine = BooleanEngine()
            let result = engine.booleanIntersection(a: meshA, b: meshB)
            DispatchQueue.main.async {
                let model = Model(name: "Intersect_\(UUID().uuidString.prefix(8))", meshes: [result])
                canvasVM.scene.addModel(model)
                canvasVM.objectWillChange.send()
            }
        }
    }

    private func performGroupAssembly() {
        guard canvasVM.scene.models.count >= 2 else { return }
        let modelIDs = canvasVM.scene.models.map { $0.id }
        assemblyEngine.createAssembly(name: "Group_\(UUID().uuidString.prefix(8))", modelIDs: modelIDs)
        sketchEngine.logOperation(type: .booleanUnion, description: "Assembly agrupado (\(modelIDs.count) modelos)")
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

private class PencilForceView: UIView {
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

private func executeCADTool(_ tool: CADTool, canvasVM: CanvasViewModel, toolVM: ToolViewModel) {
    guard let firstMesh = canvasVM.scene.models.first?.meshes.first else { return }
    var mutableMesh = firstMesh

    switch tool {
    case .fillet:
        let engine = FilletEngine()
        if mutableMesh.indices.count >= 6 {
            let e0 = Int(mutableMesh.indices[0])
            let e1 = Int(mutableMesh.indices[1])
            let radius = toolVM.filletRadius
            _ = engine.computeFillet(edges: [(e0, e1)], radius: radius, mesh: &mutableMesh)
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
        let engine = LoftEngine()
        let profile1 = mutableMesh.vertices
        let profile2 = profile1.map { v in
            Vertex(position: v.position + SIMD3<Float>(0, 0, 0.3),
                   normal: v.normal, uv: v.uv)
        }
        let profile3 = profile1.map { v in
            Vertex(position: v.position + SIMD3<Float>(0.15, 0, 0.4),
                   normal: v.normal, uv: v.uv)
        }
        let loftedMesh = engine.computeLoft(curves: [profile1, profile2, profile3], segments: 8)
        if !loftedMesh.vertices.isEmpty {
            let model = Model(name: "Loft_\(UUID().uuidString.prefix(8))", meshes: [loftedMesh])
            canvasVM.scene.addModel(model)
        }

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
            let model = Model(name: "Sweep_\(UUID().uuidString.prefix(8))", meshes: [sweptMesh])
            canvasVM.scene.addModel(model)
        }

    default:
        break
    }

    if !canvasVM.scene.models.isEmpty {
        canvasVM.scene.models[0].meshes[0] = mutableMesh
    }
    canvasVM.objectWillChange.send()
}
