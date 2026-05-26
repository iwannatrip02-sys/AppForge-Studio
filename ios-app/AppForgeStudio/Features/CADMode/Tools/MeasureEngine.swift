import Foundation
import simd
import OCCTSwift

/// B-rep precision measurement via OCCT 8.0.0. Properties are computed (optionals).
@MainActor
final class MeasureEngine {
    private let engine = OCCTEngine.shared
    
    func volume(of shape: CADShape) -> Double { engine.measureVolume(shape) ?? 0 }
    
    func area(of shape: CADShape) -> Double { engine.measureArea(shape) ?? 0 }
    
    func boundingBox(of shape: CADShape) -> (min: SIMD3<Double>, max: SIMD3<Double>) {
        engine.measureBoundingBox(shape)
    }
    
    func size(of shape: CADShape) -> SIMD3<Double> { engine.measureSize(shape) }
    
    func center(of shape: CADShape) -> SIMD3<Double> { engine.measureCenter(shape) }
}
