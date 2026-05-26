import Foundation
import simd

/// B-rep precision measurement engine via OCCT.
@MainActor
final class MeasureEngine {
    private let engine = OCCTEngine.shared
    
    func volume(of shape: CADShape) -> Double {
        engine.measureVolume(shape)
    }
    
    func area(of shape: CADShape) -> Double {
        engine.measureArea(shape)
    }
    
    func boundingBox(of shape: CADShape) -> (min: SIMD3<Double>, max: SIMD3<Double>, size: SIMD3<Double>) {
        engine.measureBoundingBox(shape)
    }
    
    func distance(from a: SIMD3<Double>, to b: SIMD3<Double>) -> Double {
        simd_length(b - a)
    }
}
