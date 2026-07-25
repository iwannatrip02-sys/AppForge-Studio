import Foundation
import SwiftUI
import simd

@MainActor
class ToolViewModel: ObservableObject {
    @Published var selectedTool: CADTool = .select
    @Published var gridSnapEnabled: Bool = false
    /// Distancia entre los dos puntos tocados en la medición libre. El ÁREA y el
    /// VOLUMEN ya no viven aquí: los calcula `MeasureService` desde el B-rep de
    /// lo seleccionado (eran `Float` fijos en 0 alimentados por una rama
    /// inalcanzable del motor de malla placebo — números falsos en pantalla).
    @Published var measurementDistance: Float = 0
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
    // La deuda que esto dejó a la vista (`Area: 0.00 mm²` / `Volumen: 0.000 mm³`
    // fijos en la barra de Medir) quedó SALDADA: `MeasureService` los calcula
    // ahora desde el B-rep de lo seleccionado — cuerpo, cara o arista.
}
