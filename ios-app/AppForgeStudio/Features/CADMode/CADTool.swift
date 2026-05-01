import Foundation

enum CADTool: String, CaseIterable, Identifiable {
    case select = "Select"
    case move = "Move"
    case rotate = "Rotate"
    case scale = "Scale"
    case extrude = "Extrude"
    case revolve = "Revolve"
    case fillet = "Fillet"
    case chamfer = "Chamfer"
    case booleanUnion = "Boolean Union"
    case booleanSubtract = "Boolean Subtract"
    case booleanIntersect = "Boolean Intersect"
    case sketch = "Sketch"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .select: return "cursorarrow"
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .rotate: return "rotate.3d"
        case .scale: return "arrow.up.backward.and.arrow.down.forward"
        case .extrude: return "cube.transparent"
        case .revolve: return "rotate.3d"
        case .fillet: return "point.topleft.down.curvedto.point.bottomright.up"
        case .chamfer: return "rectangle.and.pencil.and.ellipsis"
        case .booleanUnion: return "square.on.square"
        case .booleanSubtract: return "square.slash"
        case .booleanIntersect: return "square.on.circle"
        case .sketch: return "pencil.tip"
        }
    }
}
