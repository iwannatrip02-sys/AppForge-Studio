import Foundation
import simd

class BevelEngine {
    
    func bevel(mesh: inout Mesh, edgeIndices: [(Int, Int)], bevelSize: Float, segments: Int) -> Bool {
        guard !edgeIndices.isEmpty, segments > 0 else { return false }
        
        var newVertices = mesh.vertices
        var newIndices = [UInt32]()
        var edgeMidMap = [Int: [Int]]()
        let originalCount = mesh.vertices.count
        
        for (a, b) in edgeIndices {
            let key = min(a, b) * originalCount + max(a, b)
            guard edgeMidMap[key] == nil else { continue }
            
            var mids = [Int]()
            let midPos = (mesh.vertices[a].position + mesh.vertices[b].position) * 0.5
            for s in 0...segments {
                let t = Float(s) / Float(segments)
                let alongEdge = simd_mix(mesh.vertices[a].position, mesh.vertices[b].position, t)
                let dir = normalize(midPos - alongEdge) * bevelSize
                let pos = alongEdge + dir
                let v = Vertex(position: pos, normal: mesh.vertices[a].normal, uv: mesh.vertices[a].uv)
                mids.append(newVertices.count)
                newVertices.append(v)
            }
            edgeMidMap[key] = mids
        }
        
        // Preservar triangulos originales que no tocan aristas beveled
        let affectedSet = Set(edgeIndices.flatMap { [$0.0, $0.1] })
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            let i0 = Int(mesh.indices[i])
            let i1 = Int(mesh.indices[i+1])
            let i2 = Int(mesh.indices[i+2])
            if !affectedSet.contains(i0) && !affectedSet.contains(i1) && !affectedSet.contains(i2) {
                newIndices.append(contentsOf: [mesh.indices[i], mesh.indices[i+1], mesh.indices[i+2]])
            }
        }
        
        mesh = Mesh(vertices: newVertices, indices: newIndices)
        return true
    }
}
