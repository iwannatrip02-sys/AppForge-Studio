import Foundation
import simd

// MARK: - 2D Geometry Entities
enum Sketch2DEntity {
    case point(SIMD2<Float>)
    case line(SIMD2<Float>, SIMD2<Float>)
    case arc(center: SIMD2<Float>, radius: Float, startAngle: Float, endAngle: Float)
    case circle(center: SIMD2<Float>, radius: Float)
    
    var points: [SIMD2<Float>] {
        switch self {
        case .point(let p): return [p]
        case .line(let a, let b): return [a, b]
        case .arc(let c, let r, let sa, let ea):
            let segs = 32
            var pts: [SIMD2<Float>] = []
            for i in 0...segs {
                let t = sa + (ea - sa) * Float(i) / Float(segs)
                pts.append(c + SIMD2<Float>(cos(t), sin(t)) * r)
            }
            return pts
        case .circle(let c, let r):
            let segs = 32
            var pts: [SIMD2<Float>] = []
            for i in 0..<segs {
                let t = 2 * Float.pi * Float(i) / Float(segs)
                pts.append(c + SIMD2<Float>(cos(t), sin(t)) * r)
            }
            return pts
        }
    }
}

// MARK: - Constraints
enum SketchConstraintType {
    case distance(Sketch2DEntity, Sketch2DEntity, Float)        // distance between two entities
    case angle(Sketch2DEntity, Sketch2DEntity, Float)           // angle between two lines
    case coincident(Sketch2DEntity, Sketch2DEntity)             // points coincide
    case concentric(Sketch2DEntity, Sketch2DEntity)             // share center
    case parallel(Sketch2DEntity, Sketch2DEntity)               // lines are parallel
    case perpendicular(Sketch2DEntity, Sketch2DEntity)          // lines are perpendicular
    case horizontal(Sketch2DEntity)                          // line is horizontal
    case vertical(Sketch2DEntity)                            // line is vertical
    case fixed(Sketch2DEntity)                                // lock position
}

struct Constraint {
    let type: SketchConstraintType
    let priority: Int = 1
    var isSatisfied: Bool = false
}

// MARK: - Sketch
class Sketch2D {
    var entities: [Sketch2DEntity] = []
    var constraints: [Constraint] = []
    
    func addEntity(_ entity: Sketch2DEntity) { entities.append(entity) }
    
    func addConstraint(_ type: SketchConstraintType) {
        constraints.append(Constraint(type: type))
    }
    
    /// Evaluate all constraints and compute residual (sum of squared errors)
    func evaluateConstraints() -> Float {
        var residual: Float = 0
        for (i, constraint) in constraints.enumerated() {
            let error = constraintError(constraint.type, index: i)
            residual += error * error
        }
        return residual
    }
    
    private func constraintError(_ type: SketchConstraintType, index: Int) -> Float {
        switch type {
        case .distance(let e1, let e2, let target):
            let p1 = centerOf(e1)
            let p2 = centerOf(e2)
            return simd_distance(p1, p2) - target
        case .angle(let e1, let e2, let target):
            let dir1 = directionOf(e1)
            let dir2 = directionOf(e2)
            let dotClamped = max(-1, min(1, simd_dot(dir1, dir2)))
            return acos(dotClamped) - target
        case .coincident(let e1, let e2):
            return simd_distance(centerOf(e1), centerOf(e2))
        case .concentric(let e1, let e2):
            return simd_distance(centerOf(e1), centerOf(e2))
        case .parallel(let e1, let e2):
            let d1 = directionOf(e1); let d2 = directionOf(e2)
            let cross = abs(d1.x * d2.y - d1.y * d2.x)
            return cross
        case .perpendicular(let e1, let e2):
            let d1 = directionOf(e1); let d2 = directionOf(e2)
            return abs(simd_dot(d1, d2))
        case .horizontal(let e):
            let dir = directionOf(e)
            return abs(dir.y)
        case .vertical(let e):
            let dir = directionOf(e)
            return abs(dir.x)
        case .fixed:
            return 0
        }
    }
    
    private func centerOf(_ entity: Sketch2DEntity) -> SIMD2<Float> {
        switch entity {
        case .point(let p): return p
        case .line(let a, let b): return (a + b) * 0.5
        case .arc(let c, _, _, _): return c
        case .circle(let c, _): return c
        }
    }
    
    private func directionOf(_ entity: Sketch2DEntity) -> SIMD2<Float> {
        switch entity {
        case .line(let a, let b):
            let d = b - a
            return simd_normalize(d)
        case .arc(let c, let r, let sa, let ea):
            let mid = sa + (ea - sa) * 0.5
            return SIMD2<Float>(cos(mid), sin(mid))
        default: return SIMD2<Float>(1, 0)
        }
    }
    
    /// Solve constraints using gradient descent
    func solve(maxIterations: Int = 100, tolerance: Float = 1e-4) -> Bool {
        for _ in 0..<maxIterations {
            let residual = evaluateConstraints()
            if residual < tolerance { return true }
            // Simple gradient descent: perturb each point slightly and recompute
            for i in 0..<entities.count {
                let original = entities[i]
                let delta: Float = 0.001
                var bestResidual = residual
                var bestEntity = original
                
                // Try perturbations in 4 directions
                for dx in [-delta, delta] {
                    for dy in [-delta, delta] {
                        var modified = original
                        if case .point(let p) = modified {
                            modified = .point(p + SIMD2<Float>(dx, dy))
                        }
                        entities[i] = modified
                        let newResidual = evaluateConstraints()
                        if newResidual < bestResidual {
                            bestResidual = newResidual
                            bestEntity = modified
                        }
                    }
                }
                entities[i] = bestEntity
            }
        }
        return evaluateConstraints() < tolerance
    }
    
    /// Convert sketch to 3D profile for extrusion
    func to3DProfile(z: Float = 0) -> [SIMD3<Float>] {
        var profile: [SIMD3<Float>] = []
        for entity in entities {
            switch entity {
            case .line(let a, let b):
                if profile.isEmpty || simd_distance(profile.last!, SIMD3<Float>(a.x, a.y, z)) > 0.001 {
                    profile.append(SIMD3<Float>(a.x, a.y, z))
                }
                profile.append(SIMD3<Float>(b.x, b.y, z))
            case .point(let p):
                if profile.isEmpty || simd_distance(profile.last!, SIMD3<Float>(p.x, p.y, z)) > 0.001 {
                    profile.append(SIMD3<Float>(p.x, p.y, z))
                }
            default: break
            }
        }
        return profile
    }
}
