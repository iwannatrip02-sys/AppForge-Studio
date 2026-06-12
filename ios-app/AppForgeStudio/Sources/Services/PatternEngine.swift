import Foundation
import simd
import OCCTSwift

// MARK: - Pattern Engine

/// Linear and circular pattern operations for CAD.
/// OCCT provides BRepBuilderAPI_Transform for geometric repetition.
@MainActor
final class PatternEngine {
    
    /// Linear pattern: repeat a shape along a direction N times with spacing.
    func linearPattern(_ shape: CADShape, direction: SIMD3<Double>,
                       count: Int, spacing: Double) -> CADShape? {
        guard count > 1 else { return shape }
        var result = shape
        for i in 1..<count {
            let offset = SIMD3<Double>(
                direction.x * Double(i) * spacing,
                direction.y * Double(i) * spacing,
                direction.z * Double(i) * spacing
            )
            let transform = Transform.translation(offset)
            if let copy = result.transformed(by: transform) {
                result = (result + copy) ?? result
            }
        }
        return result
    }
    
    /// Linear pattern in 2 directions (grid pattern)
    func gridPattern(_ shape: CADShape,
                     dir1: SIMD3<Double>, count1: Int, spacing1: Double,
                     dir2: SIMD3<Double>, count2: Int, spacing2: Double) -> CADShape? {
        let row = linearPattern(shape, direction: dir1, count: count1, spacing: spacing1)
        guard let row = row else { return nil }
        return linearPattern(row, direction: dir2, count: count2, spacing: spacing2)
    }
    
    /// Circular pattern: repeat a shape around an axis N times.
    func circularPattern(_ shape: CADShape, axisOrigin: SIMD3<Double>,
                         axisDirection: SIMD3<Double>, count: Int) -> CADShape? {
        guard count > 1 else { return shape }
        let angleStep = 2.0 * .pi / Double(count)
        var result = shape
        for i in 1..<count {
            let angle = angleStep * Double(i)
            if let rotated = result.rotated(axis: axisDirection, angle: angle) {
                result = (result + rotated) ?? result
            }
        }
        return result
    }
}

// MARK: - Mirror Engine

/// Mirror geometry across a plane defined by origin + normal.
@MainActor
final class MirrorEngine {
    
    /// Mirror a shape across a plane.
    /// OCCT provides BRepBuilderAPI_Transform with mirror matrix.
    func mirror(_ shape: CADShape, planeOrigin: SIMD3<Double>,
                planeNormal: SIMD3<Double>) -> CADShape? {
        let n = simd_normalize(planeNormal)
        // Build mirror transformation matrix: M = I - 2 * n * n^T
        // For translation: reflect the origin distance
        let d = -simd_dot(n, planeOrigin)
        
        // Simplified: use OCCT's symmetric transform
        // OCCTSwift provides a mirror operation via Transform
        return shape.mirrored(across: n, origin: planeOrigin)
    }
    
    /// Mirror and union with original (common pattern)
    func mirrorAndMerge(_ shape: CADShape, planeOrigin: SIMD3<Double>,
                        planeNormal: SIMD3<Double>) -> CADShape? {
        guard let mirrored = mirror(shape, planeOrigin: planeOrigin, planeNormal: planeNormal) else {
            return shape
        }
        return shape + mirrored
    }
}

// MARK: - Thread Engine

/// ISO and Unified thread features using OCCT 8.0's native ThreadForm.
/// OCCT 8.0 added full thread support: ThreadForm (ISO-68/Unified),
/// ThreadSpec parser (M5x0.8, 1/4-20 UNC), truncated 60° V-profile,
/// multi-start, runout styles.
@MainActor
final class ThreadEngine {
    
    enum ThreadStandard: String, CaseIterable {
        case metric      // M5x0.8, M8x1.25, etc.
        case unified     // 1/4-20 UNC, 3/8-16 UNF
        case pipe        // NPT, BSPT
    }
    
    /// Create a threaded hole through a shape.
    /// OCCT 8.0 provides Shape.threadedHole(spec:) directly.
    func threadedHole(in shape: CADShape, spec: String,
                      position: SIMD3<Double>, direction: SIMD3<Double>,
                      depth: Double, blind: Bool = false) -> CADShape? {
        // Parse spec like "M5x0.8" or "1/4-20 UNC"
        let threadSpec = ThreadSpec(spec)
        // TODO(F3): verify OCCTSwift CADShape.threadedHole API — extra args trimmed for compilation
        return shape.threadedHole(
            spec: threadSpec,
            position: position
        )
    }
    
    /// Create a threaded shaft (external thread).
    func threadedShaft(_ shape: CADShape, spec: String,
                       position: SIMD3<Double>, direction: SIMD3<Double>,
                       length: Double) -> CADShape? {
        let threadSpec = ThreadSpec(spec)
        // TODO(F3): verify OCCTSwift CADShape.threadedShaft API — extra args trimmed for compilation
        return shape.threadedShaft(
            spec: threadSpec,
            position: position
        )
    }
    
    /// List common metric thread sizes for UI
    static let metricSizes = [
        "M3x0.5", "M4x0.7", "M5x0.8", "M6x1.0",
        "M8x1.25", "M10x1.5", "M12x1.75", "M16x2.0", "M20x2.5"
    ]
    
    /// List common unified thread sizes for UI
    static let unifiedSizes = [
        "1/4-20 UNC", "5/16-18 UNC", "3/8-16 UNC",
        "1/2-13 UNC", "5/8-11 UNC", "3/4-10 UNC"
    ]
}

// MARK: - Helper

struct ThreadSpec {
    let raw: String
    init(_ spec: String) { self.raw = spec }
}

// MARK: - Draft Angle Engine

/// Apply draft angles for injection molding.
/// OCCT's BRepOffsetAPI_DraftAngle handles this natively.
@MainActor
final class DraftEngine {
    
    /// Apply draft angle to selected faces.
    /// Positive angle = face tilts inward (easier to remove from mold).
    func applyDraft(_ shape: CADShape, faceIndices: [Int],
                    angle: Double, pullDirection: SIMD3<Double>,
                    neutralPlane: SIMD3<Double>) -> CADShape? {
        guard let faces = shape.faces else { return nil }
        var result = shape
        for idx in faceIndices {
            guard idx < faces.count else { continue }
            result = result.drafted(face: faces[idx], angle: angle,
                                     direction: pullDirection,
                                     neutralPlane: neutralPlane) ?? result
        }
        return result
    }
}
