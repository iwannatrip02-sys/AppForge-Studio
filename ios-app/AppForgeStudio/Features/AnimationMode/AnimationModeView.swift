import SwiftUI

struct AnimationModeView: View {
    @ObservedObject var canvasVM: CanvasViewModel
    var renderer: SatinRenderer
    @ObservedObject var toolVM: ToolViewModel
    @ObservedObject var animationVM: AnimationEngine
    @ObservedObject var subdivisionVM: SubdivisionEngine
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showTimeline = true

    /// Init explícito: los @State privados hacen privado el init memberwise,
    /// y el chrome (WorkspaceView) instancia esta vista desde otro archivo.
    init(canvasVM: CanvasViewModel, renderer: SatinRenderer, toolVM: ToolViewModel,
         animationVM: AnimationEngine, subdivisionVM: SubdivisionEngine) {
        self.canvasVM = canvasVM
        self.renderer = renderer
        self.toolVM = toolVM
        self.animationVM = animationVM
        self.subdivisionVM = subdivisionVM
    }

    private var theme: AppTheme { themeManager.currentTheme }

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
                Button(action: { animationVM.togglePlayPause() }) {
                    Image(systemName: animationVM.isPlaying ? "pause.fill" : "play.fill")
                }

                Slider(value: Binding(
                    get: { Double(animationVM.currentTime) },
                    set: { animationVM.currentTime = Float($0) }
                ), in: 0...Double(animationVM.currentClipDuration))

                Button(action: { animationVM.stop() }) {
                    Image(systemName: "stop.fill")
                }

                Button(action: { showTimeline.toggle() }) {
                    Image(systemName: "timeline.selection")
                }
            }
            .padding(.horizontal)

            if showTimeline {
                TimelineView(engine: animationVM)
                    .transition(.move(edge: .bottom))
                    .animation(.easeInOut, value: showTimeline)
            }
        }
        .background(theme.background)
    }
}
