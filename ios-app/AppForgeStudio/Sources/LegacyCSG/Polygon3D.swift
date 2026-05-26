import Foundation
import simd

struct Polygon3D {
    var vertices: [SIMD3<Float>]
    var normal: SIMD3<Float>
    var plane: (normal: SIMD3<Float>, d: Float)
    
    init(vertices: [SIMD3<Float>], normal: SIMD3<Float>) {
        self.vertices = vertices
        self.normal = normalize(normal)
        let d = -dot(self.normal, vertices[0])
        self.plane = (self.normal, d)
    }
    
    func triangulate(into vertices: inout [Mesh.Vertex], indices: inout [UInt32]) {
        guard self.vertices.count >= 3 else { return }
        let baseIndex = UInt32(vertices.count)
        for v in self.vertices {
            vertices.append(Mesh.Vertex(position: v, normal: self.normal, uv: .zero))
        }
        for i in 1..<self.vertices.count-1 {
            indices.append(baseIndex)
            indices.append(baseIndex + UInt32(i))
            indices.append(baseIndex + UInt32(i+1))
        }
    }
    
    static func fromMesh(_ mesh: Mesh) -> [Polygon3D] {
        var polygons: [Polygon3D] = []
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            let i0 = Int(mesh.indices[i])
            let i1 = Int(mesh.indices[i+1])
            let i2 = Int(mesh.indices[i+2])
            let v0 = mesh.vertices[i0].position
            let v1 = mesh.vertices[i1].position
            let v2 = mesh.vertices[i2].position
            let normal = normalize(cross(v1 - v0, v2 - v0))
            polygons.append(Polygon3D(vertices: [v0, v1, v2], normal: normal))
        }
        return polygons
    }
    
    static func toMesh(_ polygons: [Polygon3D]) -> Mesh {
        var verts: [Mesh.Vertex] = []
        var inds: [UInt32] = []
        for p in polygons {
            p.triangulate(into: &verts, indices: &inds)
        }
        return Mesh(vertices: verts, indices: inds)
    }
}
