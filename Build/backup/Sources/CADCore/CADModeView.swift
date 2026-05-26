import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "CADModeView")
struct CADModeView: View {
    @ObservedObject var canvasVM: CanvasViewModel
    var renderer: SatinRenderer
    @ObservedObject var toolVM: ToolViewModel
    @ObservedObject var animationVM: AnimationEngine
    @StateObject private var sketchEngine = CADSketchEngine()
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: AppTheme { themeManager.currentTheme }

    @State private var selectedTool: CADTool = .select
    @State private var showMeasurements = false
    @State private var extrudedMesh: Mesh? = nil
    @State private var shellThickness: Float = 0.05
    @State private var filletRadius: Float = 0.05

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
                    .onChange(of: extrudedMesh) { newMesh in
                        if let mesh = newMesh {
                            let name = "Extruded_\(UUID().uuidString.prefix(8))"
                            let model = Model(name: name, meshes: [mesh])
                            canvasVM.scene.addModel(model)
                            canvasVM.objectWillChange.send()
                            selectedTool = .select
                        }
                    }
            } else {
                toolbarSection
                parameterBar
                ContentView(canvasVM: canvasVM, renderer: renderer)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomBar
            }
            .onChange(of: selectedTool) { newTool in
                executeCADTool(newTool, canvasVM: canvasVM, toolVM: toolVM)
            }
        }.sheet(isPresented: $showMeasurements) {
            NavigationView {
                List {
                    Text(String(format: "Longitud: %.2f mm", toolVM.measurementDistance))
                    Text(String(format: "Area: %.2f mm²", toolVM.measurementArea))
                    Text(String(format: "Volumen: %.3f mm³", toolVM.measurementVolume))
                }.navigationTitle("Mediciones")
            }
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
                HStack {
                    Text("Medicion via OCCT (CSG real)")
                        .font(.caption).foregroundColor(theme.textPrimary)
                    Spacer()
                    Button("Medir") { executeSelectedTool() }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
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
        }.padding(.horizontal, 6).padding(.vertical, 2)
    }

    private var bottomBar: some View {
        HStack {
            Toggle("Snap", isOn: $toolVM.gridSnapEnabled).toggleStyle(.switch).font(.caption)
            Spacer()
            Button("Mediciones") { showMeasurements.toggle() }.font(.caption)
        }.padding(.horizontal).padding(.vertical, 4).background(theme.surface)
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
