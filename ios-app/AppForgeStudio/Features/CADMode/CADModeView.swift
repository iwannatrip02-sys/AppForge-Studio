import SwiftUI

struct CADModeView: View {
    @ObservedObject var canvasVM: CanvasViewModel
    var renderer: SatinRenderer
    @ObservedObject var animationVM: AnimationEngine
    @StateObject private var toolVM = ToolViewModel()
    @StateObject private var sketchEngine = CADSketchEngine()

    @State private var selectedTool: CADTool = .select
    @State private var showMeasurements = false
    @State private var extrudedMesh: Mesh? = nil
    @State private var shellThickness: Float = 0.05
    @State private var filletRadius: Float = 0.05

    private var isSketchTool: Bool {
        switch selectedTool {
        case .line, .circle, .rectangle, .arc, .dimension, .constraint:
            return true
        default:
            return false
        }
    }
    
    private var transformTools: [CADTool] {
        [.select, .move, .rotate, .scale]
    }
    
    private var cadTools: [CADTool] {
        [.extrude, .loopCut, .bevel, .boolean, .fillet, .chamfer, .shell, .loft, .sweep, .measure]
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
                    Button(action: { canvasVM.scene.cadHistory.undo() }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!canvasVM.scene.cadHistory.canUndo)
                    Button(action: { canvasVM.scene.cadHistory.redo() }) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!canvasVM.scene.cadHistory.canRedo)
                    ForEach(transformTools, id: \.self) { tool in
                        toolButton(tool)
                    }
                    Color.white.frame(width: 1, height: 20).opacity(0.3).padding(.horizontal, 4)
                    ForEach(cadTools, id: \.self) { tool in
                        toolButton(tool)
                    }
                    Color.white.frame(width: 1, height: 20).opacity(0.3).padding(.horizontal, 4)
                    ForEach(sketchTools, id: \.self) { tool in
                        toolButton(tool)
                    }
                }.padding(.horizontal, 6).padding(.vertical, 4)
            }
            animationRow
        }
        .background(Color.black.opacity(0.85))
    }
    
    private func toolButton(_ tool: CADTool) -> some View {
        Button(action: {
            selectedTool = tool
            toolVM.selectedTool = tool
            if tool != .select && tool != .move && tool != .rotate && tool != .scale {
                executeSelectedTool()
            }
        }) {
            Text(tool.rawValue)
                .font(.system(size: 9))
                .padding(.horizontal, 5).padding(.vertical, 3)
                .background(selectedTool == tool ? Color.blue : Color.gray.opacity(0.3))
                .foregroundColor(.white).cornerRadius(5)
        }
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
                    Text("Radio:").font(.caption).foregroundColor(.white)
                    Slider(value: $toolVM.filletRadius, in: 0.01...0.5)
                        .frame(width: 120)
                    Text(String(format: "%.2f", toolVM.filletRadius))
                        .font(.caption).foregroundColor(.white).frame(width: 35)
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
                    Text("Radio:").font(.caption).foregroundColor(.white)
                    Slider(value: $toolVM.chamferRadius, in: 0.01...0.5)
                        .frame(width: 120)
                    Text(String(format: "%.2f", toolVM.chamferRadius))
                        .font(.caption).foregroundColor(.white).frame(width: 35)
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
                    Text("Grosor:").font(.caption).foregroundColor(.white)
                    Slider(value: $toolVM.shellThickness, in: 0.005...0.2)
                        .frame(width: 120)
                    Text(String(format: "%.3f", toolVM.shellThickness))
                        .font(.caption).foregroundColor(.white).frame(width: 40)
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
                        .font(.caption).foregroundColor(.white)
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
                    Text("Altura:").font(.caption).foregroundColor(.white)
                    Slider(value: $toolVM.sweepHeight, in: 0.1...2.0)
                        .frame(width: 120)
                    Text(String(format: "%.2f", toolVM.sweepHeight))
                        .font(.caption).foregroundColor(.white).frame(width: 35)
                    Spacer()
                    Button("Aplicar") { executeSelectedTool() }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Color.yellow.opacity(0.12))
            case .boolean:
                HStack {
                    Text("Union con copia desplazada +0.15 en X")
                        .font(.caption).foregroundColor(.white)
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
                        .font(.caption).foregroundColor(.white)
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
                    .foregroundColor(canvasVM.scene.models.isEmpty ? .gray : .blue)
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
        }.padding(.horizontal).padding(.vertical, 4).background(Color.black.opacity(0.6))
    }
}
