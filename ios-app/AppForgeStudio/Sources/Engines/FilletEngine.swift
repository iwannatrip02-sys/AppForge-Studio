import Foundation
import simd
import OCCTSwift

/// Edge fillet and chamfer via OCCT TKOffset.
@MainActor
final class FilletEngine {
    private let engine = OCCTEngine.shared
    
    func fillet(_ shape: CADShape, radius: Double, quality: MeshQuality = .medium) -> Mesh {
        let result = engine.fillet(shape, radius: radius)
        return result?.appforgeMesh(quality: quality) ?? shape.appforgeMesh(quality: quality)
    }
}

@MainActor
final class ChamferEngine {
    private let engine = OCCTEngine.shared
    
    func chamfer(_ shape: CADShape, distance: Double, quality: MeshQuality = .medium) -> Mesh {
        let result = engine.chamfer(shape, distance: distance)
        return result?.appforgeMesh(quality: quality) ?? shape.appforgeMesh(quality: quality)
    }
}

typealias BevelEngine = ChamferEngine
