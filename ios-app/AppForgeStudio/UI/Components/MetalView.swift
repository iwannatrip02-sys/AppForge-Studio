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
    var onTouch3D: ((SIMD3<Float>, SIMD3<Float>) -> Void)?
    
    func makeCoordinator() -> Coordinator { Coordinator(scene: $scene, strokes: $strokes, renderer: renderer, onTouch3D: onTouch3D) }
    
    func makeUIView(context: Context) -> MTKView {
        let v = MTKView()
        v.device = MTLCreateSystemDefaultDevice()
        v.backgroundColor = .darkGray
        v.delegate = context.coordinator
        v.enableSetNeedsDisplay = true
        v.isPaused = false
        v.framebufferOnly = false
        v.sampleCount = 4
        v.clearColor = MTLClearColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
        v.isMultipleTouchEnabled = true
        context.coordinator.setup(device: v.device!, view: v)
        return v
    }
    
    func updateUIView(_ v: MTKView, context: Context) {
        context.coordinator.scene = $scene
        context.coordinator.strokes = $strokes
        context.coordinator.onTouch3D = onTouch3D
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        @Binding var scene: Scene3D
        @Binding var strokes: [BrushStroke]
        var renderer: SatinRenderer
        var onTouch3D: ((SIMD3<Float>, SIMD3<Float>) -> Void)?
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        var pipelineState: MTLRenderPipelineState!
        var depthState: MTLDepthStencilState!
        var strokeRenderer: StrokeRenderer!
        
        init(scene: Binding<Scene3D>, strokes: Binding<[BrushStroke]>, renderer: SatinRenderer, onTouch3D: ((SIMD3<Float>, SIMD3<Float>) -> Void)?) {
            _scene = scene
            _strokes = strokes
            self.renderer = renderer
            self.onTouch3D = onTouch3D
        }
        
        func setup(device: MTLDevice, view: MTKView) {
            self.device = device
            commandQueue = device.makeCommandQueue()
            strokeRenderer = StrokeRenderer(device: device)
            let library = device.makeDefaultLibrary()
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertex_main")
            pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragment_main")
            pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
            
            let vertexDescriptor = MTLVertexDescriptor()
            vertexDescriptor.attributes[0].format = .float4
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0
            vertexDescriptor.attributes[1].format = .float3
            vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 4
            vertexDescriptor.attributes[1].bufferIndex = 0
            vertexDescriptor.attributes[2].format = .float2
            vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.size * 7
            vertexDescriptor.attributes[2].bufferIndex = 0
            vertexDescriptor.attributes[3].format = .float4
            vertexDescriptor.attributes[3].offset = MemoryLayout<Float>.size * 9
            vertexDescriptor.attributes[3].bufferIndex = 0
            vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
            pipelineDescriptor.vertexDescriptor = vertexDescriptor
            
            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch { print("Pipeline error: \(error)") }
            
            let depthDescriptor = MTLDepthStencilDescriptor()
            depthDescriptor.depthCompareFunction = .less
            depthDescriptor.isDepthWriteEnabled = true
            depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable, let descriptor = view.currentRenderPassDescriptor else { return }
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            
            let cam = scene.camera
            let viewMatrix = lookAt(eye: cam.position, target: cam.target, up: cam.up)
            let aspect = Float(view.bounds.size.width / view.bounds.size.height)
            let projMatrix = perspective_fov(fov: cam.fov * .pi / 180, aspect: aspect, near: cam.nearPlane, far: cam.farPlane)
            
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
            encoder.setRenderPipelineState(pipelineState)
            encoder.setDepthStencilState(depthState)
            encoder.setFrontFacing(.counterClockwise)
            encoder.setCullMode(.back)
            
            var uniforms = Uniforms(modelMatrix: matrix_identity_float4x4, viewMatrix: viewMatrix, projectionMatrix: projMatrix, cameraPosition: cam.position)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            
            var fragUniforms = FragmentUniforms(ambientColor: scene.lighting.ambientColor, lightDirection: scene.lighting.directionalLight.direction, lightColor: scene.lighting.directionalLight.color, lightIntensity: scene.lighting.directionalLight.intensity, paintColor: SIMD4<Float>(1,1,1,1), hasTexture: false)
            encoder.setFragmentBytes(&fragUniforms, length: MemoryLayout<FragmentUniforms>.stride, index: 0)
            
            for model in scene.models {
                for mesh in model.meshes {
                    if let vb = mesh.vertexBuffer, let ib = mesh.indexBuffer {
                        encoder.setVertexBuffer(vb, offset: 0, index: 0)
                        encoder.drawIndexedPrimitives(type: .triangle, indexCount: mesh.indices.count, indexType: .uint32, indexBuffer: ib, indexBufferOffset: 0)
                    }
                }
            }
            encoder.endEncoding()
            
            strokeRenderer.render(strokes: strokes, commandBuffer: commandBuffer, renderPassDescriptor: descriptor, viewMatrix: viewMatrix, projectionMatrix: projMatrix)
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first, let view = touch.view as? MTKView, view.bounds.size.width > 0, view.bounds.size.height > 0 else { return }
            let location = touch.location(in: view)
            let size = view.bounds.size
            let normalized = CGPoint(x: location.x / size.width * 2 - 1, y: -(location.y / size.height * 2 - 1))
            let cam = scene.camera
            let viewMatrix = lookAt(eye: cam.position, target: cam.target, up: cam.up)
            let proj = perspective_fov(fov: cam.fov * .pi / 180, aspect: Float(size.width/size.height), near: cam.nearPlane, far: cam.farPlane)
            let invProjView = simd_inverse(proj * viewMatrix)
            
            let nearPoint = invProjView * SIMD4<Float>(Float(normalized.x), Float(normalized.y), 0, 1)
            let farPoint = invProjView * SIMD4<Float>(Float(normalized.x), Float(normalized.y), 1, 1)
            let near = SIMD3<Float>(nearPoint.x, nearPoint.y, nearPoint.z) / nearPoint.w
            let far = SIMD3<Float>(farPoint.x, farPoint.y, farPoint.z) / farPoint.w
            let rayDir = simd_normalize(far - near)
            
            for model in scene.models {
                for mesh in model.meshes {
                    for i in 0..<(mesh.indices.count / 3) {
                        let i0 = Int(mesh.indices[i*3])
                        let i1 = Int(mesh.indices[i*3+1])
                        let i2 = Int(mesh.indices[i*3+2])
                        guard i0 < mesh.vertices.count, i1 < mesh.vertices.count, i2 < mesh.vertices.count else { continue }
                        let v0 = mesh.vertices[i0].position
                        let v1 = mesh.vertices[i1].position
                        let v2 = mesh.vertices[i2].position
                        if let hit = rayTriangleIntersect(rayOrigin: near, rayDir: rayDir, v0: v0, v1: v1, v2: v2) {
                            let normal = simd_normalize(simd_cross(v1 - v0, v2 - v0))
                            onTouch3D?(hit, normal)
                            return
                        }
                    }
                }
            }
        }
        
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            touchesBegan(touches, with: event)
        }
    }
}
