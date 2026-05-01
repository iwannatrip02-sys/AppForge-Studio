import SwiftUI
import MetalKit

struct SatinRendererView: UIViewRepresentable {
    @Binding var scene: Scene3D
    var animationEngine: AnimationEngine? = nil
    var externalRenderer: SatinRenderer? = nil
    var metalBackground: UIColor = .darkGray

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
            return mtkView
        }
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.backgroundColor = metalBackground
        let renderer = SatinRenderer(mtkView: mtkView)
        renderer.updateScene(scene)
        renderer.animationEngine = animationEngine
        context.coordinator.renderer = renderer
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.renderer?.updateScene(scene)
        context.coordinator.renderer?.animationEngine = animationEngine
        uiView.backgroundColor = metalBackground
        uiView.setNeedsDisplay()
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: SatinRenderer?
        @Binding var scene: Scene3D

        init(scene: Binding<Scene3D>) {
            self._scene = scene
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            renderer?.updateScene(scene)
            renderer?.updateAnimation()
            renderer?.render(in: view)
        }
    }
}
