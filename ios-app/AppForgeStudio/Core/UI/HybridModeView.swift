import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "HybridModeView")
struct HybridModeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var canvasVM: CanvasViewModel
    var renderer: SatinRenderer
    @ObservedObject var toolVM: ToolViewModel
    @ObservedObject var animationVM: AnimationEngine
    @ObservedObject var subdivisionVM: SubdivisionEngine

    @State private var activeMode: ActiveMode = .sculpt
    @State private var showLayers = false
    @State private var showTimeline = false

    enum ActiveMode: String, CaseIterable {
        case cad = "CAD"
        case sculpt = "Esculpir"
        case paint = "Pintar"
        case animate = "Animar"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ForEach(ActiveMode.allCases, id: \.self) { m in
                    Button(action: { activeMode = m }) {
                        Text(m.rawValue).font(.caption).padding(.horizontal, 16).padding(.vertical, 6)
                            .background(activeMode == m ? Color.accentColor : themeManager.currentTheme.surfaceSecondary)
                            .foregroundColor(themeManager.currentTheme.textPrimary).cornerRadius(8)
                    }
                }
                Spacer()
                Button(action: { showLayers.toggle() }) {
                    Image(systemName: "square.3.layers.3d")
                }
            }.padding(.horizontal).padding(.vertical, 6).background(themeManager.currentTheme.surface)

            ContentView(canvasVM: canvasVM, renderer: renderer, brushEngine: toolVM.brushEngine, isPaintMode: activeMode == .paint || activeMode == .animate)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showTimeline && activeMode == .animate {
                TimelineView(engine: animationVM)
                    .transition(.move(edge: .bottom))
                    .animation(.easeInOut, value: showTimeline)
            }

            Group {
                switch activeMode {
                case .cad:
                    HStack {
                        Text("CAD").font(.caption).bold()
                        Spacer()
                        Button("Extruir") {}.font(.caption)
                        Button("Loop Cut") {}.font(.caption)
                        Button("Bisel") {}.font(.caption)
                    }
                case .sculpt:
                    HStack {
                        Text("Esculpir").font(.caption).bold()
                        Spacer()
                        Button("Subdividir") { if let model = canvasVM.scene.models.first { let subdivided = subdivisionVM.subdivide(model.meshes.first ?? Mesh(vertices: [], indices: []), levels: 1); let newModel = Model(name: model.name + "_subd", meshes: [subdivided]); canvasVM.scene.addModel(newModel); canvasVM.objectWillChange.send() } }.font(.caption)
                        Button("Remesh") {}.font(.caption)
                    }
                case .paint:
                    HStack {
                        Text("Pintar").font(.caption).bold()
                        Spacer()
                        Button("Color") {}.font(.caption)
                        Button("Tamaño") {}.font(.caption)
                        Button("Opacidad") {}.font(.caption)
                    }
                case .animate:
                    HStack {
                        Text("Animación").font(.caption).bold()
                        Spacer()
                        Button(action: { showTimeline.toggle() }) {
                            Image(systemName: "timeline.selection")
                        }
                        Button(action: {
                            if let firstMesh = canvasVM.scene.models.first?.meshes.first {
                                var m = firstMesh
                                canvasVM.scene.models[0].meshes[0] = subdivisionVM.subdivide(m, levels: 1)
                            }
                        }) {
                            Image(systemName: "square.grid.3x3.topleft.filled")
                        }
                        .disabled(canvasVM.scene.models.isEmpty || subdivisionVM.isSubdividing)
                    }
                }
            }.padding(.horizontal).padding(.vertical, 4).background(themeManager.currentTheme.surfaceSecondary)
        }
    }
}