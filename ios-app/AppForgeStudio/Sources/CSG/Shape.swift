import Foundation
import OCCTSwift

/// Thin wrapper around OCCTSwift.Shape providing the same API surface
/// that AppForge's CAD tools expect, now backed by real B-rep geometry.
///
/// All CSG operations now use Open CASCADE Technology 8.0.0 for industrial-grade
/// Boolean ops, fillets, chamfers, extrusions, shells, and sweeps with B-rep fidelity.
typealias CADShape = OCCTSwift.Shape

/// Backward-compatible Shape extension bridging existing CAD tool API to OCCTSwift.
extension CADShape {
    
    // MARK: - CSG Booleans (B-rep, ~1e-11 precision)
    
    func union(_ other: CADShape) -> CADShape { self + other }
    func difference(_ other: CADShape) -> CADShape { self - other }
    func intersection(_ other: CADShape) -> CADShape { self & other }
    
    // MARK: - Primitives (B-rep)
    
    static func makeBox(width: Double, height: Double, depth: Double) -> CADShape {
        .box(width: width, height: height, depth: depth)
    }
    
    static func makeCylinder(radius: Double, height: Double) -> CADShape {
        .cylinder(radius: radius, height: height)
    }
    
    static func makeSphere(radius: Double) -> CADShape {
        .sphere(radius: radius)
    }
    
    static func makeTorus(majorRadius: Double, minorRadius: Double) -> CADShape {
        .torus(majorRadius: majorRadius, minorRadius: minorRadius)
    }
    
    static func makeCone(radius: Double, height: Double) -> CADShape {
        .cone(radius: radius, height: height)
    }
    
    // MARK: - Modifiers (B-rep, analytic)
    
    func filleted(radius: Double) -> CADShape {
        OCCTSwift.Shape.filleted(self)(radius: radius)
    }
    
    func chamfered(radius: Double) -> CADShape {
        OCCTSwift.Shape.chamfered(self)(radius: radius)
    }
    
    func extruded(direction: (dx: Double, dy: Double, dz: Double), distance: Double) -> CADShape {
        OCCTSwift.Shape.extruded(self)(direction: direction, distance: distance)
    }
    
    func revolved(angle: Double) -> CADShape {
        OCCTSwift.Shape.revolved(self)(angle: angle)
    }
    
    func swept(along pathPoints: [SIMD3<Double>]) -> CADShape {
        OCCTSwift.Shape.swept(self)(along: pathPoints)
    }
}
