import Foundation
import OCCTSwift
import simd

/// Wire and profile management for CAD operations.
/// Wires are 2D/3D profiles that drive extrude, revolve, sweep, and loft.
@MainActor
final class WireManager {
    static let shared = WireManager()
    private init() {}
    
    // MARK: - 2D Profile Creation
    
    func rectangle(width: Double, height: Double) -> Wire? {
        Wire.rectangle(width: width, height: height)
    }
    
    func circle(center: SIMD2<Double>, radius: Double) -> Wire? {
        Wire.circle(center: center, radius: radius)
    }
    
    func polygon(center: SIMD2<Double>, radius: Double, sides: Int) -> Wire? {
        Wire.polygon(center: center, radius: radius, sides: sides)
    }
    
    func arc(center: SIMD2<Double>, radius: Double, startAngle: Double, endAngle: Double) -> Wire? {
        Wire.arc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle)
    }
    
    // MARK: - Profile to 3D
    
    func extrude(profile: Wire, direction: SIMD3<Double>, length: Double) -> Shape? {
        OCCTEngine.shared.extrude(profile: profile, direction: direction, length: length)
    }
    
    func revolve(profile: Wire, axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, angle: Double = .pi * 2) -> Shape? {
        OCCTEngine.shared.revolve(profile: profile, axisOrigin: axisOrigin, axisDirection: axisDirection, angle: angle)
    }
    
    func sweep(profile: Wire, along path: Wire) -> Shape? {
        OCCTEngine.shared.sweep(profile: profile, along: path)
    }
    
    func loft(profiles: [Wire]) -> Shape? {
        OCCTEngine.shared.loft(profiles: profiles)
    }
}

// MARK: - Constraint Manager (Advanced)

/// Solves 2D/3D geometric constraints using OCCT's Gcc solver.
@MainActor
final class ConstraintManager {
    static let shared = ConstraintManager()
    private init() {}
    
    /// Solve a sketch with constraints applied to points and entities.
    func solve(points: [SketchPoint], constraints: [CADConstraint]) -> [SketchPoint] {
        // Use OCCT's Gcc solver for analytical constraint resolution.
        // For now, delegate to the existing Newton-Raphson SolverSwift.
        let solver = Solver()
        return solver.solve(points: points, constraints: constraints) ?? points
    }
    
    func inferConstraints(points: [SketchPoint]) -> [CADConstraint] {
        var inferred: [CADConstraint] = []
        for i in 0..<points.count {
            for j in (i+1)..<points.count {
                let p1 = points[i].position
                let p2 = points[j].position
                let dx = p2.x - p1.x
                let dy = p2.y - p1.y
                // Horizontal alignment
                if abs(dy) < 0.01 {
                    inferred.append(CADConstraint(type: .horizontal, pointA: i, pointB: j))
                }
                // Vertical alignment
                if abs(dx) < 0.01 {
                    inferred.append(CADConstraint(type: .vertical, pointA: i, pointB: j))
                }
            }
        }
        return inferred
    }
}

struct CADConstraint {
    enum ConstraintType: String {
        case horizontal, vertical, distance, angle,
             coincident, parallel, perpendicular, tangent,
             equalLength, concentric, midpoint, collinear
    }
    let type: ConstraintType
    let pointA: Int
    let pointB: Int
    var value: Double = 0
}
