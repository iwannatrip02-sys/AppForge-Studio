import Foundation

enum CADTool: String, CaseIterable, Identifiable {
    case select = "Select"
    case move = "Move"
    case rotate = "Rotate"
    case scale = "Scale"
    case extrude = "Extrude"
    case revolve = "Revolve"
    case loopCut = "Loop Cut"
    case bevel = "Bevel"
    case booleanUnion = "Boolean Union"
    case booleanSubtract = "Boolean Subtract"
    case booleanIntersect = "Boolean Intersect"
    case pushPull = "Push/Pull"
    case hole = "Hole"
    case fillet = "Fillet"
    case chamfer = "Chamfer"
    case shell = "Shell"
    case loft = "Loft"
    case sweep = "Sweep"
    case measure = "Measure"
    case sketch = "Sketch"
    case line = "Line"
    case circle = "Circle"
    case rectangle = "Rectangle"
    case arc = "Arc"
    case dimension = "Dimension"
    case constraint = "Constraint"

    var id: String { rawValue }

    /// Nombre visible en la UI (convención: español; rawValue queda como id estable).
    var displayName: String {
        switch self {
        case .select: return "Seleccionar"
        case .move: return "Mover"
        case .rotate: return "Rotar"
        case .scale: return "Escalar"
        case .extrude: return "Extruir"
        case .revolve: return "Revolución"
        case .loopCut: return "Corte"
        case .bevel: return "Bisel"
        case .booleanUnion: return "Unir"
        case .booleanSubtract: return "Restar"
        case .booleanIntersect: return "Intersecar"
        case .pushPull: return "Push/Pull"
        case .hole: return "Agujero"
        case .fillet: return "Redondear"
        case .chamfer: return "Chaflán"
        case .shell: return "Vaciar"
        case .loft: return "Loft"
        case .sweep: return "Barrer"
        case .measure: return "Medir"
        case .sketch: return "Boceto"
        case .line: return "Línea"
        case .circle: return "Círculo"
        case .rectangle: return "Rectángulo"
        case .arc: return "Arco"
        case .dimension: return "Cota"
        case .constraint: return "Restricción"
        }
    }

    var isSketchTool: Bool {
        switch self {
        case .line, .circle, .rectangle, .arc, .dimension, .constraint:
            return true
        default:
            return false
        }
    }

    var icon: String {
        switch self {
        case .select: return "cursorarrow"
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .rotate: return "rotate.3d"
        case .scale: return "arrow.up.backward.and.arrow.down.forward"
        case .extrude: return "cube.transparent"
        case .revolve: return "rotate.3d"
        case .loopCut: return "scissors"
        case .bevel: return "point.topleft.down.curvedto.point.bottomright.up"
        case .booleanUnion: return "square.on.square"
        case .booleanSubtract: return "square.slash"
        case .booleanIntersect: return "square.on.circle"
        case .pushPull: return "square.stack.3d.up"
        case .hole: return "circle.circle"
        case .fillet: return "point.topleft.down.curvedto.point.bottomright.up"
        case .chamfer: return "rectangle.and.pencil.and.ellipsis"
        case .shell: return "rectangle.3.group"
        case .loft: return "rectangle.stack"
        case .sweep: return "arrow.triangle.swap"
        case .measure: return "ruler"
        case .sketch: return "pencil.tip"
        case .line: return "line.diagonal"
        case .circle: return "circle"
        case .rectangle: return "rectangle"
        case .arc: return "point.topleft.down.curvedto.point.bottomright.up"
        case .dimension: return "text.magnifyingglass"
        case .constraint: return "link"
        }
    }
}
