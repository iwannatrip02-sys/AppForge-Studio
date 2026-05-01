import Foundation
import Metal
import Satin
import simd

class SatinMesh: Object {
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var vertexCount: Int = 0
    var indexCount: Int = 0
    var meshColor: simd_float4 = simd_float4(0.5, 0.5, 0.5, 1.0)
    
    init(device: MTLDevice, vertices: [Float] = [], indices: [UInt16] = [], color: simd_float4 = simd_float4(0.5, 0.5, 0.5, 1.0)) {
        let data = GeometryData(
            vertices: !vertices.isEmpty ? vertices : [0,0,0, 0,0,1, 1,0,0, 1,0,1],
            normals: [],
            uvs: [],
            indices: !indices.isEmpty ? indices : [0,1,2, 2,1,3]
        )
        let geometry = Geometry(data: data)
        let material = BasicMaterial(color: color)
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
    
    func updateColor(_ color: simd_float4) {
        meshColor = color
        material?.set("ModelColor", color)
    }
}
