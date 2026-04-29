import Foundation
import simd
import Metal

// MARK: - SubdivisionEngine
// Implementa el algoritmo Catmull-Clark para suavizado de mallas.
// Soporta mallas triangulares (3 indices por cara).
@MainActor
class SubdivisionEngine: ObservableObject {
    @Published var isSubdividing = false
    @Published var progress: Float = 0
    
    private let device: MTLDevice?
    
    init(device: MTLDevice? = nil) {
        self.device = device
    }
    
    // MARK: - Subdivision Principal
    // Aplica Catmull-Clark a una malla 'levels' veces.
    func subdivide(_ mesh: Mesh, levels: Int = 1) -> Mesh {
        guard levels > 0, mesh.vertices.count >= 3, mesh.indices.count >= 3 else {
            return mesh
        }
        
        var currentMesh = mesh
        isSubdividing = true
        progress = 0
        
        for level in 0..<min(levels, 4) {
            currentMesh = subdivideOnce(currentMesh)
            progress = Float(level + 1) / Float(levels)
        }
        
        // Subir a GPU si tenemos device
        if let device = device {
            currentMesh.uploadToGPU(device: device)
        }
        
        isSubdividing = false
        progress = 1.0
        return currentMesh
    }
    
    // MARK: - Preview Rapido
    // Para preview en tiempo real sin reconstruir topologia completa.
    // Solo calcula nuevas posiciones de vertices existentes.
    func previewSubdivision(_ mesh: Mesh, level: Int) -> Mesh {
        guard level > 0 else { return mesh }
        var preview = mesh
        for _ in 0..<min(level, 3) {
            preview = smoothVertices(preview)
        }
        return preview
    }
    
    // MARK: - Smooth (solo vertices, sin cambiar topologia)
    private func smoothVertices(_ mesh: Mesh) -> Mesh {
        var newVertices = mesh.vertices
        let vertexCount = newVertices.count
        
        // Construir lista de adjacencia por aristas
        var edgeMap: [UInt64: [Int]] = [:]
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            guard i + 2 < mesh.indices.count else { break }
            let i0 = Int(mesh.indices[i])
            let i1 = Int(mesh.indices[i+1])
            let i2 = Int(mesh.indices[i+2])
            
            addEdge(&edgeMap, a: i0, b: i1, faceIdx: i/3)
            addEdge(&edgeMap, a: i1, b: i2, faceIdx: i/3)
            addEdge(&edgeMap, a: i2, b: i0, faceIdx: i/3)
        }
        
        // Calcular new vertex = promedio de vecinos
        for vi in 0..<vertexCount {
            guard let neighbors = edgeMap[edgeKey(vi, vi)] else { continue }
            var sum = SIMD3<Float>.zero
            var count = 0
            for (key, _) in edgeMap {
                let a = Int(key >> 32)
                let b = Int(key & 0xFFFFFFFF)
                if a == vi, b < vertexCount {
                    sum += mesh.vertices[b].position
                    count += 1
                } else if b == vi, a < vertexCount {
                    sum += mesh.vertices[a].position
                    count += 1
                }
            }
            if count > 0 {
                newVertices[vi].position = mesh.vertices[vi].position * 0.5 + (sum / Float(count)) * 0.5
                newVertices[vi].normal = estimateNormal(at: vi, mesh: mesh, edgeMap: edgeMap)
            }
        }
        
        var newMesh = mesh
        newMesh.vertices = newVertices
        return newMesh
    }
    
    // MARK: - Catmull-Clark Una Iteracion
    private func subdivideOnce(_ mesh: Mesh) -> Mesh {
        let vertices = mesh.vertices
        let indices = mesh.indices
        let vertexCount = vertices.count
        let faceCount = indices.count / 3
        
        guard faceCount > 0 else { return mesh }
        
        // Construir estructuras auxiliares
        var faceVertices: [[Int]] = []
        for f in 0..<faceCount {
            let i0 = Int(indices[f * 3])
            let i1 = Int(indices[f * 3 + 1])
            let i2 = Int(indices[f * 3 + 2])
            faceVertices.append([i0, i1, i2])
        }
        
        // Construir aristas con sus caras adjacentes
        var edgeToFaces: [UInt64: [Int]] = [:]
        for (fi, fv) in faceVertices.enumerated() {
            for j in 0..<3 {
                let a = fv[j]
                let b = fv[(j + 1) % 3]
                let key = edgeKey(min(a, b), max(a, b))
                if edgeToFaces[key] == nil {
                    edgeToFaces[key] = []
                }
                if !edgeToFaces[key]!.contains(fi) {
                    edgeToFaces[key]!.append(fi)
                }
            }
        }
        
        // Construir caras por vertice
        var vertexFaces: [Int: [Int]] = [:]
        for (fi, fv) in faceVertices.enumerated() {
            for v in fv {
                if vertexFaces[v] == nil { vertexFaces[v] = [] }
                if !vertexFaces[v]!.contains(fi) {
                    vertexFaces[v]!.append(fi)
                }
            }
        }
        
        // 1. Calcular Face Points
        var facePoints: [SIMD3<Float>] = []
        for fv in faceVertices {
            let sum = vertices[fv[0]].position + vertices[fv[1]].position + vertices[fv[2]].position
            facePoints.append(sum / 3.0)
        }
        
        // 2. Calcular Edge Points
        var edgePoints: [UInt64: SIMD3<Float>] = [:]
        for (key, faces) in edgeToFaces {
            let a = Int(key >> 32)
            let b = Int(key & 0xFFFFFFFF)
            let midpoint = (vertices[a].position + vertices[b].position) * 0.5
            
            if faces.count == 2 {
                // Arista interior: promedio con face points adjacentes
                let fp1 = facePoints[faces[0]]
                let fp2 = facePoints[faces[1]]
                edgePoints[key] = (midpoint + fp1 + fp2) / 3.0
            } else {
                // Arista de borde: solo midpoint
                edgePoints[key] = midpoint
            }
        }
        
        // 3. Calcular Vertex Points
        var newVertexPositions: [SIMD3<Float>] = Array(repeating: .zero, count: vertexCount)
        for vi in 0..<vertexCount {
            guard let adjFaces = vertexFaces[vi], !adjFaces.isEmpty else {
                newVertexPositions[vi] = vertices[vi].position
                continue
            }
            
            let n = Float(adjFaces.count)
            
            // Q = promedio de face points
            var qSum = SIMD3<Float>.zero
            for fi in adjFaces { qSum += facePoints[fi] }
            let q = qSum / n
            
            // R = promedio de edge midpoints
            var rSum = SIMD3<Float>.zero
            var edgeCount: Float = 0
            for (key, _) in edgeToFaces {
                let a = Int(key >> 32)
                let b = Int(key & 0xFFFFFFFF)
                if a == vi || b == vi {
                    rSum += (vertices[a].position + vertices[b].position) * 0.5
                    edgeCount += 1
                }
            }
            let r = edgeCount > 0 ? rSum / edgeCount : vertices[vi].position
            
            // Formula Catmull-Clark: new_vertex = (Q + 2R + (n-3)*old) / n
            let old = vertices[vi].position
            if n >= 3 {
                newVertexPositions[vi] = (q + 2.0 * r + (n - 3.0) * old) / n
            } else {
                newVertexPositions[vi] = (q + 2.0 * r) / 3.0
            }
        }
        
        // 4. Construir nuevas caras
        var newVertices: [Vertex] = []
        var newIndices: [UInt32] = []
        
        // Agregar vertices originales con nuevas posiciones
        for i in 0..<vertexCount {
            var v = vertices[i]
            v.position = newVertexPositions[i]
            newVertices.append(v)
        }
        
        // Agregar edge points como nuevos vertices
        let edgePointStart = UInt32(newVertices.count)
        var edgePointIndex: [UInt64: UInt32] = [:]
        var epIdx = edgePointStart
        for (key, pos) in edgePoints {
            edgePointIndex[key] = epIdx
            newVertices.append(Vertex(position: pos, normal: .zero, uv: .zero))
            epIdx += 1
        }
        
        // Agregar face points como nuevos vertices
        let facePointStart = epIdx
        var facePointIndex: [Int: UInt32] = [:]
        for (fi, fp) in facePoints.enumerated() {
            facePointIndex[fi] = facePointStart + UInt32(fi)
            newVertices.append(Vertex(position: fp, normal: .zero, uv: .zero))
        }
        
        // Crear 3 nuevas caras por cada cara original
        for (fi, fv) in faceVertices.enumerated() {
            let v0 = UInt32(fv[0])
            let v1 = UInt32(fv[1])
            let v2 = UInt32(fv[2])
            let fp = facePointIndex[fi]!
            
            // Aristas de la cara
            let e01 = edgePointIndex[edgeKey(fv[0], fv[1])]!
            let e12 = edgePointIndex[edgeKey(fv[1], fv[2])]!
            let e20 = edgePointIndex[edgeKey(fv[2], fv[0])]!
            
            // Cara 1: v0, e01, fp, e20
            newIndices.append(contentsOf: [v0, e01, fp, v0, fp, e20])
            // Cara 2: v1, e12, fp, e01
            newIndices.append(contentsOf: [v1, e12, fp, v1, fp, e01])
            // Cara 3: v2, e20, fp, e12
            newIndices.append(contentsOf: [v2, e20, fp, v2, fp, e12])
        }
        
        // Calcular normals para nuevos vertices
        for i in 0..<newVertices.count {
            newVertices[i].normal = estimateNormalFromIndices(vertexIdx: i, vertices: newVertices, indices: newIndices)
        }
        
        return Mesh(vertices: newVertices, indices: newIndices)
    }
    
    // MARK: - Helpers
    private func edgeKey(_ a: Int, _ b: Int) -> UInt64 {
        let minVal = UInt64(min(a, b))
        let maxVal = UInt64(max(a, b))
        return (minVal << 32) | maxVal
    }
    
    private func addEdge(_ map: inout [UInt64: [Int]], a: Int, b: Int, faceIdx: Int) {
        let key = edgeKey(a, b)
        if map[key] == nil { map[key] = [] }
        if !map[key]!.contains(faceIdx) {
            map[key]!.append(faceIdx)
        }
    }
    
    private func estimateNormal(at vi: Int, mesh: Mesh, edgeMap: [UInt64: [Int]]) -> SIMD3<Float> {
        guard vi < mesh.vertices.count else { return .zero }
        var normal = SIMD3<Float>.zero
        var count = 0
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            guard i + 2 < mesh.indices.count else { break }
            let i0 = Int(mesh.indices[i])
            let i1 = Int(mesh.indices[i+1])
            let i2 = Int(mesh.indices[i+2])
            if i0 == vi || i1 == vi || i2 == vi {
                let v0 = mesh.vertices[i0].position
                let v1 = mesh.vertices[i1].position
                let v2 = mesh.vertices[i2].position
                let edge1 = v1 - v0
                let edge2 = v2 - v0
                let faceNormal = simd_cross(edge1, edge2)
                if simd_length(faceNormal) > 0.001 {
                    normal += simd_normalize(faceNormal)
                    count += 1
                }
            }
        }
        return count > 0 ? simd_normalize(normal / Float(count)) : .zero
    }
    
    private func estimateNormalFromIndices(vertexIdx: Int, vertices: [Vertex], indices: [UInt32]) -> SIMD3<Float> {
        var normal = SIMD3<Float>.zero
        var count = 0
        let ui = UInt32(vertexIdx)
        for i in stride(from: 0, to: indices.count, by: 3) {
            guard i + 2 < indices.count else { break }
            let i0 = indices[i]
            let i1 = indices[i+1]
            let i2 = indices[i+2]
            if i0 == ui || i1 == ui || i2 == ui {
                let v0 = vertices[Int(i0)].position
                let v1 = vertices[Int(i1)].position
                let v2 = vertices[Int(i2)].position
                let edge1 = v1 - v0
                let edge2 = v2 - v0
                let faceNormal = simd_cross(edge1, edge2)
                if simd_length(faceNormal) > 0.001 {
                    normal += simd_normalize(faceNormal)
                    count += 1
                }
            }
        }
        return count > 0 ? simd_normalize(normal / Float(count)) : .zero
    }
}