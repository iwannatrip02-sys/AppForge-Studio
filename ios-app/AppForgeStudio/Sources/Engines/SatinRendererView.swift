import SwiftUI
import MetalKit
import QuartzCore
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "SatinRendererView")

struct SatinRendererView: UIViewRepresentable {
    @Binding var scene: Scene3D
    var animationEngine: AnimationEngine? = nil
    var externalRenderer: SatinRenderer? = nil
    @Binding var playbackController: AnimationPlaybackController?
    var metalBackground: UIColor = .darkGray

    init(scene: Binding<Scene3D>,
         animationEngine: AnimationEngine? = nil,
         externalRenderer: SatinRenderer? = nil,
         playbackController: Binding<AnimationPlaybackController?> = .constant(nil),
         metalBackground: UIColor = .darkGray) {
        self._scene = scene
        self.animationEngine = animationEngine
        self.externalRenderer = externalRenderer
        self._playbackController = playbackController
        self.metalBackground = metalBackground
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scene: $scene)
    }

    func makeUIView(context: Context) -> MTKView {
        if let renderer = externalRenderer, let mtkView = renderer.mtkView {
            renderer.updateScene(scene)
            renderer.animationEngine = animationEngine
            context.coordinator.renderer = renderer
            mtkView.delegate = context.coordinator
            mtkView.backgroundColor = metalBackground
            setupPlaybackController(context: context)
            return mtkView
        }
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.backgroundColor = metalBackground
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearColor = MTLClearColor(red: 0.09, green: 0.10, blue: 0.12, alpha: 1.0)
        let renderer = SatinRenderer(mtkView: mtkView)
        renderer.updateScene(scene)
        renderer.animationEngine = animationEngine
        context.coordinator.renderer = renderer
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        setupPlaybackController(context: context)
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.renderer?.updateScene(scene)
        context.coordinator.renderer?.animationEngine = animationEngine
        setupPlaybackController(context: context)
        uiView.backgroundColor = metalBackground
        uiView.setNeedsDisplay()
    }

    private func setupPlaybackController(context: Context) {
        if let engine = animationEngine {
            if context.coordinator.playbackController == nil {
                let controller = AnimationPlaybackController(animationEngine: engine)
                context.coordinator.playbackController = controller
                context.coordinator.renderer?.playbackController = controller
                DispatchQueue.main.async {
                    self.playbackController = controller
                }
            }
        } else {
            context.coordinator.playbackController = nil
            context.coordinator.renderer?.playbackController = nil
            DispatchQueue.main.async {
                self.playbackController = nil
            }
        }
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: SatinRenderer?
        var playbackController: AnimationPlaybackController?
        @Binding var scene: Scene3D

        init(scene: Binding<Scene3D>) {
            self._scene = scene
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            renderer?.updateAnimation()
            renderer?.render(in: view)
        }
    }
}
