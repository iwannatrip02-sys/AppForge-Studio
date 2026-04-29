import Foundation
import simd
import OCCTSwift

// BooleanEngine que usa OCCTEngine.shared para operaciones CSG reales
class BooleanEngine {
    
    // MARK: - Mesh a Shape usando triangulacion OCCT BRepBuilderAPI_MakePolygon
    private func meshToShape(_ mesh: Mesh) -> Shape? {
        guard mesh.vertices.count >= 3, mesh.indices.count >= 3 else { return nil }
        
        // Construir Shape desde triangulos reales de la malla
        do {
            let points: [SIMD3<Double>] = mesh.vertices.map { v in
                SIMD3<Double>(Double(v.position.x), Double(v.position.y), Double(v.position.z))
            }
            
            var triangles: [(SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)] = []
            for i in stride(from: 0, to: mesh.indices.count, by: 3) {
                guard i + 2 < mesh.indices.count else { break }
                let i0 = Int(mesh.indices[i])
                let i1 = Int(mesh.indices[i+1])
                let i2 = Int(mesh.indices[i+2])
                guard i0 < points.count, i1 < points.count, i2 < points.count else { continue }
                triangles.append((points[i0], points[i1], points[i2]))
            }
            
            guard !triangles.isEmpty else { return nil }
            
            if triangles.count == 1 {
                let (p0, p1, p2) = triangles[0]
                return try Shape.face(p0: p0, p1: p1, p2: p2)
            } else {
                var faces: [Shape] = []
                for (p0, p1, p2) in triangles {
                    if let face = try? Shape.face(p0: p0, p1: p1, p2: p2) {
                        faces.append(face)
                    }
                }
                guard !faces.isEmpty else { return nil }
                let shell = Shape.shell(faces: faces)
                return Shape.solid(shell: shell)
            }
        } catch {
            var minBounds = SIMD3<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
            var maxBounds = SIMD3<Float>(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
            for v in mesh.vertices {
                minBounds = simd_min(minBounds, v.position)
                maxBounds = simd_max(maxBounds, v.position)
            }
            let size = maxBounds - minBounds
            let center = (minBounds + maxBounds) * 0.5
            let engine = OCCTEngine.shared
            let box = engine.createBox(width: Double(size.x), height: Double(size.y), depth: Double(size.z))
            return box
        }
    }
    
    // MARK: - Shape a Mesh (extraer triangulos de un Shape)
    private func shapeToMesh(_ shape: Shape) -> Mesh {
        do {
            let triangles = try shape.triangulate()
            let vertices = triangles.vertices.map { tv in
                Vertex(position: SIMD3<Float>(Float(tv.x), Float(tv.y), Float(tv.z)),
                       normal: SIMD3<Float>(0, 0, 1),
                       uv: SIMD2<Float>(0, 0))
            }
            return Mesh(vertices: vertices, indices: triangles.indices)
        } catch {
            return Mesh()
        }
    }
    
    // MARK: - Operaciones Booleanas
    
    func booleanUnion(a: Mesh, b: Mesh) -> Mesh {
        let engine = OCCTEngine.shared
        if let shapeA = meshToShape(a), let shapeB = meshToShape(b) {
            let result = engine.union(shapeA, shapeB)
            return shapeToMesh(result)
        }
        // Fallback: concatenar vertices
        var combinedVerts = a.vertices
        var combinedInds = a.indices
        let offset = UInt32(combinedVerts.count)
        for i in b.indices {
            combinedInds.append(i + offset)
        }
        combinedVerts.append(contentsOf: b.vertices)
        return Mesh(vertices: combinedVerts, indices: combinedInds)
    }
    
    func booleanDifference(a: Mesh, b: Mesh) -> Mesh {
        let engine = OCCTEngine.shared
        if let shapeA = meshToShape(a), let shapeB = meshToShape(b) {
            let result = engine.subtract(shapeA, shapeB)
            return shapeToMesh(result)
        }
        return a
    }
    
    func booleanIntersection(a: Mesh, b: Mesh) -> Mesh {
        let engine = OCCTEngine.shared
        if let shapeA = meshToShape(a), let shapeB = meshToShape(b) {
            let result = engine.intersect(shapeA, shapeB)
            return shapeToMesh(result)
        }
        return Mesh()
    }
    
    // MARK: - Helpers
    
    func validateMesh(_ mesh: Mesh) -> Bool {
        return mesh.vertices.count >= 3 && mesh.indices.count >= 3
    }
    
    func repairMesh(_ mesh: Mesh) -> Mesh {
        var repaired = mesh
        if repaired.indices.count % 3 != 0 {
            let excess = repaired.indices.count % 3
            repaired.indices.removeLast(excess)
        }
        return repaired
    }
}
