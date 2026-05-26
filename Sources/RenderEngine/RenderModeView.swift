import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "RenderModeView")
struct RenderModeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var canvasVM: CanvasViewModel
    var renderer: SatinRenderer
    @ObservedObject var toolVM: ToolViewModel
    @ObservedObject var animationVM: AnimationEngine
    @ObservedObject var subdivisionVM: SubdivisionEngine
    @ObservedObject var materialVM: MaterialEditorViewModel

    @State private var showExport = false
    @State private var showMaterialEditor = false

    init(canvasVM: CanvasViewModel, renderer: SatinRenderer, toolVM: ToolViewModel, animationVM: AnimationEngine, subdivisionVM: SubdivisionEngine, materialVM: MaterialEditorViewModel) {
        self.canvasVM = canvasVM
        self.renderer = renderer
        self.toolVM = toolVM
        self.animationVM = animationVM
        self.subdivisionVM = subdivisionVM
        self.materialVM = materialVM
    }

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
            if showMaterialEditor {
                MaterialEditorView(
                    materialVM: materialVM,
                    canvasVM: canvasVM,
                    renderer: renderer
                )
                .environmentObject(themeManager)
            } else {
                MetalView(
                    scene: $canvasVM.scene,
                    strokes: strokesBinding,
                    renderer: renderer,
                    animationEngine: animationVM,
                    metalBackground: themeManager.currentTheme.metalBackground
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Button(action: { showMaterialEditor.toggle() }) {
                    Label(
                        showMaterialEditor ? "Vista 3D" : "Materiales",
                        systemImage: showMaterialEditor ? "cube.fill" : "paintpalette.fill"
                    )
                }
                .font(.caption)

                if showMaterialEditor {
                    Button(action: {
                        withAnimation {
                            showMaterialEditor = false
                            renderer.updateScene(canvasVM.scene)
                        }
                    }) {
                        Label("Aplicar", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                }

                Spacer()

                Button(action: { showExport = true }) {
                    Label("Exportar", systemImage: "square.and.arrow.up")
                }
                .font(.caption)
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
