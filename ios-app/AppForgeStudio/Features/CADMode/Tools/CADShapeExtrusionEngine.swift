import Foundation
import simd
import OCCTSwift

/// Parametric extrusion from 2D profile to 3D solid.
@MainActor
final class CADShapeExtrusionEngine {
    private let engine = OCCTEngine.shared
    
    func extrude(profile: Wire, direction: SIMD3<Double>, length: Double, quality: MeshQuality = .medium) -> Mesh {
        let result = engine.extrude(profile: profile, direction: direction, length: length)
        return result?.appforgeMesh(quality: quality) ?? Mesh(vertices: [], indices: [])
    }
    
    func extrude(shape: CADShape, by direction: SIMD3<Double>, quality: MeshQuality = .medium) -> Mesh {
        let result = engine.extrude(shape, by: direction)
        return result?.appforgeMesh(quality: quality) ?? Mesh(vertices: [], indices: [])
    }
    
    func extrudeUp(shape: CADShape, height: Double, quality: MeshQuality = .medium) -> Mesh {
        extrude(shape: shape, by: SIMD3<Double>(0, height, 0), quality: quality)
    }
}
