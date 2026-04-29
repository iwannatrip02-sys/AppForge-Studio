import Foundation
import simd

class ExtrusionEngine {
    
    func extrude(mesh: inout Mesh, faceIndices: [UInt32], direction: SIMD3<Float>, distance: Float) -> Mesh {
        guard !faceIndices.isEmpty else { return mesh }
        let offset = direction * distance
        var newVertices = mesh.vertices
        let vertexOffset = newVertices.count
        
        // Duplicar los vertices de las caras seleccionadas
        var extrudedVertexMap = [Int: Int]()
        for index in faceIndices {
            let vIdx = Int(index)
            if extrudedVertexMap[vIdx] == nil {
                var v = mesh.vertices[vIdx]
                v.position += offset
                extrudedVertexMap[vIdx] = newVertices.count
                newVertices.append(v)
            }
        }
        
        // Construir nuevas caras (triangulos laterales)
        var newIndices = mesh.indices
        for i in 0..<faceIndices.count {
            let current = Int(faceIndices[i])
            let next = Int(faceIndices[(i + 1) % faceIndices.count])
            if let currNew = extrudedVertexMap[current], let nextNew = extrudedVertexMap[next] {
                // Cara lateral: current - next - nextNew y current - nextNew - currNew
                newIndices.append(UInt32(current))
                newIndices.append(UInt32(next))
                newIndices.append(UInt32(nextNew))
                newIndices.append(UInt32(current))
                newIndices.append(UInt32(nextNew))
                newIndices.append(UInt32(currNew))
            }
        }
        
        // Cara frontal (la cara extrudida)
        for i in 0..<faceIndices.count {
            let idx = Int(faceIndices[i])
            if let newIdx = extrudedVertexMap[idx] {
                newIndices.append(UInt32(newIdx))
            }
        }
        
        return Mesh(vertices: newVertices, indices: newIndices)
    }
}
