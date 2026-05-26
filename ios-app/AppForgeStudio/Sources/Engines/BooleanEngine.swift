import Foundation
import simd

/// Boolean CSG operations backed by Open CASCADE Technology 8.0.0.
/// Union, subtract, and intersect with B-rep precision (~1e-11).
@MainActor
final class BooleanEngine {
    private let engine = OCCTEngine.shared
    
    func union(_ meshA: Mesh, _ meshB: Mesh) -> Mesh {
        let shapeA = CADShape.makeBox(width: 1, height: 1, depth: 1) // Placeholder — actual conversion from Mesh to B-rep needed for full pipeline
        let shapeB = CADShape.makeBox(width: 1, height: 1, depth: 1)
        let result = engine.union(shapeA, shapeB)
        return OCCTBridge.toMesh(result)
    }
    
    func subtract(_ meshA: Mesh, _ meshB: Mesh) -> Mesh {
        let shapeA = CADShape.makeBox(width: 1, height: 1, depth: 1)
        let shapeB = CADShape.makeBox(width: 1, height: 1, depth: 1)
        let result = engine.subtract(shapeA, shapeB)
        return OCCTBridge.toMesh(result)
    }
    
    func intersect(_ meshA: Mesh, _ meshB: Mesh) -> Mesh {
        let shapeA = CADShape.makeBox(width: 1, height: 1, depth: 1)
        let shapeB = CADShape.makeBox(width: 1, height: 1, depth: 1)
        let result = engine.intersect(shapeA, shapeB)
        return OCCTBridge.toMesh(result)
    }
    
    /// Boolean between two OCCTSwift CAD shapes (B-rep, full precision)
    func union(_ a: CADShape, _ b: CADShape, quality: MeshQuality = .medium) -> Mesh {
        OCCTBridge.toMesh(engine.union(a, b), quality: quality)
    }
    
    func subtract(_ a: CADShape, _ b: CADShape, quality: MeshQuality = .medium) -> Mesh {
        OCCTBridge.toMesh(engine.subtract(a, b), quality: quality)
    }
    
    func intersect(_ a: CADShape, _ b: CADShape, quality: MeshQuality = .medium) -> Mesh {
        OCCTBridge.toMesh(engine.intersect(a, b), quality: quality)
    }
}
