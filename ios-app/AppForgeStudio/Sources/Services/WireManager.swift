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
        Wire.circle(origin: SIMD3<Double>(center.x, center.y, 0), radius: radius)
    }

    func polygon(center: SIMD2<Double>, radius: Double, sides: Int) -> Wire? {
        guard sides >= 3 else { return nil }
        let points = (0..<sides).map { i -> SIMD2<Double> in
            let angle = Double(i) / Double(sides) * 2 * .pi
            return SIMD2<Double>(center.x + radius * cos(angle), center.y + radius * sin(angle))
        }
        return Wire.polygon(points)
    }

    func arc(center: SIMD2<Double>, radius: Double, startAngle: Double, endAngle: Double) -> Wire? {
        Wire.arc(center: SIMD3<Double>(center.x, center.y, 0), radius: radius,
                 startAngle: startAngle, endAngle: endAngle)
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
        // Resolución analítica simple (horizontal/vertical/coincident).
        // TODO(F3): delegar al solver Newton-Raphson (GeometryConstraintManager) o OCCT Gcc.
        var result = points
        for constraint in constraints {
            guard constraint.pointA < result.count, constraint.pointB < result.count else { continue }
            switch constraint.type {
            case .horizontal:
                let avgY = (result[constraint.pointA].position.y + result[constraint.pointB].position.y) * 0.5
                result[constraint.pointA].position.y = avgY
                result[constraint.pointB].position.y = avgY
            case .vertical:
                let avgX = (result[constraint.pointA].position.x + result[constraint.pointB].position.x) * 0.5
                result[constraint.pointA].position.x = avgX
                result[constraint.pointB].position.x = avgX
            case .coincident:
                result[constraint.pointB].position = result[constraint.pointA].position
            default:
                break
            }
        }
        return result
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
