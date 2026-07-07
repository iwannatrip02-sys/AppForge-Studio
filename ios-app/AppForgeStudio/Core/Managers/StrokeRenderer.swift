import Foundation
import Metal
import simd

class StrokeRenderer {
    let device: MTLDevice
    let pipelineState: MTLRenderPipelineState?
    let maxQuads: Int = 65536
    
    init(device: MTLDevice) {
        self.device = device
        
        guard let library = device.makeDefaultLibrary() else {
            print("Warning: No Metal library found. Stroke rendering disabled.")
            self.pipelineState = nil
            return
        }
        
        guard let vertexFn = library.makeFunction(name: "strokeVertex"),
              let fragmentFn = library.makeFunction(name: "strokeFragment") else {
            print("Warning: Stroke shaders not found in Metal library.")
            self.pipelineState = nil
            return
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFn
        descriptor.fragmentFunction = fragmentFn
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Failed to create stroke pipeline: \(error)")
            self.pipelineState = nil
        }
    }
    
    func render(strokes: [BrushStroke], commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor, viewMatrix: float4x4, projectionMatrix: float4x4) {
        guard let pipelineState = pipelineState, !strokes.isEmpty else { return }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        encoder.setRenderPipelineState(pipelineState)
        
        var mvp = projectionMatrix * viewMatrix
        encoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.stride, index: 1)
        
        var allVertices: [QuadVertex] = []
        allVertices.reserveCapacity(maxQuads * 4)
        
        for stroke in strokes {
            let pts = stroke.points
            guard pts.count >= 2 else { continue }
            for i in 0..<(pts.count - 1) {
                let p0 = pts[i]
                let p1 = pts[i + 1]
                let mid = (p0.position + p1.position) * 0.5
                let dir = simd_normalize(p1.position - p0.position)
                let up = SIMD3<Float>(0, 1, 0)
                let right = simd_normalize(simd_cross(dir, up))
                let localUp = simd_normalize(simd_cross(right, dir))
                let r = stroke.radius
                let h = stroke.hardness
                let c = stroke.color
                
                let v0 = QuadVertex(position: SIMD4<Float>(mid - right * r - localUp * r, 1), color: c, hardness: h)
                let v1 = QuadVertex(position: SIMD4<Float>(mid + right * r - localUp * r, 1), color: c, hardness: h)
                let v2 = QuadVertex(position: SIMD4<Float>(mid - right * r + localUp * r, 1), color: c, hardness: h)
                let v3 = QuadVertex(position: SIMD4<Float>(mid + right * r + localUp * r, 1), color: c, hardness: h)
                allVertices.append(contentsOf: [v0, v1, v2, v3])
            }
        }
        
        guard !allVertices.isEmpty else { encoder.endEncoding(); return }
        encoder.setVertexBytes(allVertices, length: MemoryLayout<QuadVertex>.stride * allVertices.count, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: allVertices.count)
        encoder.endEncoding()
    }
}

struct QuadVertex {
    var position: SIMD4<Float>
    var color: SIMD4<Float>
    var hardness: Float
}