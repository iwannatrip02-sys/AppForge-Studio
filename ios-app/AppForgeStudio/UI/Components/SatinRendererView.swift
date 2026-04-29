import SwiftUI
import MetalKit

struct SatinRendererView: UIViewRepresentable {
    @Binding var scene: Scene3D
    
    func makeCoordinator() -> Coordinator {
        Coordinator(scene: $scene)
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.backgroundColor = .black
        let renderer = SatinRenderer(mtkView: mtkView)
        renderer.setup()
        renderer.updateScene(&scene)
        context.coordinator.renderer = renderer
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.renderer?.updateScene(&scene)
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
            renderer?.updateScene(&scene)
            renderer?.draw()
        }
    }
}
