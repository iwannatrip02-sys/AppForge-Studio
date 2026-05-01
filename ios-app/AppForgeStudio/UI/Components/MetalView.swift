import SwiftUI
import MetalKit
import simd
import Satin

func perspective_fov(fov: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
    let y = 1.0 / tan(fov * 0.5)
    let x = y / aspect
    let z = far / (far - near)
    return float4x4(SIMD4<Float>(x, 0, 0, 0), SIMD4<Float>(0, y, 0, 0), SIMD4<Float>(0, 0, z, 1), SIMD4<Float>(0, 0, -near * z, 0))
}

func lookAt(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
    let f = simd_normalize(target - eye)
    let s = simd_normalize(simd_cross(f, up))
    let u = simd_cross(s, f)
    return float4x4(SIMD4<Float>(s.x, u.x, -f.x, 0), SIMD4<Float>(s.y, u.y, -f.y, 0), SIMD4<Float>(s.z, u.z, -f.z, 0), SIMD4<Float>(-simd_dot(s, eye), -simd_dot(u, eye), simd_dot(f, eye), 1))
}

func rayTriangleIntersect(rayOrigin: SIMD3<Float>, rayDir: SIMD3<Float>, v0: SIMD3<Float>, v1: SIMD3<Float>, v2: SIMD3<Float>) -> SIMD3<Float>? {
    let edge1 = v1 - v0
    let edge2 = v2 - v0
    let h = simd_cross(rayDir, edge2)
    let a = simd_dot(edge1, h)
    if abs(a) < 0.0001 { return nil }
    let f = 1.0 / a
    let s = rayOrigin - v0
    let u = f * simd_dot(s, h)
    if u < 0.0 || u > 1.0 { return nil }
    let q = simd_cross(s, edge1)
    let v = f * simd_dot(rayDir, q)
    if v < 0.0 || u + v > 1.0 { return nil }
    let t = f * simd_dot(edge2, q)
    if t > 0.0001 { return rayOrigin + rayDir * t }
    return nil
}

struct MetalView: UIViewRepresentable {
    @Binding var scene: Scene3D
    @Binding var strokes: [BrushStroke]
    var renderer: SatinRenderer
    var animationEngine: AnimationEngine?
    var onTouch3D: ((SIMD3<Float>, SIMD3<Float>) -> Void)?
    var metalBackground: UIColor = .darkGray
    
    func makeCoordinator() -> Coordinator { Coordinator(scene: $scene, strokes: $strokes, renderer: renderer, onTouch3D: onTouch3D, animationEngine: animationEngine) }
    
    func makeUIView(context: Context) -> MTKView {
        let v = MTKView()
        v.device = MTLCreateSystemDefaultDevice()
        v.backgroundColor = metalBackground
        v.delegate = context.coordinator
        renderer.updateScene(scene)
        renderer.animationEngine = animationEngine
        return v
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.renderer = renderer
        context.coordinator.scene = scene
        context.coordinator.strokes = strokes
        context.coordinator.animationEngine = animationEngine
        renderer.updateScene(scene)
        renderer.animationEngine = animationEngine
        uiView.backgroundColor = metalBackground
        uiView.setNeedsDisplay()
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: SatinRenderer
        var animationEngine: AnimationEngine?
        @Binding var scene: Scene3D
        @Binding var strokes: [BrushStroke]
        var onTouch3D: ((SIMD3<Float>, SIMD3<Float>) -> Void)?
        
        init(scene: Binding<Scene3D>, strokes: Binding<[BrushStroke]>, renderer: SatinRenderer, onTouch3D: ((SIMD3<Float>, SIMD3<Float>) -> Void)?, animationEngine: AnimationEngine? = nil) {
            self._scene = scene
            self._strokes = strokes
            self.renderer = renderer
            self.onTouch3D = onTouch3D
            self.animationEngine = animationEngine
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        func draw(in view: MTKView) {
            renderer.updateScene(scene)
            renderer.updateAnimation()
            renderer.render(in: view)
        }
    }
}
