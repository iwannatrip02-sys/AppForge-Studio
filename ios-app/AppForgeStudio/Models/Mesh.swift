import Foundation
import simd
import Metal

struct Vertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var uv: SIMD2<Float>
    
    init(position: SIMD3<Float> = .zero, normal: SIMD3<Float> = .zero, uv: SIMD2<Float> = .zero) {
        self.position = position
        self.normal = normal
        self.uv = uv
    }
}

struct Mesh {
    var vertices: [Vertex]
    var indices: [UInt32]
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    
    init(vertices: [Vertex] = [], indices: [UInt32] = []) {
        self.vertices = vertices
        self.indices = indices
        self.vertexBuffer = nil
        self.indexBuffer = nil
    }
    
    mutating func uploadToGPU(device: MTLDevice) {
        guard !vertices.isEmpty else { return }
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: .storageModeShared)
        if !indices.isEmpty {
            indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt32>.stride * indices.count, options: .storageModeShared)
        }
    }
}
