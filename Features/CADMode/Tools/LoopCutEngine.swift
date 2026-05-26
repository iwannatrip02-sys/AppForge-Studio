import Foundation
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "LoopCutEngine")
class LoopCutEngine {
    
    func loopCut(mesh: inout Mesh, edgeLoop: [(Int, Int)]) -> Bool {
        guard !edgeLoop.isEmpty else { return false }
        
        var vertexMap = [Int: Int]()
        var newVertices = mesh.vertices
        let originalCount = mesh.vertices.count
        
        // Insertar vertice en la mitad de cada arista
        for (a, b) in edgeLoop {
            let key = min(a, b) * originalCount + max(a, b)
            guard vertexMap[key] == nil else { continue }
            let mid = (mesh.vertices[a].position + mesh.vertices[b].position) * 0.5
            let v = Vertex(position: mid, normal: mesh.vertices[a].normal, uv: (mesh.vertices[a].uv + mesh.vertices[b].uv) * 0.5)
            vertexMap[key] = newVertices.count
            newVertices.append(v)
        }
        
        // Reindexar caras (subdividir triangulos en 4)
        var newIndices = [UInt32]()
        for i in 0..<mesh.indices.count / 3 {
            let i0 = Int(mesh.indices[i * 3])
            let i1 = Int(mesh.indices[i * 3 + 1])
            let i2 = Int(mesh.indices[i * 3 + 2])
            
            let k01 = min(i0, i1) * originalCount + max(i0, i1)
            let k12 = min(i1, i2) * originalCount + max(i1, i2)
            let k20 = min(i2, i0) * originalCount + max(i2, i0)
            
            guard let m01 = vertexMap[k01], let m12 = vertexMap[k12], let m20 = vertexMap[k20] else {
                newIndices.append(contentsOf: [UInt32(i0), UInt32(i1), UInt32(i2)])
                continue
            }
            
            newIndices.append(contentsOf: [UInt32(i0), UInt32(m01), UInt32(m20)])
            newIndices.append(contentsOf: [UInt32(i1), UInt32(m12), UInt32(m01)])
            newIndices.append(contentsOf: [UInt32(i2), UInt32(m20), UInt32(m12)])
            newIndices.append(contentsOf: [UInt32(m01), UInt32(m12), UInt32(m20)])
        }
        
        mesh = Mesh(vertices: newVertices, indices: newIndices)
        return true
    }
}
