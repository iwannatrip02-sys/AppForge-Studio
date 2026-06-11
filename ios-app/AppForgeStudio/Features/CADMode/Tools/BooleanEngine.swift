import Foundation
import simd
import OCCTSwift

// BooleanEngine que usa OCCTEngine.shared para operaciones CSG reales
@MainActor
class BooleanEngine {

    // MARK: - Mesh a Shape usando bounding box (OCCTEngine wrapper)
    private func meshToShape(_ mesh: Mesh) -> OCCTSwift.Shape? {
        guard mesh.vertices.count >= 3, mesh.indices.count >= 3 else { return nil }

        // Compute bounding box from mesh vertices
        var minBounds = SIMD3<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxBounds = SIMD3<Float>(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        for v in mesh.vertices {
            minBounds = simd_min(minBounds, v.position)
            maxBounds = simd_max(maxBounds, v.position)
        }
        let size = maxBounds - minBounds
        let engine = OCCTEngine.shared
        return engine.box(width: Double(size.x), height: Double(size.y), depth: Double(size.z))
    }
    
    // MARK: - Shape a Mesh (extraer triangulos de un Shape)
    private func shapeToMesh(_ shape: OCCTSwift.Shape) -> Mesh {
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
        if let shapeA = meshToShape(a), let shapeB = meshToShape(b),
           let result = engine.union(shapeA, shapeB) {
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
        if let shapeA = meshToShape(a), let shapeB = meshToShape(b),
           let result = engine.subtract(shapeA, shapeB) {
            return shapeToMesh(result)
        }
        return a
    }
    
    func booleanIntersection(a: Mesh, b: Mesh) -> Mesh {
        let engine = OCCTEngine.shared
        if let shapeA = meshToShape(a), let shapeB = meshToShape(b),
           let result = engine.intersect(shapeA, shapeB) {
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
