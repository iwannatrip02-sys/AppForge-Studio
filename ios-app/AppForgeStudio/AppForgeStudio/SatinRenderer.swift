import Foundation
import Satin
import MetalKit
import Combine
import simd

private struct Uniforms {
    var modelMatrix: simd_float4x4
    var viewMatrix: simd_float4x4
    var projectionMatrix: simd_float4x4
    var ambientColor: SIMD3<Float>
    var lightDirection: SIMD3<Float>
    var lightColor: SIMD3<Float>
    var lightIntensity: Float
}

class SatinRenderer: NSObject, ObservableObject {
    let device: MTLDevice
    var scene: Object
    var camera: PerspectiveCamera
    @Published var scene3D: Scene3D?

    // MARK: - Animation Connection
    var animationEngine: AnimationEngine?
    var onTransformsApplied: (([String: simd_float4x4]) -> Void)?
    private var lastFrameTime: CFTimeInterval = 0

    func updateAnimation() {
        guard let engine = animationEngine, engine.isPlaying else { return }
        let now = CACurrentMediaTime()
        if lastFrameTime == 0 { lastFrameTime = now }
        let deltaTime = Float(now - lastFrameTime)
        lastFrameTime = now

        let transforms = engine.evaluateAnimation(deltaTime: deltaTime)
        onTransformsApplied?(transforms)
        engine.objectWillChange.send()

        guard var scene3D = self.scene3D else { return }
        for i in 0..<scene3D.models.count {
            let model = scene3D.models[i]
            if let transform = transforms[model.id.uuidString] {
                let translation = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
                let rotationMatrix = simd_float3x3(columns: (
                    SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
                    SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
                    SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
                ))
                let rotation = simd_quatf(rotationMatrix)
                let scaleX = simd_length(SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z))
                let scaleY = simd_length(SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z))
                let scaleZ = simd_length(SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z))
                let scale = SIMD3<Float>(scaleX, scaleY, scaleZ)

                scene3D.models[i].position = translation
                scene3D.models[i].rotation = rotation
                scene3D.models[i].scale = scale
            }
        }
        self.scene3D = scene3D
        rebuildSceneFrom(scene3D)
    }
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var depthState: MTLDepthStencilState?
    weak var mtkView: MTKView?

    init(mtkView: MTKView) {
        self.device = mtkView.device ?? MTLCreateSystemDefaultDevice()!
        self.commandQueue = self.device.makeCommandQueue()!
        self.scene = Object()
        self.camera = PerspectiveCamera()
        self.mtkView = mtkView
        super.init()
        mtkView.framebufferOnly = false
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        setup()
    }

    func setup() {
        guard let library = device.makeDefaultLibrary() else { return }
        guard let vertexFn = library.makeFunction(name: "vertex_main"),
              let fragmentFn = library.makeFunction(name: "fragment_main") else { return }

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

        let layout = MTLVertexDescriptor().layouts[0]
        layout.stride = MemoryLayout<Float>.size * 9
        layout.stepRate = 1
        layout.stepFunction = .perVertex

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFn
        pipelineDescriptor.fragmentFunction = fragmentFn
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView?.colorPixelFormat ?? .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
        }

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
    }

    func updateScene(_ scene3D: Scene3D) {
        self.scene3D = scene3D
        rebuildSceneFrom(scene3D)
    }

    private func rebuildSceneFrom(_ scene3D: Scene3D) {
        scene = Object()
        for model in scene3D.models {
            let object = buildObject(from: model)
            scene.add(object)
        }
    }

    private func buildObject(from model: Model) -> Object {
        if let vb = model.vertexBuffer, let ib = model.indexBuffer,
           model.vertexCount > 0, model.indexCount > 0 {
            let vertexCount = model.vertexCount
            let indexCount = model.indexCount
            let data = GeometryData(
                vertices: [],
                normals: [],
                uvs: [],
                indices: []
            )
            let geometry = Geometry(data: data)
            geometry.vertexBuffer = vb
            geometry.indexBuffer = ib
            geometry.vertexCount = vertexCount
            geometry.indexCount = indexCount
            let material = BasicMaterial(color: model.color)
            let object = Object(geometry: geometry, material: material)
            object.position = model.position
            return object
        }
        var vertices: [Float] = []
        var indices: [UInt16] = []
        for mesh in model.meshes {
            let baseIndex = UInt16(vertices.count / 9)
            for v in mesh.vertices {
                vertices.append(v.position.x)
                vertices.append(v.position.y)
                vertices.append(v.position.z)
                vertices.append(0)
                vertices.append(v.normal.x)
                vertices.append(v.normal.y)
                vertices.append(v.normal.z)
                vertices.append(v.uv.x)
                vertices.append(v.uv.y)
            }
            for idx in mesh.indices {
                indices.append(baseIndex + UInt16(idx))
            }
        }
        if vertices.isEmpty {
            vertices = [0,0,0, 0,0,0,1,0,0, 1,0,0, 0,0,0,1,0,0, 1,0,0, 0,0,0,1,0,0]
            indices = [0,1,2, 2,1,3]
        }
        let data = GeometryData(
            vertices: vertices,
            normals: [],
            uvs: [],
            indices: indices
        )
        let geometry = Geometry(data: data)
        let material = BasicMaterial(color: model.color)
        let object = Object(geometry: geometry, material: material)
        object.position = model.position
        return object
    }

    func update() {
        updateAnimation()
    }

    func render(in view: MTKView) {
        update()

        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let pipelineState = pipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState)

        var uniforms = Uniforms(
            modelMatrix: matrix_identity_float4x4,
            viewMatrix: camera.viewMatrix,
            projectionMatrix: camera.projectionMatrix,
            ambientColor: SIMD3<Float>(0.2, 0.2, 0.2),
            lightDirection: simd_normalize(SIMD3<Float>(0.0, -1.0, -1.0)),
            lightColor: SIMD3<Float>(1.0, 1.0, 1.0),
            lightIntensity: 0.8
        )

        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

        scene.draw(encoder: encoder)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func draw() {
        guard let view = mtkView else { return }
        render(in: view)
    }
}
