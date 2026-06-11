import Metal
import simd
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "SceneRenderer")
struct SceneUniforms {
    var modelMatrix: simd_float4x4
    var viewMatrix: simd_float4x4
    var projectionMatrix: simd_float4x4
    var ambientColor: SIMD3<Float>
    var lightDirection: SIMD3<Float>
    var lightColor: SIMD3<Float>
    var lightIntensity: Float
}

class SceneRenderer {
    let device: MTLDevice
    let pipelineState: MTLRenderPipelineState?
    let depthState: MTLDepthStencilState?
    
    init(device: MTLDevice) {
        self.device = device
        
        guard let library = device.makeDefaultLibrary() else {
            logger.info("Warning: No Metal library found for SceneRenderer")
            self.pipelineState = nil
            self.depthState = nil
            return
        }
        
        guard let vertexFn = library.makeFunction(name: "vertex_main"),
              let fragmentFn = library.makeFunction(name: "fragment_main") else {
            logger.info("Warning: vertex_main/fragment_main not found in Metal library")
            self.pipelineState = nil
            self.depthState = nil
            return
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFn
        descriptor.fragmentFunction = fragmentFn
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.depthAttachmentPixelFormat = .depth32Float
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = MemoryLayout<SIMD4<Float>>.stride + MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.attributes[3].format = .float4
        vertexDescriptor.attributes[3].offset = MemoryLayout<SIMD4<Float>>.stride + MemoryLayout<SIMD3<Float>>.stride + MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.attributes[3].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD4<Float>>.stride + MemoryLayout<SIMD3<Float>>.stride + MemoryLayout<SIMD2<Float>>.stride + MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        descriptor.vertexDescriptor = vertexDescriptor
        
        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .less
        depthDesc.isDepthWriteEnabled = true
        self.depthState = device.makeDepthStencilState(descriptor: depthDesc)
        
        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            logger.info("Failed to create scene pipeline: \(error)")
            self.pipelineState = nil
        }
    }
    
    func render(scene: Scene3D, commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
        guard let pipelineState = pipelineState,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        encoder.setRenderPipelineState(pipelineState)
        if let depthState = depthState {
            encoder.setDepthStencilState(depthState)
        }
        
        let ambientColor = SIMD3<Float>(0.3, 0.3, 0.35)
        let lightDirection = simd_normalize(SIMD3<Float>(0.5, -1.0, 0.8))
        let lightColor = SIMD3<Float>(1.0, 0.98, 0.95)
        let lightIntensity: Float = 0.8
        
        for model in scene.models {
            guard let vertexBuffer = model.vertexBuffer,
                  let indexBuffer = model.indexBuffer else { continue }
            
            var uniforms = SceneUniforms(
                modelMatrix: model.transform,
                viewMatrix: scene.camera.viewMatrix,
                projectionMatrix: scene.camera.projectionMatrix,
                ambientColor: ambientColor,
                lightDirection: lightDirection,
                lightColor: lightColor,
                lightIntensity: lightIntensity
            )
            
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<SceneUniforms>.stride, index: 1)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: model.indexCount, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
        }
        
        encoder.endEncoding()
    }
}