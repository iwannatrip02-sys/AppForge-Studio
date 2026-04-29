import Foundation

enum CADTool: String, CaseIterable {
    case select = "Seleccionar"
    case move = "Mover"
    case rotate = "Rotar"
    case scale = "Escalar"
    case extrude = "Extruir"
    case loopCut = "Loop Cut"
    case bevel = "Bisel"
    case boolean = "Booleano"
    case measure = "Medir"
    case fillet = "Fillet"
    case chamfer = "Chamfer"
    case shell = "Shell"
    case loft = "Loft"
    case sweep = "Sweep"
    // Sketch 2D tools
    case line = "Linea"
    case circle = "Circulo"
    case rectangle = "Rectangulo"
    case arc = "Arco"
    case dimension = "Dimension"
    case constraint = "Constraint"
}
