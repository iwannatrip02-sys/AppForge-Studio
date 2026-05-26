import Foundation
import OCCTSwift

/// Wraps Open CASCADE Technology 8.0.0 for professional CAD operations.
/// Replaces the legacy triangle-based Shape + BSP tree with real B-rep geometry.
@MainActor
final class OCCTEngine {
    static let shared = OCCTEngine()
    private init() {}
    
    // MARK: - Primitives
    
    func box(width: Double, height: Double, depth: Double) -> CADShape {
        CADShape.box(width: width, height: height, depth: depth)
    }
    
    func cylinder(radius: Double, height: Double) -> CADShape {
        CADShape.cylinder(radius: radius, height: height)
    }
    
    func sphere(radius: Double) -> CADShape {
        CADShape.sphere(radius: radius)
    }
    
    func torus(majorRadius: Double, minorRadius: Double) -> CADShape {
        CADShape.torus(majorRadius: majorRadius, minorRadius: minorRadius)
    }
    
    func cone(radius: Double, height: Double) -> CADShape {
        CADShape.cone(radius: radius, height: height)
    }
    
    // MARK: - Boolean Operations (B-rep, OCCT BRepAlgoAPI)
    
    func union(_ a: CADShape, _ b: CADShape) -> CADShape { a + b }
    
    func subtract(_ a: CADShape, _ b: CADShape) -> CADShape { a - b }
    
    func intersect(_ a: CADShape, _ b: CADShape) -> CADShape { a & b }
    
    // MARK: - Modifiers (TKOffset + TKTopAlgo)
    
    func fillet(_ shape: CADShape, radius: Double) -> CADShape {
        OCCTSwift.Shape.filleted(shape)(radius: radius)
    }
    
    func chamfer(_ shape: CADShape, radius: Double) -> CADShape {
        OCCTSwift.Shape.chamfered(shape)(radius: radius)
    }
    
    func extrude(_ shape: CADShape,
                 direction: (dx: Double, dy: Double, dz: Double),
                 distance: Double) -> CADShape {
        OCCTSwift.Shape.extruded(shape)(direction: direction, distance: distance)
    }
    
    func revolve(_ shape: CADShape, angle: Double) -> CADShape {
        OCCTSwift.Shape.revolved(shape)(angle: angle)
    }
    
    func sweep(_ shape: CADShape, along points: [SIMD3<Double>]) -> CADShape {
        OCCTSwift.Shape.swept(shape)(along: points)
    }
    
    func loft(_ profiles: [(points: [SIMD3<Double>], position: SIMD3<Double>)]) -> CADShape {
        OCCTSwift.Shape.loft(profiles: profiles)
    }
    
    func shell(_ shape: CADShape, thickness: Double) -> CADShape {
        OCCTSwift.Shape.shelled(shape)(thickness: thickness)
    }
    
    // MARK: - Analysis (B-rep precision)
    
    func measureVolume(_ shape: CADShape) -> Double {
        shape.volume()
    }
    
    func measureArea(_ shape: CADShape) -> Double {
        shape.area()
    }
    
    func measureBoundingBox(_ shape: CADShape) -> (min: SIMD3<Double>, max: SIMD3<Double>, size: SIMD3<Double>) {
        shape.boundingBox()
    }
    
    // MARK: - STEP Export (OCCT TKSTEP)
    
    func exportSTEP(_ shape: CADShape, to url: URL) throws {
        try OCCTSwift.Exporter.writeSTEP(shape, to: url)
    }
    
    func exportSTL(_ shape: CADShape, to url: URL) throws {
        try OCCTSwift.Exporter.writeSTL(shape, to: url)
    }
    
    // MARK: - STEP/IGES Import
    
    func importSTEP(from url: URL) throws -> CADShape {
        try OCCTSwift.Document.load(from: url)
    }
    
    func importIGES(from url: URL) throws -> CADShape {
        try OCCTSwift.Document.load(from: url)
    }
}
