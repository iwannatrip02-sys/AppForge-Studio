import Metal

class IBLPipeline {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let irradiancePS: MTLComputePipelineState
    private let prefilterPS: MTLComputePipelineState
    private let brdfPS: MTLComputePipelineState

    init?(device: MTLDevice, library: MTLLibrary) {
        guard let queue = device.makeCommandQueue() else { return nil }
        guard let irradianceFn = library.makeFunction(name: "irradiance_map"),
              let prefilterFn = library.makeFunction(name: "prefilter_envmap"),
              let brdfFn = library.makeFunction(name: "brdf_integration") else { return nil }

        do {
            irradiancePS = try device.makeComputePipelineState(function: irradianceFn)
            prefilterPS = try device.makeComputePipelineState(function: prefilterFn)
            brdfPS = try device.makeComputePipelineState(function: brdfFn)
        } catch {
            return nil
        }

        self.device = device
        self.commandQueue = queue
    }

    func generate(from hdriTexture: MTLTexture) -> (irradiance: MTLTexture, prefilter: MTLTexture, brdfLUT: MTLTexture)? {
        let irradianceSize = 32
        let irradianceDesc = MTLTextureDescriptor.textureCubeDescriptor(
            pixelFormat: .rgba16Float, size: irradianceSize, mipmapped: false
        )
        irradianceDesc.usage = [.shaderRead, .shaderWrite]
        irradianceDesc.storageMode = .private
        guard let irradianceTex = device.makeTexture(descriptor: irradianceDesc) else { return nil }

        let prefilterSize = 128
        let prefilterMipLevels = 5
        let prefilterDesc = MTLTextureDescriptor.textureCubeDescriptor(
            pixelFormat: .rgba16Float, size: prefilterSize, mipmapped: true
        )
        prefilterDesc.mipmapLevelCount = prefilterMipLevels
        prefilterDesc.usage = [.shaderRead, .shaderWrite]
        prefilterDesc.storageMode = .private
        guard let prefilterTex = device.makeTexture(descriptor: prefilterDesc) else { return nil }

        let lutSize = 256
        let lutDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rg16Float, width: lutSize, height: lutSize, mipmapped: false
        )
        lutDesc.usage = [.shaderRead, .shaderWrite]
        lutDesc.storageMode = .private
        guard let lutTex = device.makeTexture(descriptor: lutDesc) else { return nil }

        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf.makeComputeCommandEncoder() else { return nil }

        encoder.setComputePipelineState(irradiancePS)
        encoder.setTexture(hdriTexture, index: 0)
        encoder.setTexture(irradianceTex, index: 1)
        let irradianceGrid = MTLSize(width: 6, height: irradianceSize, depth: irradianceSize)
        let irradianceTG = MTLSize(width: 1, height: 8, depth: 8)
        encoder.dispatchThreads(irradianceGrid, threadsPerThreadgroup: irradianceTG)
        encoder.endEncoding()

        for mip in 0..<prefilterMipLevels {
            let mipSize = max(prefilterSize >> mip, 1)
            let roughness = Float(mip) / Float(prefilterMipLevels - 1)
            var r = roughness
            guard let mipView = prefilterTex.makeTextureView(
                pixelFormat: .rgba16Float,
                textureType: .typeCube,
                levels: mip..<mip + 1,
                slices: 0..<6
            ) else { continue }

            guard let mipEncoder = cmdBuf.makeComputeCommandEncoder() else { continue }
            mipEncoder.setComputePipelineState(prefilterPS)
            mipEncoder.setTexture(hdriTexture, index: 0)
            mipEncoder.setTexture(mipView, index: 1)
            mipEncoder.setBytes(&r, length: MemoryLayout<Float>.size, index: 0)
            let prefilterGrid = MTLSize(width: 6, height: mipSize, depth: mipSize)
            let prefilterTG = MTLSize(width: 1, height: 16, depth: 16)
            mipEncoder.dispatchThreads(prefilterGrid, threadsPerThreadgroup: prefilterTG)
            mipEncoder.endEncoding()
        }

        guard let brdfEncoder = cmdBuf.makeComputeCommandEncoder() else { return nil }
        brdfEncoder.setComputePipelineState(brdfPS)
        brdfEncoder.setTexture(lutTex, index: 0)
        let lutGrid = MTLSize(width: lutSize, height: lutSize, depth: 1)
        let lutTG = MTLSize(width: 16, height: 16, depth: 1)
        brdfEncoder.dispatchThreads(lutGrid, threadsPerThreadgroup: lutTG)
        brdfEncoder.endEncoding()

        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        return (irradianceTex, prefilterTex, lutTex)
    }
}
