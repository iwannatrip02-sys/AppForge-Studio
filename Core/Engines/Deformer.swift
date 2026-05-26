import Foundation
import simd

protocol Deformer {
    func deform(vertex: inout Vertex, at point: SculptPoint, radius: Float, strength: Float, falloff: Float, adjacency: [SIMD3<Float>]? = nil)
}

struct DeformerFactory {
    static func make(_ type: DeformerType) -> Deformer {
        switch type {
        case .inflate: return InflateDeformer()
        case .pinch: return PinchDeformer()
        case .smooth: return SmoothDeformer()
        case .crease: return CreaseDeformer()
        case .grab: return GrabDeformer()
        case .flatten: return FlattenDeformer()
        case .twist: return TwistDeformer()
        case .move: return MoveDeformer()
        }
    }
}