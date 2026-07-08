import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "SculptModeView")
struct SculptModeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var canvasVM: CanvasViewModel
    var renderer: SatinRenderer
    var animationVM: AnimationEngine?
    @ObservedObject var toolVM: ToolViewModel
    @ObservedObject var subdivisionVM: SubdivisionEngine

    @State private var selectedBrush: DeformerType = .grab
    @State private var subdivisionLevels: Double = 2
    @State private var brushStrength: Float = 0.5

    /// Init explícito: los @State privados hacen privado el init memberwise,
    /// y el chrome (WorkspaceView) instancia esta vista desde otro archivo.
    init(canvasVM: CanvasViewModel, renderer: SatinRenderer, animationVM: AnimationEngine?,
         toolVM: ToolViewModel, subdivisionVM: SubdivisionEngine) {
        self.canvasVM = canvasVM
        self.renderer = renderer
        self.animationVM = animationVM
        self.toolVM = toolVM
        self.subdivisionVM = subdivisionVM
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Modo", selection: $toolVM.isPaintMode) {
                Text("Esculpir").tag(false); Text("Pintar").tag(true)
            }.pickerStyle(.segmented).padding(.horizontal).padding(.vertical, 4)

            // Los 10 deformers REALES del SculptEngine — seleccionar cambia el
            // pincel del pipeline táctil (antes este selector era decorativo).
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(DeformerType.allCases, id: \.self) { b in
                        Button(action: {
                            HapticService.shared.light()
                            selectedBrush = b
                            renderer.sculptEngine?.setDeformer(b)
                        }) {
                            VStack(spacing: 2) {
                                Circle().fill(selectedBrush == b ? themeManager.currentTheme.accent : themeManager.currentTheme.textSecondary).frame(width: 6, height: 6)
                                Text(b.displayNameES).font(.system(size: 8))
                            }.padding(.horizontal, 6).padding(.vertical, 4)
                                .background(selectedBrush == b ? themeManager.currentTheme.accent.opacity(0.15) : Color.clear).cornerRadius(themeManager.currentTheme.cornerRadiusSmall)
                        }
                    }
                }.padding(.horizontal, 8)
            }.padding(.vertical, 4).background(themeManager.currentTheme.surface)

            ContentView(canvasVM: canvasVM, renderer: renderer, brushEngine: nil,
                        isPaintMode: toolVM.isPaintMode, sculptEnabled: !toolVM.isPaintMode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 12) {
                // Undo/Redo buttons connected to SculptEngine
                Button(action: {
                    var verts = canvasVM.currentMesh.vertices
                    if renderer.sculptEngine?.undo(&verts) == true {
                        var mesh = canvasVM.currentMesh
                        mesh.vertices = verts
                        canvasVM.currentMesh = mesh  // triggers GPU upload via setter
                    }
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14))
                }
                .disabled(!(renderer.sculptEngine?.canUndo ?? false))
                .opacity((renderer.sculptEngine?.canUndo ?? false) ? 1.0 : 0.4)

                Button(action: {
                    var verts = canvasVM.currentMesh.vertices
                    if renderer.sculptEngine?.redo(&verts) == true {
                        var mesh = canvasVM.currentMesh
                        mesh.vertices = verts
                        canvasVM.currentMesh = mesh
                    }
                }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 14))
                }
                .disabled(!(renderer.sculptEngine?.canRedo ?? false))
                .opacity((renderer.sculptEngine?.canRedo ?? false) ? 1.0 : 0.4)

                if subdivisionVM.isSubdividing {
                    ProgressView(value: subdivisionVM.progress).frame(width: 80)
                } else {
                    HStack(spacing: 4) {
                        Text("Sub").font(.caption)
                        Slider(value: $subdivisionLevels, in: 1...4, step: 1).frame(width: 100)
                        Text("\(Int(subdivisionLevels))").font(.caption).foregroundColor(themeManager.currentTheme.textPrimary).frame(width: 20)
                        Button("Aplicar") {
                            canvasVM.saveState()
                            let mesh = canvasVM.currentMesh
                            canvasVM.currentMesh = subdivisionVM.subdivide(mesh, levels: Int(subdivisionLevels))
                        }
                        .font(.caption).padding(.horizontal, 6).padding(.vertical, 4)
                        .background(themeManager.currentTheme.accent).foregroundColor(themeManager.currentTheme.textPrimary).cornerRadius(themeManager.currentTheme.cornerRadiusSmall)
                    }
                }
                Text("Radio").font(.caption2).foregroundColor(themeManager.currentTheme.textSecondary)
                Slider(value: $toolVM.radius, in: 0.01...0.5).frame(width: 100)
                Text(String(format: "%.2f", toolVM.radius)).font(.caption).foregroundColor(themeManager.currentTheme.textPrimary).frame(width: 36)
                Text("Fuerza").font(.caption2).foregroundColor(themeManager.currentTheme.textSecondary)
                Slider(value: $brushStrength, in: 0.05...1.0).frame(width: 100)
                Toggle("Simetria", isOn: $toolVM.symmetryEnabled).toggleStyle(.switch).font(.caption2)
            }.padding(.horizontal).padding(.vertical, 4).background(themeManager.currentTheme.surface)
        }
        // Sincronización vista → engine: el SculptEngine no es ObservableObject,
        // así que los parámetros se empujan explícitamente.
        .onAppear {
            renderer.sculptEngine?.setDeformer(selectedBrush)
            renderer.sculptEngine?.radius = toolVM.radius
            renderer.sculptEngine?.strength = brushStrength
            renderer.sculptEngine?.symmetryEnabled = toolVM.symmetryEnabled
        }
        .onChange(of: toolVM.radius) { r in renderer.sculptEngine?.radius = r }
        .onChange(of: brushStrength) { s in renderer.sculptEngine?.strength = s }
        .onChange(of: toolVM.symmetryEnabled) { s in renderer.sculptEngine?.symmetryEnabled = s }
    }
}
