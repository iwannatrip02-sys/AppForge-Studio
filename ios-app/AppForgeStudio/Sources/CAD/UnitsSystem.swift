import Foundation

// MARK: - Sistema de Unidades de Ingeniería

/// Unidad de longitud para el sistema CAD.
/// Todo el modelado interno es en milímetros (como OCCT y todos los kernels CAD reales).
/// La UI muestra en la unidad seleccionada por el usuario.
enum CADUnit: String, CaseIterable, Codable {
    case mm = "Milímetros"
    case cm = "Centímetros"
    case m  = "Metros"
    case inch = "Pulgadas"

    /// Factor de conversión: 1 unidad de display = X milímetros
    var toMillimeters: Double {
        switch self {
        case .mm:   return 1.0
        case .cm:   return 10.0
        case .m:    return 1000.0
        case .inch: return 25.4
        }
    }

    /// Factor inverso: 1 milímetro = X unidades de display
    var fromMillimeters: Double {
        1.0 / toMillimeters
    }

    /// Símbolo para mostrar en cotas y UI
    var symbol: String {
        switch self {
        case .mm:   return "mm"
        case .cm:   return "cm"
        case .m:    return "m"
        case .inch: return "in"
        }
    }

    /// Precisión decimal recomendada para mostrar valores
    var displayPrecision: Int {
        switch self {
        case .mm:   return 2
        case .cm:   return 2
        case .m:    return 3
        case .inch: return 3
        }
    }

    /// Pasos de grid típicos en esta unidad
    var defaultGridSteps: [Double] {
        switch self {
        case .mm:   return [0.5, 1, 5, 10, 25, 50]
        case .cm:   return [0.1, 0.5, 1, 2, 5]
        case .m:    return [0.01, 0.05, 0.1, 0.5, 1]
        case .inch: return [1.0/64, 1.0/32, 1.0/16, 1.0/8, 1.0/4, 1.0/2, 1]
        }
    }
}

// MARK: - Configuración de proyecto

/// Configuración persistente de un proyecto de ingeniería.
/// Controla unidades, grid, snapping, y precisión.
struct ProjectConfig: Codable {
    var displayUnit: CADUnit = .mm
    var gridStep: Double = 1.0        // en mm internos
    var snapToGrid: Bool = true
    var snapTolerance: Double = 0.5    // en mm internos
    var angleSnapDegrees: Double = 5.0 // snap angular (0 = sin snap)
    var autoConstraints: Bool = true
    var showDimensions: Bool = true
    var dimensionColor: SIMD4<Float> = SIMD4<Float>(1.0, 0.48, 0.27, 1.0)

    /// Convierte un valor interno (mm) a la unidad de display
    func toDisplay(_ mmValue: Double) -> Double {
        mmValue * displayUnit.fromMillimeters
    }

    /// Convierte un valor de display a mm internos
    func toInternal(_ displayValue: Double) -> Double {
        displayValue * displayUnit.toMillimeters
    }

    /// Formatea un valor interno (mm) para mostrar en UI
    func format(_ mmValue: Double) -> String {
        let display = toDisplay(mmValue)
        return String(format: "%.\(displayUnit.displayPrecision)f %@",
                      display, displayUnit.symbol)
    }

    /// Formatea un valor angular
    static func formatAngle(_ degrees: Double) -> String {
        String(format: "%.1f°", degrees)
    }

    /// Snap de un valor al paso de grid más cercano (en mm)
    func snapValue(_ mmValue: Double) -> Double {
        guard snapToGrid, gridStep > 0 else { return mmValue }
        return round(mmValue / gridStep) * gridStep
    }

    /// Snap de un punto 3D (en mm) al grid
    func snapPoint(_ point: SIMD3<Double>) -> SIMD3<Double> {
        guard snapToGrid, gridStep > 0 else { return point }
        return SIMD3<Double>(
            round(point.x / gridStep) * gridStep,
            round(point.y / gridStep) * gridStep,
            round(point.z / gridStep) * gridStep
        )
    }

    /// Snap de un ángulo al paso configurado
    func snapAngle(_ degrees: Double) -> Double {
        guard angleSnapDegrees > 0 else { return degrees }
        return round(degrees / angleSnapDegrees) * angleSnapDegrees
    }

    static let `default` = ProjectConfig()
}

// MARK: - Observabilidad

/// ViewModel global para configuración de proyecto.
/// ObservableObject → SwiftUI reacciona a cambios de unidad/grid.
@MainActor
final class ProjectSettings: ObservableObject {
    static let shared = ProjectSettings()

    @Published var config = ProjectConfig()

    private init() {}

    /// Cambia la unidad de display y ajusta el grid step al valor por defecto más cercano
    func setUnit(_ unit: CADUnit) {
        config.displayUnit = unit
        config.gridStep = unit.defaultGridSteps[1] * unit.toMillimeters
    }

    /// Cambia el paso de grid (en mm internos)
    func setGridStep(_ mmStep: Double) {
        config.gridStep = mmStep
    }

    func toggleSnap() {
        config.snapToGrid.toggle()
    }

    func toggleAutoConstraints() {
        config.autoConstraints.toggle()
    }

    // MARK: - Persistencia

    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        try data.write(to: url)
    }

    func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        config = try JSONDecoder().decode(ProjectConfig.self, from: data)
    }
}
