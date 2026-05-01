import SwiftUI

struct RenderModeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var canvasVM: CanvasViewModel
    var renderer: SatinRenderer
    @ObservedObject var toolVM: ToolViewModel
    @ObservedObject var animationVM: AnimationEngine
    @ObservedObject var subdivisionVM: SubdivisionEngine

    @State private var showExport = false

    private var strokesBinding: Binding<[BrushStroke]> {
        Binding(
            get: { canvasVM.scene.strokes },
            set: { newVal in
                var s = canvasVM.scene
                s.strokes = newVal
                canvasVM.scene = s
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            MetalView(
                scene: $canvasVM.scene,
                strokes: strokesBinding,
                renderer: renderer,
                animationEngine: animationVM,
                metalBackground: themeManager.currentTheme.metalBackground
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button(action: { showExport = true }) {
                    Label("Exportar", systemImage: "square.and.arrow.up")
                }
                .font(.caption)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.surface)
        }
        .sheet(isPresented: $showExport) {
            ExportView()
        }
        .background(themeManager.currentTheme.background)
    }
}
