import Foundation
import Metal
import Satin
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "SatinMesh")
class SatinMesh: Mesh {
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var vertexCount: Int = 0
    var indexCount: Int = 0
    var meshColor: simd_float4 = simd_float4(0.5, 0.5, 0.5, 1.0)

    init(device: MTLDevice, vertices: [Float] = [], indices: [UInt16] = [], color: simd_float4 = simd_float4(0.5, 0.5, 0.5, 1.0)) {
        let geometry = Geometry()
        let vertexData = !vertices.isEmpty ? vertices : [0,0,0, 0,0,1, 1,0,0, 1,0,1]
        let indexData = !indices.isEmpty ? indices : [0,1,2, 2,1,3]
        if let buffer = device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: []) {
            let attr = VertexBufferAttribute(buffer: buffer, format: MTLVertexFormat.float3, offset: 0, stride: MemoryLayout<SIMD3<Float>>.stride)
            geometry.vertexAttributes[VertexAttribute.Position] = attr
        }
        if !indexData.isEmpty, let idxBuffer = device.makeBuffer(bytes: indexData, length: indexData.count * MemoryLayout<UInt16>.size, options: []) {
            geometry.elementBuffer = ElementBuffer(buffer: idxBuffer, type: MTLIndexType.uint16, count: indexData.count)
        }
        let material = BasicColorMaterial(color: color)
        super.init(geometry: geometry, material: material)
        self.meshColor = color
        if !vertices.isEmpty {
            vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])
            vertexCount = vertices.count / 13
            if !indices.isEmpty {
                indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size, options: [])
                indexCount = indices.count
            }
        }
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    func updateColor(_ color: simd_float4) {
        meshColor = color
        material?.set("ModelColor", color)
    }
}
