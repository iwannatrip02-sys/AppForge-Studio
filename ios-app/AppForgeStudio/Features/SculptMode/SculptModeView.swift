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

    @State private var selectedBrush: BrushOption = .round
    @State private var subdivisionLevels: Double = 2

    enum BrushOption: String, CaseIterable {
        case round = "Redondo", flat = "Plano", inflate = "Inflar", pinch = "Pellizcar"
        case smooth = "Suavizar", crease = "Pliegue", grab = "Agarrar", clay = "Arcilla", airbrush = "Aerografo"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Modo", selection: $toolVM.isPaintMode) {
                Text("Esculpir").tag(false); Text("Pintar").tag(true)
            }.pickerStyle(.segmented).padding(.horizontal).padding(.vertical, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(BrushOption.allCases, id: \.self) { b in
                        Button(action: { selectedBrush = b }) {
                            VStack(spacing: 2) {
                                Circle().fill(selectedBrush == b ? themeManager.currentTheme.accent : themeManager.currentTheme.textSecondary).frame(width: 6, height: 6)
                                Text(b.rawValue).font(.system(size: 8))
                            }.padding(.horizontal, 6).padding(.vertical, 4)
                                .background(selectedBrush == b ? themeManager.currentTheme.accent.opacity(0.15) : Color.clear).cornerRadius(themeManager.currentTheme.cornerRadiusSmall)
                        }
                    }
                }.padding(.horizontal, 8)
            }.padding(.vertical, 4).background(themeManager.currentTheme.surface)

            ContentView(canvasVM: canvasVM, renderer: renderer, brushEngine: nil, isPaintMode: toolVM.isPaintMode)
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
                Slider(value: $toolVM.radius, in: 0.01...0.5).frame(width: 120)
                Text(String(format: "%.2f", toolVM.radius)).font(.caption).foregroundColor(themeManager.currentTheme.textPrimary).frame(width: 40)
                Toggle("Simetria", isOn: $toolVM.symmetryEnabled).toggleStyle(.switch).font(.caption2)
            }.padding(.horizontal).padding(.vertical, 4).background(themeManager.currentTheme.surface)
        }
    }
}
