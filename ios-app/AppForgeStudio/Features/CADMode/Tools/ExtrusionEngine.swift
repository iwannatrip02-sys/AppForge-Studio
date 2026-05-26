import Foundation
import simd

/// Parametric extrusion from 2D profile to 3D solid using OCCT B-rep.
@MainActor
final class ExtrusionEngine {
    private let engine = OCCTEngine.shared
    
    func extrude(shape: CADShape,
                 direction: SIMD3<Double>,
                 distance: Double,
                 quality: MeshQuality = .medium) -> Mesh {
        let dir = (dx: direction.x, dy: direction.y, dz: direction.z)
        let result = engine.extrude(shape, direction: dir, distance: distance)
        return OCCTBridge.toMesh(result, quality: quality)
    }
    
    func extrude(face: CADShape, height: Double) -> Mesh {
        extrude(shape: face, direction: SIMD3<Double>(0, 1, 0), distance: height)
    }
}
