import Foundation
import simd

/// Loft, shell, and sweep operations via OCCT B-rep.
@MainActor
final class LoftEngine {
    private let engine = OCCTEngine.shared
    
    func loft(profiles: [(points: [SIMD3<Double>], position: SIMD3<Double>)],
              quality: MeshQuality = .medium) -> Mesh {
        let result = engine.loft(profiles)
        return OCCTBridge.toMesh(result, quality: quality)
    }
}

@MainActor
final class ShellEngine {
    private let engine = OCCTEngine.shared
    
    func shell(_ shape: CADShape, thickness: Double, quality: MeshQuality = .medium) -> Mesh {
        let result = engine.shell(shape, thickness: thickness)
        return OCCTBridge.toMesh(result, quality: quality)
    }
}

@MainActor
final class SweepEngine {
    private let engine = OCCTEngine.shared
    
    func sweep(_ shape: CADShape, along path: [SIMD3<Double>],
               quality: MeshQuality = .medium) -> Mesh {
        let result = engine.sweep(shape, along: path)
        return OCCTBridge.toMesh(result, quality: quality)
    }
}
