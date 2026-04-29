import Foundation
import Metal
import MetalKit

class PaintRenderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?
    var computePipelineState: MTLComputePipelineState?
    var paintTexture: MTLTexture?
    var depthState: MTLDepthStencilState?
    
    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        setupPipelines()
        setupDepthState()
        createPaintTexture(width: 2048, height: 2048)
    }
    
    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to create Metal library")
        }
        
        // Vertex pipeline
        let vertexFn = library.makeFunction(name: "vertex_main")
        let fragmentFn = library.makeFunction(name: "fragment_main")
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFn
        descriptor.fragmentFunction = fragmentFn
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float
        
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
        descriptor.vertexDescriptor = vertexDescriptor
        
        pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor)
        
        // Compute pipeline for painting
        if let paintKernel = library.makeFunction(name: "paint_kernel") {
            computePipelineState = try? device.makeComputePipelineState(function: paintKernel)
        }
    }
    
    private func setupDepthState() {
        let desc = MTLDepthStencilDescriptor()
        desc.depthCompareFunction = .less
        desc.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: desc)
    }
    
    private func createPaintTexture(width: Int, height: Int) {
        let desc = MTLTextureDescriptor()
        desc.pixelFormat = .rgba8Unorm
        desc.width = width
        desc.height = height
        desc.usage = [.shaderRead, .shaderWrite, .renderTarget]
        paintTexture = device.makeTexture(descriptor: desc)
    }
    
    func render(mesh: Mesh, uniforms: Uniforms, in view: MTKView, commandBuffer: MTLCommandBuffer) {
        guard let pipelineState = pipelineState,
              let descriptor = view.currentRenderPassDescriptor,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState)
        
        var uniforms = uniforms
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        
        var fragUniforms = FragmentUniforms(
            ambientColor: float3(0.2, 0.2, 0.2),
            lightDirection: float3(0, -1, -1),
            lightColor: float3(1, 1, 1),
            lightIntensity: 0.8,
            paintColor: float4(1, 1, 1, 1),
            hasTexture: paintTexture != nil
        )
        encoder.setFragmentBytes(&fragUniforms, length: MemoryLayout<FragmentUniforms>.stride, index: 0)
        
        if let paintTexture = paintTexture {
            encoder.setFragmentTexture(paintTexture, index: 0)
        }
        let sampler = MTLSamplerDescriptor()
        let samplerState = device.makeSamplerState(descriptor: sampler)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        
        if let vertexBuffer = mesh.vertexBuffer, let indexBuffer = mesh.indexBuffer {
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: mesh.indices.count,
                                          indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0)
        }
        
        encoder.endEncoding()
    }
    
    func paintStroke(at uv: float2, color: float4, radius: Float, hardness: Float, commandBuffer: MTLCommandBuffer) {
        guard let computePipelineState = computePipelineState,
              let paintTexture = paintTexture else { return }
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(computePipelineState)
        encoder.setTexture(paintTexture, index: 0)
        
        var uv = uv
        var color = color
        var radius = radius
        var hardness = hardness
        
        encoder.setBytes(&uv, length: MemoryLayout<float2>.stride, index: 0)
        encoder.setBytes(&color, length: MemoryLayout<float4>.stride, index: 1)
        encoder.setBytes(&radius, length: MemoryLayout<Float>.stride, index: 2)
        encoder.setBytes(&hardness, length: MemoryLayout<Float>.stride, index: 3)
        
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let gridSize = MTLSize(width: paintTexture.width, height: paintTexture.height, depth: 1)
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
    }
}

struct Uniforms {
    var modelMatrix: float4x4
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
    var cameraPosition: float3
}

struct FragmentUniforms {
    var ambientColor: float3
    var lightDirection: float3
    var lightColor: float3
    var lightIntensity: Float
    var paintColor: float4
    var hasTexture: Bool
}
