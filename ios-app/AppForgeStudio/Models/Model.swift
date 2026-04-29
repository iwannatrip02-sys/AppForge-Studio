import Foundation
import simd

struct Model {
    var name: String
    var meshes: [Mesh]
    var transform: simd_float4x4
    
    init(name: String, meshes: [Mesh], transform: simd_float4x4 = matrix_identity_float4x4) {
        self.name = name
        self.meshes = meshes
        self.transform = transform
    }
}
