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
                                Circle().fill(selectedBrush == b ? Color.blue : themeManager.currentTheme.textSecondary).frame(width: 6, height: 6)
                                Text(b.rawValue).font(.system(size: 8))
                            }.padding(.horizontal, 6).padding(.vertical, 4)
                                .background(selectedBrush == b ? Color.blue.opacity(0.2) : Color.clear).cornerRadius(8)
                        }
                    }
                }.padding(.horizontal, 8)
            }.padding(.vertical, 4).background(themeManager.isDarkMode ? Color.black.opacity(0.5) : themeManager.currentTheme.surface)

            ContentView(canvasVM: canvasVM, renderer: renderer, brushEngine: toolVM.brushEngine, isPaintMode: toolVM.isPaintMode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 12) {
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
                        .background(Color.blue).foregroundColor(themeManager.currentTheme.textPrimary).cornerRadius(6)
                    }
                }
                Slider(value: $toolVM.radius, in: 0.01...0.5).frame(width: 120)
                Text(String(format: "%.2f", toolVM.radius)).font(.caption).foregroundColor(themeManager.currentTheme.textPrimary).frame(width: 40)
                Toggle("Simetria", isOn: $toolVM.symmetryEnabled).toggleStyle(.switch).font(.caption2)
            }.padding(.horizontal).padding(.vertical, 4).background(themeManager.isDarkMode ? Color.black.opacity(0.6) : themeManager.currentTheme.surface)
        }
    }
}