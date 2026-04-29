import Foundation
import simd

struct Model {
    let id: UUID
    var name: String
    var meshes: [Mesh]
    var transform: simd_float4x4
    var color: SIMD4<Float>
    var cadHistoryID: UUID?
    var originOp: String?
    
    init(name: String, meshes: [Mesh], transform: simd_float4x4 = matrix_identity_float4x4,
         id: UUID = UUID(), color: SIMD4<Float> = SIMD4<Float>(0.7, 0.7, 0.7, 1.0),
         cadHistoryID: UUID? = nil, originOp: String? = nil) {
        self.id = id
        self.name = name
        self.meshes = meshes
        self.transform = transform
        self.color = color
        self.cadHistoryID = cadHistoryID
        self.originOp = originOp
    }
}
