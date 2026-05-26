import Foundation
import simd
import OCCTSwift

/// Wraps Open CASCADE Technology 8.0.0 (via gsdali/OCCTSwift) for professional CAD.
/// All operations return Shape? — nil means the operation failed on degenerate geometry.
@MainActor
final class OCCTEngine {
    static let shared = OCCTEngine()
    private init() {}
    
    // MARK: - Primitives (all return Shape?)
    
    func box(width: Double, height: Double, depth: Double) -> OCCTSwift.Shape? {
        OCCTSwift.Shape.box(width: width, height: height, depth: depth)
    }
    
    func cylinder(radius: Double, height: Double) -> OCCTSwift.Shape? {
        OCCTSwift.Shape.cylinder(radius: radius, height: height)
    }
    
    func sphere(radius: Double) -> OCCTSwift.Shape? {
        OCCTSwift.Shape.sphere(radius: radius)
    }
    
    func torus(majorRadius: Double, minorRadius: Double) -> OCCTSwift.Shape? {
        OCCTSwift.Shape.torus(majorRadius: majorRadius, minorRadius: minorRadius)
    }
    
    func cone(bottomRadius: Double, topRadius: Double, height: Double) -> OCCTSwift.Shape? {
        OCCTSwift.Shape.cone(bottomRadius: bottomRadius, topRadius: topRadius, height: height)
    }
    
    // MARK: - Boolean Operations (operators +, -, & return Shape?)
    
    func union(_ a: OCCTSwift.Shape, _ b: OCCTSwift.Shape) -> OCCTSwift.Shape? { a + b }
    
    func subtract(_ a: OCCTSwift.Shape, _ b: OCCTSwift.Shape) -> OCCTSwift.Shape? { a - b }
    
    func intersect(_ a: OCCTSwift.Shape, _ b: OCCTSwift.Shape) -> OCCTSwift.Shape? { a & b }
    
    // MARK: - Modifiers (all return Shape?)
    
    func fillet(_ shape: OCCTSwift.Shape, radius: Double) -> OCCTSwift.Shape? {
        shape.filleted(radius: radius)
    }
    
    func chamfer(_ shape: OCCTSwift.Shape, distance: Double) -> OCCTSwift.Shape? {
        shape.chamfered(distance: distance)
    }
    
    func shell(_ shape: OCCTSwift.Shape, thickness: Double) -> OCCTSwift.Shape? {
        shape.shelled(thickness: thickness)
    }
    
    func extrude(_ shape: OCCTSwift.Shape, by direction: SIMD3<Double>) -> OCCTSwift.Shape? {
        shape.extruded(by: direction)
    }
    
    func extrude(profile: Wire, direction: SIMD3<Double>, length: Double) -> OCCTSwift.Shape? {
        OCCTSwift.Shape.extrude(profile: profile, direction: direction, length: length)
    }
    
    func revolve(profile: Wire, axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, angle: Double = .pi * 2) -> OCCTSwift.Shape? {
        OCCTSwift.Shape.revolve(profile: profile, axisOrigin: axisOrigin, axisDirection: axisDirection, angle: angle)
    }
    
    func revolve(_ shape: OCCTSwift.Shape, axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>) -> OCCTSwift.Shape? {
        shape.revolved(axisOrigin: axisOrigin, axisDirection: axisDirection)
    }
    
    func sweep(profile: Wire, along path: Wire) -> OCCTSwift.Shape? {
        OCCTSwift.Shape.sweep(profile: profile, along: path)
    }
    
    func loft(profiles: [Wire], solid: Bool = true) -> OCCTSwift.Shape? {
        OCCTSwift.Shape.loft(profiles: profiles, solid: solid)
    }
    
    // MARK: - Analysis (computed properties, all optional)
    
    func measureVolume(_ shape: OCCTSwift.Shape) -> Double? {
        shape.volume
    }
    
    func measureArea(_ shape: OCCTSwift.Shape) -> Double? {
        shape.surfaceArea
    }
    
    func measureBoundingBox(_ shape: OCCTSwift.Shape) -> (min: SIMD3<Double>, max: SIMD3<Double>) {
        shape.bounds
    }
    
    func measureSize(_ shape: OCCTSwift.Shape) -> SIMD3<Double> {
        shape.size
    }
    
    func measureCenter(_ shape: OCCTSwift.Shape) -> SIMD3<Double> {
        shape.center
    }
    
    // MARK: - STEP/IGES/STL Export (throws)
    
    func exportSTEP(_ shape: OCCTSwift.Shape, to url: URL) throws {
        try Exporter.writeSTEP(shape: shape, to: url)
    }
    
    func exportSTL(_ shape: OCCTSwift.Shape, to url: URL, deflection: Double = 0.05) throws {
        try Exporter.writeSTL(shape: shape, to: url, deflection: deflection)
    }
    
    // MARK: - STEP/IGES Import (throws)
    
    func importSTEP(from url: URL) throws -> OCCTSwift.Shape? {
        try OCCTSwift.Shape.load(from: url)
    }
    
    func importSTEP(from path: String) throws -> OCCTSwift.Shape? {
        try OCCTSwift.Shape.loadSTEP(fromPath: path)
    }
    
    func importDocument(from url: URL) throws -> Document {
        try Document.load(from: url)
    }
}
