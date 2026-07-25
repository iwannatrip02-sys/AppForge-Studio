import Foundation
import SwiftUI
import simd

@MainActor
class ToolViewModel: ObservableObject {
    @Published var selectedTool: CADTool = .select
    @Published var gridSnapEnabled: Bool = false
    @Published var measurementDistance: Float = 0
    @Published var measurementArea: Float = 0
    @Published var measurementVolume: Float = 0
    @Published var isPaintMode: Bool = false
    @Published var radius: Float = 0.1
    @Published var filletRadius: Float = 0.05
    @Published var chamferRadius: Float = 0.05
    @Published var shellThickness: Float = 0.02
    @Published var sweepHeight: Float = 0.5
    @Published var csgShapeAIndex: Int? = nil
    @Published var csgShapeBIndex: Int? = nil
    @Published var csgActiveOperation: CADTool? = nil
    @Published var symmetryEnabled: Bool = false
    
    // MOTORES DE MALLA RETIRADOS (auditoría 2026-07-25) junto con
    // `executeTool(mesh:)`, que era el sistema de herramientas PARALELO y
    // placebo del CAD:
    //   · Corte y Bisel operaban sobre `indices[0]`/`[1]` — una arista
    //     arbitraria del primer triángulo, nunca la que tocabas.
    //   · Los booleanos se aplicaban contra una COPIA de la propia malla
    //     desplazada 0.15 en X: no era una operación entre dos cuerpos.
    //   · Barrer usaba una ruta de 3 puntos hardcodeada.
    //   · Extruir, Loft y Revolución eran `break`.
    // Escribían la malla mostrada SIN tocar `cadShape`, dejando el render
    // desincronizado de la verdad de ingeniería y sin undo.
    //
    // Los caminos REALES viven en otra parte y son los únicos que quedan:
    // fillet/chamfer/shell → `BRepModeling` (B-rep OCCT exacto), booleanos →
    // `startCSGOperation(_:)` con selección A/B, barrido → `tubeAlongPath`,
    // revolución → `revolveProfile`, extrusión → `extrudedShapeForActiveRegion`.
    //
    // DEUDA CONOCIDA que esto deja a la vista: `measurementArea` y
    // `measurementVolume` solo se calculaban en la rama `.measure` de
    // `executeTool`, que ya era inalcanzable — la UI los muestra como
    // "Area: 0.00 mm²" / "Volumen: 0.000 mm³" fijos. Hay que calcularlos del
    // B-rep (`Shape.volume`, `Face.area`) o quitar esas dos líneas de la UI.
}
