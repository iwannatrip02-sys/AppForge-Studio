import Satin
import Foundation
import Metal
import simd

class Model3D {
    let id: UUID
    var name: String
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var vertexCount: Int
    var indexCount: Int
    var meshes: [Mesh] = []
    var transform: simd_float4x4
    var color: SIMD4<Float>
    var cadHistoryID: UUID?
    var originOp: String?
    
    init(name: String = "Model", vertices: [Float] = [], indices: [UInt16] = [], device: MTLDevice? = nil) {
        self.id = UUID()
        self.name = name
        self.vertexCount = vertices.count / 8
        self.indexCount = indices.count
        self.transform = matrix_identity_float4x4
        self.color = SIMD4<Float>(0.7, 0.7, 0.7, 1.0)
        
        if let device = device, !vertices.isEmpty {
            setBuffers(vertices: vertices, indices: indices, device: device)
        }
    }
    
    func setBuffers(vertices: [Float], indices: [UInt16], device: MTLDevice) {
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.stride, options: .storageModeShared)
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: .storageModeShared)
        vertexCount = vertices.count / 8
        indexCount = indices.count
    }
    
    func updateTransform(_ newTransform: simd_float4x4) {
        transform = newTransform
    }
}