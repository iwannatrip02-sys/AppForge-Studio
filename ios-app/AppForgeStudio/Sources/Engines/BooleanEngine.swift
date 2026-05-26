import Foundation
import OCCTSwift

/// Boolean CSG operations backed by OCCT 8.0.0. All operations return Shape?.
@MainActor
final class BooleanEngine {
    private let engine = OCCTEngine.shared
    
    func union(_ a: CADShape, _ b: CADShape, quality: MeshQuality = .medium) -> Mesh {
        let result = engine.union(a, b) ?? a
        return result.appforgeMesh(quality: quality)
    }
    
    func subtract(_ a: CADShape, _ b: CADShape, quality: MeshQuality = .medium) -> Mesh {
        let result = engine.subtract(a, b) ?? a
        return result.appforgeMesh(quality: quality)
    }
    
    func intersect(_ a: CADShape, _ b: CADShape, quality: MeshQuality = .medium) -> Mesh {
        let result = engine.intersect(a, b) ?? a
        return result.appforgeMesh(quality: quality)
    }
}
