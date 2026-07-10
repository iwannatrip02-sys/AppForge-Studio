import Foundation

// MARK: - Biblioteca de Agujeros Estándar

/// Estándares de rosca soportados.
enum ThreadStandard: String, CaseIterable, Codable {
    case isoMetric = "ISO Métrico (M)"
    case isoMetricFine = "ISO Métrico Fino (MF)"
    case unc = "UNC (Unified Coarse)"
    case unf = "UNF (Unified Fine)"

    var description: String { rawValue }
}

/// Tipo de agujero.
enum HoleType: String, CaseIterable {
    case through = "Pasante"
    case blind = "Ciego"
    case countersunk = "Avellanado"
    case counterbored = "Con caja"

    var icon: String {
        switch self {
        case .through:      return "circle"
        case .blind:        return "circle.bottomhalf.filled"
        case .countersunk:  return "circle.dotted"
        case .counterbored: return "cylinder"
        }
    }
}

/// Especificación completa de un agujero.
struct HoleSpec: Identifiable {
    let id: UUID
    var standard: ThreadStandard
    var nominalSize: Double       // mm (M6 = 6.0)
    var pitch: Double             // mm (M6 gruesa = 1.0)
    var tapDrillDiameter: Double  // mm (broca para roscar)
    var clearanceDiameter: Double // mm (agujero pasante sin roscar)
    var type: HoleType
    var depth: Double             // mm (0 = pasante)
    var countersinkAngle: Double  // grados (típico 82° o 90°)
    var counterboreDiameter: Double
    var counterboreDepth: Double
    var label: String

    init(id: UUID = UUID(),
         standard: ThreadStandard = .isoMetric,
         nominalSize: Double,
         pitch: Double,
         tapDrillDiameter: Double? = nil,
         clearanceDiameter: Double? = nil,
         type: HoleType = .through,
         depth: Double = 0,
         countersinkAngle: Double = 90,
         counterboreDiameter: Double = 0,
         counterboreDepth: Double = 0) {
        self.id = id
        self.standard = standard
        self.nominalSize = nominalSize
        self.pitch = pitch
        self.tapDrillDiameter = tapDrillDiameter ?? (nominalSize - pitch)
        self.clearanceDiameter = clearanceDiameter ?? (nominalSize * 1.05)
        self.type = type
        self.depth = depth
        self.countersinkAngle = countersinkAngle
        self.counterboreDiameter = counterboreDiameter
        self.counterboreDepth = counterboreDepth
        self.label = HoleSpec.generateLabel(standard: standard, size: nominalSize,
                                             pitch: pitch, type: type)
    }

    private static func generateLabel(standard: ThreadStandard, size: Double,
                                       pitch: Double, type: HoleType) -> String {
        switch standard {
        case .isoMetric:
            return "M\(Int(size))×\(String(format: "%.1f", pitch)) \(type.rawValue)"
        case .isoMetricFine:
            return "MF\(Int(size))×\(String(format: "%.1f", pitch)) \(type.rawValue)"
        case .unc:
            return "\(size) UNC \(type.rawValue)"
        case .unf:
            return "\(size) UNF \(type.rawValue)"
        }
    }
}

// MARK: - Base de datos de agujeros estándar

/// Provee especificaciones de agujeros estándar para ingeniería mecánica.
/// Datos según ISO 724 (métrico) y ASME B1.1 (unificado).
enum HoleLibrary {

    // MARK: - ISO Métrico Grueso (M1.6 - M64)

    static let isoMetricSizes: [HoleSpec] = [
        // (nominal, pitch)
        (1.6, 0.35), (2.0, 0.40), (2.5, 0.45), (3.0, 0.50),
        (4.0, 0.70), (5.0, 0.80), (6.0, 1.00), (8.0, 1.25),
        (10.0, 1.50), (12.0, 1.75), (14.0, 2.00), (16.0, 2.00),
        (18.0, 2.50), (20.0, 2.50), (22.0, 2.50), (24.0, 3.00),
        (27.0, 3.00), (30.0, 3.50), (33.0, 3.50), (36.0, 4.00),
        (39.0, 4.00), (42.0, 4.50), (45.0, 4.50), (48.0, 5.00),
        (52.0, 5.00), (56.0, 5.50), (60.0, 5.50), (64.0, 6.00),
    ].map { size, pitch in
        HoleSpec(standard: .isoMetric, nominalSize: size, pitch: pitch)
    }

    // MARK: - ISO Métrico Fino (MF8 - MF64)

    static let isoMetricFineSizes: [HoleSpec] = [
        (8.0, 1.00), (10.0, 1.00), (10.0, 1.25), (12.0, 1.25),
        (12.0, 1.50), (14.0, 1.50), (16.0, 1.50), (18.0, 1.50),
        (20.0, 1.50), (20.0, 2.00), (24.0, 2.00), (30.0, 2.00),
        (36.0, 3.00), (42.0, 3.00), (48.0, 3.00), (56.0, 4.00),
        (64.0, 4.00),
    ].map { size, pitch in
        HoleSpec(standard: .isoMetricFine, nominalSize: size, pitch: pitch)
    }

    // MARK: - UNC (#1 - 1")

    static let uncSizes: [HoleSpec] = [
        (1.854, 0.397),  // #1-64
        (2.184, 0.454),  // #2-56
        (2.515, 0.529),  // #3-48
        (2.845, 0.635),  // #4-40
        (3.175, 0.635),  // #5-40
        (3.505, 0.794),  // #6-32
        (4.166, 0.794),  // #8-32
        (4.826, 1.058),  // #10-24
        (5.486, 1.058),  // #12-24
        (6.350, 1.270),  // 1/4"-20
        (7.938, 1.411),  // 5/16"-18
        (9.525, 1.588),  // 3/8"-16
        (11.113, 1.814), // 7/16"-14
        (12.700, 1.954), // 1/2"-13
        (14.288, 2.117), // 9/16"-12
        (15.875, 2.309), // 5/8"-11
        (19.050, 2.540), // 3/4"-10
        (22.225, 2.822), // 7/8"-9
        (25.400, 3.175), // 1"-8
    ].map { size, pitch in
        HoleSpec(standard: .unc, nominalSize: size, pitch: pitch)
    }

    // MARK: - UNF (#0 - 1")

    static let unfSizes: [HoleSpec] = [
        (1.524, 0.318),  // #0-80
        (1.854, 0.353),  // #1-72
        (2.184, 0.397),  // #2-64
        (2.515, 0.454),  // #3-56
        (2.845, 0.529),  // #4-48
        (3.175, 0.577),  // #5-44
        (3.505, 0.635),  // #6-40
        (4.166, 0.706),  // #8-36
        (4.826, 0.907),  // #10-32
        (6.350, 1.058),  // 1/4"-28
        (7.938, 1.270),  // 5/16"-24
        (9.525, 1.411),  // 3/8"-24
        (11.113, 1.588), // 7/16"-20
        (12.700, 1.814), // 1/2"-20
        (14.288, 1.814), // 9/16"-18
        (15.875, 1.814), // 5/8"-18
        (19.050, 2.117), // 3/4"-16
        (22.225, 2.309), // 7/8"-14
        (25.400, 2.540), // 1"-12
    ].map { size, pitch in
        HoleSpec(standard: .unf, nominalSize: size, pitch: pitch)
    }

    // MARK: - Consultas

    /// Todos los agujeros de un estándar
    static func sizes(for standard: ThreadStandard) -> [HoleSpec] {
        switch standard {
        case .isoMetric:     return isoMetricSizes
        case .isoMetricFine: return isoMetricFineSizes
        case .unc:           return uncSizes
        case .unf:           return unfSizes
        }
    }

    /// Busca un agujero por tamaño nominal
    static func find(standard: ThreadStandard, nominalSize: Double) -> HoleSpec? {
        sizes(for: standard).first { abs($0.nominalSize - nominalSize) < 0.01 }
    }

    /// Tamaños disponibles como strings para UI
    static func sizeLabels(for standard: ThreadStandard) -> [String] {
        sizes(for: standard).map { $0.label }
    }

    /// Diámetro de broca recomendado para roscar (mm)
    static func tapDrillFor(standard: ThreadStandard, nominalSize: Double) -> Double? {
        find(standard: standard, nominalSize: nominalSize)?.tapDrillDiameter
    }

    /// Diámetro de agujero de paso (sin roscar) (mm)
    static func clearanceFor(standard: ThreadStandard, nominalSize: Double) -> Double? {
        find(standard: standard, nominalSize: nominalSize)?.clearanceDiameter
    }
}
