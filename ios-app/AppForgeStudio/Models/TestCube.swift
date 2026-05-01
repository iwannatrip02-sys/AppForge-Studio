import Foundation
import simd

struct TestCube {
    static func build(name: String = "TestCube") -> Model {
        let s: Float = 1.0
        let verts: [Vertex] = [
            Vertex(position: SIMD3(-s,-s,-s), normal: SIMD3( 0, 0,-1), uv: SIMD2(0,0)),
            Vertex(position: SIMD3( s,-s,-s), normal: SIMD3( 0, 0,-1), uv: SIMD2(1,0)),
            Vertex(position: SIMD3( s, s,-s), normal: SIMD3( 0, 0,-1), uv: SIMD2(1,1)),
            Vertex(position: SIMD3(-s, s,-s), normal: SIMD3( 0, 0,-1), uv: SIMD2(0,1)),
            Vertex(position: SIMD3(-s,-s, s), normal: SIMD3( 0, 0, 1), uv: SIMD2(0,0)),
            Vertex(position: SIMD3( s,-s, s), normal: SIMD3( 0, 0, 1), uv: SIMD2(1,0)),
            Vertex(position: SIMD3( s, s, s), normal: SIMD3( 0, 0, 1), uv: SIMD2(1,1)),
            Vertex(position: SIMD3(-s, s, s), normal: SIMD3( 0, 0, 1), uv: SIMD2(0,1)),
        ]
        let idxs: [UInt32] = [
            0,1,2, 0,2,3, 1,5,6, 1,6,2,
            5,4,7, 5,7,6, 4,0,3, 4,3,7,
            3,2,6, 3,6,7, 4,5,1, 4,1,0
        ]
        let mesh = Mesh(vertices: verts, indices: idxs)
        let model = Model(name: name)
        model.meshes = [mesh]
        model.color = SIMD4(0.8, 0.8, 0.8, 1.0)
        return model
    }
}
