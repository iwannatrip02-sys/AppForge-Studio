import SwiftUI
import simd

/// 3D transformation gizmo rendered via Metal overlay.
/// Provides translate arrows, rotate arcs, and scale handles for selected objects.
struct ViewportGizmo {
    enum Mode: String, CaseIterable {
        case translate, rotate, scale
    }
    
    enum Axis: String, CaseIterable {
        case x, y, z, all
    }
    
    var mode: Mode = .translate
    var activeAxis: Axis?
    var position: SIMD3<Float>
    var isVisible: Bool = false
    
    // Colors per axis
    static let axisColors: [Axis: SIMD4<Float>] = [
        .x: SIMD4<Float>(1, 0.2, 0.2, 1),
        .y: SIMD4<Float>(0.2, 1, 0.2, 1),
        .z: SIMD4<Float>(0.2, 0.2, 1, 1),
        .all: SIMD4<Float>(1, 1, 1, 0.5),
    ]
    
    static let handleLength: Float = 1.0
    static let handleRadius: Float = 0.03
    static let arrowHeadRadius: Float = 0.08
}

/// Navigation cube rendered in viewport corner.
struct ViewCube {
    enum Face: CaseIterable {
        case front, back, left, right, top, bottom
    }
    
    var isVisible: Bool = true
    var highlightedFace: Face?
    var position: CGPoint = CGPoint(x: 40, y: 40)
    var size: CGFloat = 120
    
    func cameraDirection(for face: Face) -> (position: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) {
        switch face {
        case .front:  return (SIMD3<Float>(0, 0, 5), .zero, SIMD3<Float>(0, 1, 0))
        case .back:   return (SIMD3<Float>(0, 0, -5), .zero, SIMD3<Float>(0, 1, 0))
        case .left:   return (SIMD3<Float>(-5, 0, 0), .zero, SIMD3<Float>(0, 1, 0))
        case .right:  return (SIMD3<Float>(5, 0, 0), .zero, SIMD3<Float>(0, 1, 0))
        case .top:    return (SIMD3<Float>(0, 5, 0), .zero, SIMD3<Float>(0, 0, -1))
        case .bottom: return (SIMD3<Float>(0, -5, 0), .zero, SIMD3<Float>(0, 0, 1))
        }
    }
}

/// Adaptive ground grid with logarithmic subdivision.
struct AdaptiveGrid {
    var isVisible: Bool = true
    var size: Float = 20
    var majorDivisions: Int = 10
    var minorDivisions: Int = 5
    var color: SIMD4<Float> = SIMD4<Float>(0.3, 0.3, 0.3, 0.5)
    var originColor: SIMD4<Float> = SIMD4<Float>(0.5, 0.5, 0.5, 0.8)
}

/// Display mode for the 3D viewport.
enum DisplayMode: String, CaseIterable {
    case shaded
    case wireframe
    case shadedWithEdges
    case xray
}
