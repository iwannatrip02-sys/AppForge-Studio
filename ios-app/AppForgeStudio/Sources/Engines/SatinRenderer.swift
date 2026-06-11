import Foundation
import Satin
import MetalKit
import Combine
import simd
import QuartzCore
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "SatinRenderer")
private struct FrameUniforms {
    var modelMatrix: simd_float4x4
    var viewMatrix: simd_float4x4
    var projectionMatrix: simd_float4x4
    var cameraPosition: SIMD4<Float>
    var normalMatrix: simd_float3x3
}

private struct BasicUniforms {
    var modelMatrix: simd_float4x4
    var viewMatrix: simd_float4x4
    var projectionMatrix: simd_float4x4
    var ambientColor: SIMD3<Float>
    var lightDirection: SIMD3<Float>
    var lightColor: SIMD3<Float>
    var lightIntensity: Float
    var normalMatrix: simd_float3x3
}

struct GPUPBRMaterial {
    var albedoR: Float; var albedoG: Float; var albedoB: Float; var _pad1: Float = 0
    var metallic: Float
    var roughness: Float
    var ao: Float
    var _padEmissionAlign: Float = 0
    var emissionR: Float; var emissionG: Float; var emissionB: Float; var _pad2: Float = 0
    var emissionIntensity: Float
}

struct GPUPointLight {
    var posX: Float; var posY: Float; var posZ: Float; var _pad1: Float = 0
    var colR: Float; var colG: Float; var colB: Float; var _pad2: Float = 0
    var intensity: Float
    var range: Float
}

struct GPUDirectionalLight {
    var dirX: Float; var dirY: Float; var dirZ: Float; var _pad1: Float = 0
    var colR: Float; var colG: Float; var colB: Float; var _pad2: Float = 0
    var intensity: Float
}

struct GPULightUniforms {
    var ambientR: Float; var ambientG: Float; var ambientB: Float
    var pointLightCount: UInt32
    var directionalLight: GPUDirectionalLight
    var pointLights: (
        GPUPointLight, GPUPointLight, GPUPointLight, GPUPointLight
    )
}

struct IBLUniforms {
    var inverseView: simd_float4x4
    var roughnessLevels: Float
}

private struct PBRRenderable {
    var vertexBuffer: MTLBuffer
    var indexBuffer: MTLBuffer
    var indexCount: Int
    var pbrMaterial: GPUPBRMaterial
    var model: Model
}

class SatinRenderer: NSObject, ObservableObject {
    let device: MTLDevice
    var scene: Object? = nil
    var camera: PerspectiveCamera
    @Published var scene3D: Scene3D?

    var animationEngine: AnimationEngine?
    var playbackController: AnimationPlaybackController?
    var onTransformsApplied: (([String: simd_float4x4]) -> Void)?
    var sculptEngine: SculptEngine?

    /// World-space position for the brush cursor indicator (set from MetalView touch handlers).
    /// nil = cursor hidden.
    var brushCursorPosition: SIMD3<Float>? = nil
    /// Radius of the brush cursor indicator in world units.
    var brushCursorRadius: Float = 0.05

    func setSculptEngine(_ engine: SculptEngine) {
        self.sculptEngine = engine
    }
    /// Number of times rebuildSceneFrom() has been called. Testability hook (F0 regression test).
    private(set) var rebuildCount: Int = 0
    private var lastFrameTime: CFTimeInterval = 0
    private var sceneObjectCount: Int = 0
    private var modelIdToObject: [String: Object] = [:]

    func updateAnimation() {
        let now = CACurrentMediaTime()
        if lastFrameTime == 0 { lastFrameTime = now }
        let deltaTime = Float(now - lastFrameTime)
        lastFrameTime = now

        playbackController?.tick(deltaTime: deltaTime)
        guard let engine = animationEngine else { return }

        if playbackController != nil {
            applyCurrentEngineTransforms()
            return
        }

        guard engine.isPlaying else { return }

        let transforms = engine.evaluateAnimation(deltaTime: deltaTime)
        guard !transforms.isEmpty else { return }

        applyTransformsToScene(transforms)
    }

    private func applyCurrentEngineTransforms() {
        guard let engine = animationEngine else { return }
        let transforms = engine.currentTransforms
        guard !transforms.isEmpty else { return }
        applyTransformsToScene(transforms)
    }

    private func applyTransformsToScene(_ transforms: [String: simd_float4x4]) {
        onTransformsApplied?(transforms)

        guard var scene3D = self.scene3D else { return }
        var anyApplied = false
        for i in 0..<scene3D.models.count {
            let model = scene3D.models[i]
            let idKey = model.id.uuidString
            let transform = transforms[model.name] ?? transforms[idKey]
            guard let transform = transform else { continue }
            anyApplied = true

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

            // Update Scene3D model
            scene3D.models[i].position = translation
            scene3D.models[i].rotation = rotation
            scene3D.models[i].scale = scale

            // Update Satin Object in-place (basic pipeline)
            if let object = modelIdToObject[idKey] {
                object.position = translation
                object.rotation = rotation
                object.scale = scale
            }

            // Update PBRRenderable model in-place (PBR pipeline)
            if let pbrIndex = pbrRenderables.firstIndex(where: { $0.model.id == model.id }) {
                pbrRenderables[pbrIndex].model.position = translation
                pbrRenderables[pbrIndex].model.rotation = rotation
                pbrRenderables[pbrIndex].model.scale = scale
            }
        }

        if anyApplied {
            self.scene3D = scene3D
            // Transforms updated in-place — no rebuild needed
        }
    }

    private let commandQueue: MTLCommandQueue
    private var basicPipelineState: MTLRenderPipelineState?
    private var pbrPipelineState: MTLRenderPipelineState?
    private var pbrIBLPipelineState: MTLRenderPipelineState?
    private var iblPipelineState: MTLRenderPipelineState?
    private var iblSamplerState: MTLSamplerState?
    private var iblComputePipeline: IBLPipeline?
    private var depthState: MTLDepthStencilState?
    weak var mtkView: MTKView?

    private var pbrRenderables: [PBRRenderable] = []
    private var cursorObject: Object?
    private var cursorSetupDone = false

    var irradianceMap: MTLTexture?
    var prefilterMap: MTLTexture?
    var brdfLUT: MTLTexture?

    private var equirectToCubemapPS: MTLComputePipelineState?
    private var irradianceConvolutionPS: MTLComputePipelineState?
    private var prefilterConvolutionPS: MTLComputePipelineState?
    private var brdfLUTPS: MTLComputePipelineState?

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

        setupBasicPipeline(library: library)
        setupPBRPipeline(library: library)
        setupPBRIBLPipeline(library: library)
        setupIBLPipeline(library: library)

        iblComputePipeline = IBLPipeline(device: device, library: library)

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
        animationEngine?.onFrameTick = { [weak self] in self?.mtkView?.setNeedsDisplay() }
        setupCursorObject()
    }

    /// Creates a small wireframe sphere Object used as the brush cursor indicator (lazy, called once).
    private func setupCursorObject() {
        guard !cursorSetupDone else { return }
        cursorSetupDone = true

        // Build a low-poly icosahedron-like sphere for the cursor
        let t: Float = (1.0 + sqrt(5.0)) / 2.0
        let rawVerts: [SIMD3<Float>] = [
            SIMD3<Float>(-1,  t,  0), SIMD3<Float>( 1,  t,  0), SIMD3<Float>(-1, -t,  0), SIMD3<Float>( 1, -t,  0),
            SIMD3<Float>( 0, -1,  t), SIMD3<Float>( 0,  1,  t), SIMD3<Float>( 0, -1, -t), SIMD3<Float>( 0,  1, -t),
            SIMD3<Float>( t,  0, -1), SIMD3<Float>( t,  0,  1), SIMD3<Float>(-t,  0, -1), SIMD3<Float>(-t,  0,  1),
        ]
        var verts: [Float] = []
        for v in rawVerts {
            let n = simd_normalize(v)
            let s: Float = 0.04 // small radius
            verts.append(contentsOf: [n.x * s, n.y * s, n.z * s, 0,  // position + w
                                       n.x, n.y, n.z,              // normal
                                       0.0, 0.0])                   // uv
        }
        let indices: [UInt32] = [
            0,11,5, 0,5,1, 0,1,7, 0,7,10, 0,10,11,
            1,5,9, 5,11,4, 11,10,2, 10,7,6, 7,1,8,
            3,9,4, 3,4,2, 3,2,6, 3,6,8, 3,8,9,
            4,9,5, 2,4,11, 6,2,10, 8,6,7, 9,8,1,
        ]
        let data = GeometryData(vertices: verts, normals: [], uvs: [], indices: indices)
        let geometry = Geometry(data: data)
        geometry.vertexBuffer = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<Float>.stride, options: .storageModeShared)
        geometry.indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt32>.stride, options: .storageModeShared)
        geometry.vertexCount = rawVerts.count
        geometry.indexCount = indices.count
        let mat = BasicMaterial(color: SIMD4<Float>(0.2, 0.6, 1.0, 0.8))
        let obj = Object(geometry: geometry, material: mat)
        obj.visible = false
        cursorObject = obj
        scene?.add(obj)
    }

    private func setupBasicPipeline(library: MTLLibrary) {
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

        let layout = vertexDescriptor.layouts[0]
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
            basicPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            logger.info("Failed to create basic pipeline state: \(error)")
        }
    }

    private func setupPBRPipeline(library: MTLLibrary) {
        guard let vertexFn = library.makeFunction(name: "pbr_vertex_main"),
              let fragmentFn = library.makeFunction(name: "pbr_fragment_main") else {
            logger.info("PBR shader functions not found in library")
            return
        }

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

        let layout = vertexDescriptor.layouts[0]
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
            pbrPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            logger.info("Failed to create PBR pipeline state: \(error)")
        }
    }

    private func setupPBRIBLPipeline(library: MTLLibrary) {
        guard let vertexFn = library.makeFunction(name: "pbr_vertex_main"),
              let fragmentFn = library.makeFunction(name: "pbr_ibl_fragment_main") else {
            logger.info("PBR+IBL shader functions not found in library")
            return
        }

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

        let layout = vertexDescriptor.layouts[0]
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
            pbrIBLPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            logger.info("Failed to create PBR+IBL pipeline state: \(error)")
        }
    }

    private func setupIBLPipeline(library: MTLLibrary) {
        guard let vertexFn = library.makeFunction(name: "ibl_vertex_main"),
              let fragmentFn = library.makeFunction(name: "ibl_fragment_main") else {
            logger.info("IBL shader functions not found in library")
            return
        }

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

        let layout = vertexDescriptor.layouts[0]
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
            iblPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            logger.info("Failed to create IBL pipeline state: \(error)")
        }

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.rAddressMode = .clampToEdge
        iblSamplerState = device.makeSamplerState(descriptor: samplerDescriptor)
    }

    private func setupComputePipelines() {
        guard let library = device.makeDefaultLibrary() else { return }
        let computeNames = [
            ("equirect_to_cubemap", &equirectToCubemapPS),
            ("irradiance_convolution", &irradianceConvolutionPS),
            ("prefilter_convolution", &prefilterConvolutionPS),
            ("brdf_lut", &brdfLUTPS)
        ]
        for (name, statePtr) in computeNames {
            if let fn = library.makeFunction(name: name) {
                do {
                    statePtr.pointee = try device.makeComputePipelineState(function: fn)
                } catch {
                    logger.info("Failed to create compute pipeline \(name): \(error)")
                }
            }
        }
    }

    func loadEnvironmentMap(from url: URL) async throws -> (irradiance: MTLTexture, prefilter: MTLTexture, brdfLUT: MTLTexture) {
        if equirectToCubemapPS == nil { setupComputePipelines() }

        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue as NSNumber,
            .textureStorageMode: MTLStorageMode.private.rawValue as NSNumber,
            .SRGB: false
        ]
        let hdrTexture = try await loader.newTexture(URL: url, options: options)

        let cubemapSize = 512
        let cubemapDesc = MTLTextureDescriptor.textureCubeDescriptor(
            pixelFormat: .rgba16Float, size: cubemapSize, mipmapped: false
        )
        cubemapDesc.usage = [.shaderRead, .shaderWrite]
        cubemapDesc.storageMode = .private
        guard let envCubemap = device.makeTexture(descriptor: cubemapDesc) else {
            throw NSError(domain: "IBL", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create cubemap"])
        }

        try await runEquirectToCubemap(source: hdrTexture, destination: envCubemap)

        let irradianceSize = 32
        let irradianceDesc = MTLTextureDescriptor.textureCubeDescriptor(
            pixelFormat: .rgba16Float, size: irradianceSize, mipmapped: false
        )
        irradianceDesc.usage = [.shaderRead, .shaderWrite]
        irradianceDesc.storageMode = .private
        guard let irradianceTex = device.makeTexture(descriptor: irradianceDesc) else {
            throw NSError(domain: "IBL", code: 2)
        }

        try await runIrradianceConvolution(source: envCubemap, destination: irradianceTex)

        let prefilterSize = 128
        let prefilterMipLevels = 5
        let prefilterDesc = MTLTextureDescriptor.textureCubeDescriptor(
            pixelFormat: .rgba16Float, size: prefilterSize, mipmapped: true
        )
        prefilterDesc.mipmapLevelCount = prefilterMipLevels
        prefilterDesc.usage = [.shaderRead, .shaderWrite]
        prefilterDesc.storageMode = .private
        guard let prefilterTex = device.makeTexture(descriptor: prefilterDesc) else {
            throw NSError(domain: "IBL", code: 3)
        }

        try await runPrefilterConvolution(source: envCubemap, destination: prefilterTex, mipLevels: prefilterMipLevels)

        let lutSize = 512
        let lutDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rg16Float, width: lutSize, height: lutSize, mipmapped: false
        )
        lutDesc.usage = [.shaderRead, .shaderWrite]
        lutDesc.storageMode = .private
        guard let lutTex = device.makeTexture(descriptor: lutDesc) else {
            throw NSError(domain: "IBL", code: 4)
        }

        try await runBRDFLUT(destination: lutTex)

        self.irradianceMap = irradianceTex
        self.prefilterMap = prefilterTex
        self.brdfLUT = lutTex

        return (irradianceTex, prefilterTex, lutTex)
    }

    func loadHDRI(url: URL) async throws {
        guard let pipeline = iblComputePipeline else {
            throw NSError(domain: "IBLPipeline", code: 1, userInfo: [NSLocalizedDescriptionKey: "IBLPipeline not initialized"])
        }

        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue as NSNumber,
            .textureStorageMode: MTLStorageMode.private.rawValue as NSNumber,
            .SRGB: false
        ]
        let hdriTexture = try await loader.newTexture(URL: url, options: options)

        guard let result = pipeline.generate(from: hdriTexture) else {
            throw NSError(domain: "IBLPipeline", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to generate IBL textures"])
        }

        self.irradianceMap = result.irradiance
        self.prefilterMap = result.prefilter
        self.brdfLUT = result.brdfLUT
    }

    private func runEquirectToCubemap(source: MTLTexture, destination: MTLTexture) async throws {
        guard let ps = equirectToCubemapPS,
              let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(ps)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        let size = destination.width
        let threadsPerGrid = MTLSize(width: 6, height: size, depth: size)
        let threadsPerGroup = MTLSize(width: 1, height: min(ps.maxTotalThreadsPerThreadgroup / size, size), depth: 1)
        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
    }

    private func runIrradianceConvolution(source: MTLTexture, destination: MTLTexture) async throws {
        guard let ps = irradianceConvolutionPS,
              let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(ps)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        let size = destination.width
        let threadsPerGrid = MTLSize(width: 6, height: size, depth: size)
        let threadsPerGroup = MTLSize(width: 1, height: min(ps.maxTotalThreadsPerThreadgroup / size, size), depth: 1)
        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
    }

    private func runPrefilterConvolution(source: MTLTexture, destination: MTLTexture, mipLevels: Int) async throws {
        guard let ps = prefilterConvolutionPS,
              let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(ps)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)

        for mip in 0..<mipLevels {
            let roughness = Float(mip) / Float(mipLevels - 1)
            var r = roughness
            encoder.setBytes(&r, length: MemoryLayout<Float>.size, index: 0)
            let mipSize = max(destination.width >> mip, 1)
            let threadsPerGrid = MTLSize(width: 6, height: mipSize, depth: mipSize)
            let threadHeight = min(ps.maxTotalThreadsPerThreadgroup / mipSize, mipSize)
            let tg = MTLSizeMake(1, threadHeight, 1)
            encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: tg)
        }

        encoder.endEncoding()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
    }

    private func runBRDFLUT(destination: MTLTexture) async throws {
        guard let ps = brdfLUTPS,
              let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(ps)
        encoder.setTexture(destination, index: 0)
        let size = destination.width
        let threadsPerGrid = MTLSize(width: size, height: size, depth: 1)
        let w = min(ps.maxTotalThreadsPerThreadgroup, size)
        let threadsPerGroup = MTLSize(width: w, height: w, depth: 1)
        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
    }

    func updateScene(_ scene3D: Scene3D) {
        let structureChanged = scene3D.models.count != sceneObjectCount
        self.scene3D = scene3D
        if structureChanged {
            rebuildSceneFrom(scene3D)
        }
    }

    private func rebuildSceneFrom(_ scene3D: Scene3D) {
        rebuildCount += 1
        let savedCursor = cursorObject
        scene = Object()
        sceneObjectCount = scene3D.models.count
        pbrRenderables.removeAll()
        modelIdToObject.removeAll()

        for model in scene3D.models {
            if model.usesPBR {
                let vb: MTLBuffer
                let ib: MTLBuffer
                let ic: Int

                if let existingVB = model.vertexBuffer, let existingIB = model.indexBuffer,
                   model.vertexCount > 0, model.indexCount > 0 {
                    vb = existingVB
                    ib = existingIB
                    ic = model.indexCount
                } else {
                    let (vertexBuffer, indexBuffer, indexCount) = createBuffersFromMeshes(model.meshes)
                    guard let vBuf = vertexBuffer, let iBuf = indexBuffer, indexCount > 0 else { continue }
                    vb = vBuf
                    ib = iBuf
                    ic = indexCount
                }

                let pbrMat = GPUPBRMaterial(
                    albedoR: model.pbrMaterial.albedo.x,
                    albedoG: model.pbrMaterial.albedo.y,
                    albedoB: model.pbrMaterial.albedo.z,
                    metallic: model.pbrMaterial.metallic,
                    roughness: model.pbrMaterial.roughness,
                    ao: model.pbrMaterial.ao,
                    emissionR: model.pbrMaterial.emission.x,
                    emissionG: model.pbrMaterial.emission.y,
                    emissionB: model.pbrMaterial.emission.z,
                    emissionIntensity: model.pbrMaterial.emissionIntensity
                )
                pbrRenderables.append(PBRRenderable(
                    vertexBuffer: vb,
                    indexBuffer: ib,
                    indexCount: ic,
                    pbrMaterial: pbrMat,
                    model: model
                ))
            } else {
                let object = buildObject(from: model)
                scene.add(object)
                modelIdToObject[model.id.uuidString] = object
            }
        }
        // Re-add cursor object if it exists (scene was replaced)
        if let co = savedCursor {
            cursorObject = co
            scene.add(co)
        }
    }

    private func createBuffersFromMeshes(_ meshes: [Mesh]) -> (MTLBuffer?, MTLBuffer?, Int) {
        var vertices: [Float] = []
        var indices: [UInt32] = []
        for mesh in meshes {
            let baseIndex = UInt32(vertices.count / 9)
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
                indices.append(baseIndex + UInt32(idx))
            }
        }
        if vertices.isEmpty { return (nil, nil, 0) }
        let vb = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.stride, options: .storageModeShared)
        let ib = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt32>.stride, options: .storageModeShared)
        return (vb, ib, indices.count)
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
            let materialColor = model.usesPBR ? model.pbrMaterial.colorPreview : model.color
            let material = BasicMaterial(color: materialColor)
            let object = Object(geometry: geometry, material: material)
            object.position = model.position
            return object
        }
        var vertices: [Float] = []
        var indices: [UInt32] = []
        for mesh in model.meshes {
            let baseIndex = UInt32(vertices.count / 9)
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
                indices.append(baseIndex + UInt32(idx))
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
        let materialColor = model.usesPBR ? model.pbrMaterial.colorPreview : model.color
        let material = BasicMaterial(color: materialColor)
        let object = Object(geometry: geometry, material: material)
        object.position = model.position
        return object
    }

    /// Rebuilds a non-PBR Satin Object's geometry buffers in-place from the model's current meshes.
    /// Used by the sculpt path to update non-PBR models without a full scene rebuild.
    /// Risk: Satin Geometry properties (vertexBuffer, indexBuffer, vertexCount, indexCount)
    /// may be computed/private in some Satin versions. The CI build passes with the same
    /// property-assignment pattern used by buildObject(). If this path fails at runtime,
    /// the safe fallback is a single rebuildSceneFrom() at stroke end (see BRAIN.md Risks).
    private func refreshNonPBRObjectGeometry(for model: Model) {
        guard let object = modelIdToObject[model.id.uuidString] else { return }
        let (vb, ib, ic) = createBuffersFromMeshes(model.meshes)
        guard let vBuf = vb, let iBuf = ib, ic > 0 else { return }

        // Rebuild interleaved vertex data to compute vertexCount
        var totalFloats = 0
        for mesh in model.meshes {
            totalFloats += mesh.vertices.count * 9
        }
        let vertexCount = totalFloats > 0 ? totalFloats / 9 : 0
        guard vertexCount > 0 else { return }

        // Update the existing Satin Object's geometry in-place
        // (same property-assignment pattern as buildObject)
        object.geometry.vertexBuffer = vBuf
        object.geometry.indexBuffer = iBuf
        object.geometry.vertexCount = vertexCount
        object.geometry.indexCount = ic
    }

    func update() {
        updateAnimation()
    }

    private func makeLightUniforms(from lighting: Scene3D.Lighting) -> GPULightUniforms {
        let dl = lighting.directionalLight
        var lights = GPULightUniforms(
            ambientR: lighting.ambientColor.x,
            ambientG: lighting.ambientColor.y,
            ambientB: lighting.ambientColor.z,
            pointLightCount: UInt32(min(lighting.pointLights.count, 4)),
            directionalLight: GPUDirectionalLight(
                dirX: dl.direction.x, dirY: dl.direction.y, dirZ: dl.direction.z,
                colR: dl.color.x, colG: dl.color.y, colB: dl.color.z,
                intensity: dl.intensity
            ),
            pointLights: (
                GPUPointLight(posX: 0, posY: 0, posZ: 0, colR: 0, colG: 0, colB: 0, intensity: 0, range: 0),
                GPUPointLight(posX: 0, posY: 0, posZ: 0, colR: 0, colG: 0, colB: 0, intensity: 0, range: 0),
                GPUPointLight(posX: 0, posY: 0, posZ: 0, colR: 0, colG: 0, colB: 0, intensity: 0, range: 0),
                GPUPointLight(posX: 0, posY: 0, posZ: 0, colR: 0, colG: 0, colB: 0, intensity: 0, range: 0)
            )
        )

        for i in 0..<min(lighting.pointLights.count, 4) {
            let pl = lighting.pointLights[i]
            let gpl = GPUPointLight(
                posX: pl.position.x, posY: pl.position.y, posZ: pl.position.z,
                colR: pl.color.x, colG: pl.color.y, colB: pl.color.z,
                intensity: pl.intensity,
                range: pl.range
            )
            switch i {
            case 0: lights.pointLights.0 = gpl
            case 1: lights.pointLights.1 = gpl
            case 2: lights.pointLights.2 = gpl
            case 3: lights.pointLights.3 = gpl
            default: break
            }
        }

        return lights
    }

    func render(in view: MTKView) {
        if let se = sculptEngine, var scene = self.scene3D {
            var modifiedModelIndices = Set<Int>()
            for i in 0..<scene.models.count {
                for j in 0..<scene.models[i].meshes.count {
                    if se.applySculpt(to: &scene.models[i].meshes[j]) {
                        modifiedModelIndices.insert(i)
                    }
                }
            }
            if !modifiedModelIndices.isEmpty {
                self.scene3D = scene
                // Update GPU buffers in-place for modified PBR models (no full scene rebuild)
                for i in modifiedModelIndices where scene.models[i].usesPBR {
                    let (vb, ib, ic) = createBuffersFromMeshes(scene.models[i].meshes)
                    guard let vBuf = vb, let iBuf = ib, ic > 0 else { continue }
                    if let pbrIndex = pbrRenderables.firstIndex(where: { $0.model.id == scene.models[i].id }) {
                        pbrRenderables[pbrIndex].vertexBuffer = vBuf
                        pbrRenderables[pbrIndex].indexBuffer = iBuf
                        pbrRenderables[pbrIndex].indexCount = ic
                    }
                }
                // Non-PBR models: rebuild Satin Object geometry in-place
                for i in modifiedModelIndices where !scene.models[i].usesPBR {
                    refreshNonPBRObjectGeometry(for: scene.models[i])
                }
            }
        }

        // ---- Brush cursor state ----
        if let cursorPos = brushCursorPosition {
            setupCursorObject()
            if let co = cursorObject {
                co.visible = true
                co.position = cursorPos
                let r = brushCursorRadius
                co.scale = SIMD3<Float>(r / 0.04, r / 0.04, r / 0.04)  // normalize to base radius
            }
        } else {
            cursorObject?.visible = false
        }

        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        encoder.setDepthStencilState(depthState)

        // ---- Basic pipeline pass ----
        if let basicPS = basicPipelineState {
            encoder.setRenderPipelineState(basicPS)

            var basicUniforms = BasicUniforms(
                modelMatrix: matrix_identity_float4x4,
                viewMatrix: camera.viewMatrix,
                projectionMatrix: camera.projectionMatrix,
                ambientColor: SIMD3<Float>(0.18, 0.18, 0.18),
                lightDirection: scene3D?.lighting.directionalLight.direction ?? simd_normalize(SIMD3<Float>(0.0, -1.0, -1.0)),
                lightColor: scene3D?.lighting.directionalLight.color ?? SIMD3<Float>(1.0, 1.0, 1.0),
                lightIntensity: scene3D?.lighting.directionalLight.intensity ?? 0.8,
                normalMatrix: matrix_identity_float3x3
            )

            encoder.setVertexBytes(&basicUniforms, length: MemoryLayout<BasicUniforms>.stride, index: 1)
            encoder.setFragmentBytes(&basicUniforms, length: MemoryLayout<BasicUniforms>.stride, index: 1)

            scene.draw(encoder: encoder)
        }

        // ---- PBR pipeline pass ----
        let hasIBLTextures = irradianceMap != nil && prefilterMap != nil && brdfLUT != nil
        let useCombinedIBL = hasIBLTextures && pbrIBLPipelineState != nil
        let useSeparateIBL = hasIBLTextures && iblPipelineState != nil && !useCombinedIBL
        let activePBRPS = useCombinedIBL ? pbrIBLPipelineState :
                          (useSeparateIBL ? iblPipelineState : pbrPipelineState)
        if let pbrPS = activePBRPS, !pbrRenderables.isEmpty {
            encoder.setRenderPipelineState(pbrPS)

            let lighting = scene3D?.lighting ?? .default
            var lightUniforms = makeLightUniforms(from: lighting)
            let viewMatrix = camera.viewMatrix
            let projectionMatrix = camera.projectionMatrix
            let cameraPos = camera.position
            let cameraPos4 = SIMD4<Float>(cameraPos.x, cameraPos.y, cameraPos.z, 0)

            var iblUniforms = IBLUniforms(
                inverseView: viewMatrix.inverse,
                roughnessLevels: 4.0
            )

            if useCombinedIBL || useSeparateIBL {
                encoder.setFragmentBytes(&iblUniforms, length: MemoryLayout<IBLUniforms>.stride, index: 4)
                encoder.setFragmentTexture(irradianceMap, index: 0)
                encoder.setFragmentTexture(prefilterMap, index: 1)
                encoder.setFragmentTexture(brdfLUT, index: 2)
                if let sampler = iblSamplerState {
                    encoder.setFragmentSamplerState(sampler, index: 0)
                }
            } else if hasIBLTextures {
                encoder.setFragmentBytes(&iblUniforms, length: MemoryLayout<IBLUniforms>.stride, index: 4)
                encoder.setFragmentTexture(irradianceMap, index: 6)
                encoder.setFragmentTexture(prefilterMap, index: 7)
                encoder.setFragmentTexture(brdfLUT, index: 8)
                if let sampler = iblSamplerState {
                    encoder.setFragmentSamplerState(sampler, index: 1)
                }
            }

            for pbrObj in pbrRenderables {
                let modelMatrix = pbrObj.model.transform
                let model3x3 = simd_float3x3(
                    SIMD3<Float>(modelMatrix.columns.0.x, modelMatrix.columns.0.y, modelMatrix.columns.0.z),
                    SIMD3<Float>(modelMatrix.columns.1.x, modelMatrix.columns.1.y, modelMatrix.columns.1.z),
                    SIMD3<Float>(modelMatrix.columns.2.x, modelMatrix.columns.2.y, modelMatrix.columns.2.z)
                )
                let normalMatrix = model3x3.inverse.transpose
                var frameUniforms = FrameUniforms(
                    modelMatrix: modelMatrix,
                    viewMatrix: viewMatrix,
                    projectionMatrix: projectionMatrix,
                    cameraPosition: cameraPos4,
                    normalMatrix: normalMatrix
                )
                var materialUniforms = pbrObj.pbrMaterial

                encoder.setVertexBytes(&frameUniforms, length: MemoryLayout<FrameUniforms>.stride, index: 1)
                encoder.setVertexBuffer(pbrObj.vertexBuffer, offset: 0, index: 0)
                encoder.setFragmentBytes(&frameUniforms, length: MemoryLayout<FrameUniforms>.stride, index: 1)
                encoder.setFragmentBytes(&materialUniforms, length: MemoryLayout<GPUPBRMaterial>.stride, index: 2)
                encoder.setFragmentBytes(&lightUniforms, length: MemoryLayout<GPULightUniforms>.stride, index: 3)

                encoder.setFrontFacing(.counterClockwise)
                encoder.setCullMode(.back)

                encoder.drawIndexedPrimitives(
                    type: .triangle,
                    indexCount: pbrObj.indexCount,
                    indexType: .uint32,
                    indexBuffer: pbrObj.indexBuffer,
                    indexBufferOffset: 0
                )
            }
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func draw() {
        guard let view = mtkView else { return }
        render(in: view)
    }
}
