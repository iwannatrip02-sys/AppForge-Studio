import Foundation

/// Analytic edge fillet and chamfer via OCCT TKOffset (B-rep).
@MainActor
final class FilletEngine {
    private let engine = OCCTEngine.shared
    
    func fillet(_ shape: CADShape, radius: Double, quality: MeshQuality = .medium) -> Mesh {
        let result = engine.fillet(shape, radius: radius)
        return OCCTBridge.toMesh(result, quality: quality)
    }
}

@MainActor
final class ChamferEngine {
    private let engine = OCCTEngine.shared
    
    func chamfer(_ shape: CADShape, radius: Double, quality: MeshQuality = .medium) -> Mesh {
        let result = engine.chamfer(shape, radius: radius)
        return OCCTBridge.toMesh(result, quality: quality)
    }
}

/// Bevel alias — delegates to chamfer engine.
typealias BevelEngine = ChamferEngine
