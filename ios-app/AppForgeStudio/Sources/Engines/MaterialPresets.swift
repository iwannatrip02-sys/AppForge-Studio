import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "MaterialPresets")
struct MaterialPresets {

    struct Preset: Identifiable, Equatable {
        let id: String
        let name: String
        let category: Category
        let material: PBRMaterial

        enum Category: String, CaseIterable, Identifiable {
            case metal = "Metales"
            case plastic = "Plasticos"
            case fabric = "Telas"
            case stone = "Piedras"
            case wood = "Madera"
            case glass = "Vidrio"
            case other = "Otros"

            var id: String { rawValue }
        }
    }

    static let all: [Preset] = metals + plastics + fabrics + stones + woods + glasses + others

    static let metals: [Preset] = [
        Preset(id: "gold", name: "Oro", category: .metal,
               material: PBRMaterial(albedo: SIMD3<Float>(1.0, 0.71, 0.29), metallic: 1.0, roughness: 0.15, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "silver", name: "Plata", category: .metal,
               material: PBRMaterial(albedo: SIMD3<Float>(0.95, 0.93, 0.88), metallic: 1.0, roughness: 0.12, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "copper", name: "Cobre", category: .metal,
               material: PBRMaterial(albedo: SIMD3<Float>(0.95, 0.53, 0.33), metallic: 1.0, roughness: 0.18, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "iron", name: "Hierro", category: .metal,
               material: PBRMaterial(albedo: SIMD3<Float>(0.52, 0.49, 0.45), metallic: 1.0, roughness: 0.35, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "steel", name: "Acero", category: .metal,
               material: PBRMaterial(albedo: SIMD3<Float>(0.65, 0.65, 0.66), metallic: 0.9, roughness: 0.25, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "aluminum", name: "Aluminio", category: .metal,
               material: PBRMaterial(albedo: SIMD3<Float>(0.82, 0.83, 0.84), metallic: 0.95, roughness: 0.20, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "chrome", name: "Cromo", category: .metal,
               material: PBRMaterial(albedo: SIMD3<Float>(0.55, 0.55, 0.55), metallic: 1.0, roughness: 0.05, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "titanium", name: "Titanio", category: .metal,
               material: PBRMaterial(albedo: SIMD3<Float>(0.60, 0.56, 0.52), metallic: 0.85, roughness: 0.30, ao: 1.0, emission: .zero, emissionIntensity: 0)),
    ]

    static let plastics: [Preset] = [
        Preset(id: "plastic_white", name: "Plastico Blanco", category: .plastic,
               material: PBRMaterial(albedo: SIMD3<Float>(0.85, 0.85, 0.85), metallic: 0.0, roughness: 0.40, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "plastic_black", name: "Plastico Negro", category: .plastic,
               material: PBRMaterial(albedo: SIMD3<Float>(0.08, 0.08, 0.08), metallic: 0.0, roughness: 0.35, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "rubber", name: "Goma", category: .plastic,
               material: PBRMaterial(albedo: SIMD3<Float>(0.12, 0.12, 0.12), metallic: 0.0, roughness: 0.85, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "carbon_fiber", name: "Fibra de Carbono", category: .plastic,
               material: PBRMaterial(albedo: SIMD3<Float>(0.1, 0.1, 0.1), metallic: 0.2, roughness: 0.55, ao: 1.0, emission: .zero, emissionIntensity: 0)),
    ]

    static let fabrics: [Preset] = [
        Preset(id: "leather", name: "Cuero", category: .fabric,
               material: PBRMaterial(albedo: SIMD3<Float>(0.31, 0.17, 0.1), metallic: 0.0, roughness: 0.75, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "velvet", name: "Terciopelo Rojo", category: .fabric,
               material: PBRMaterial(albedo: SIMD3<Float>(0.65, 0.05, 0.05), metallic: 0.0, roughness: 0.90, ao: 1.0, emission: .zero, emissionIntensity: 0)),
    ]

    static let stones: [Preset] = [
        Preset(id: "marble", name: "Marmol", category: .stone,
               material: PBRMaterial(albedo: SIMD3<Float>(0.85, 0.82, 0.78), metallic: 0.05, roughness: 0.25, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "granite", name: "Granito", category: .stone,
               material: PBRMaterial(albedo: SIMD3<Float>(0.55, 0.52, 0.50), metallic: 0.1, roughness: 0.45, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "concrete", name: "Concreto", category: .stone,
               material: PBRMaterial(albedo: SIMD3<Float>(0.60, 0.60, 0.59), metallic: 0.0, roughness: 0.65, ao: 1.0, emission: .zero, emissionIntensity: 0)),
    ]

    static let woods: [Preset] = [
        Preset(id: "oak", name: "Roble", category: .wood,
               material: PBRMaterial(albedo: SIMD3<Float>(0.50, 0.32, 0.18), metallic: 0.0, roughness: 0.60, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "walnut", name: "Nogal", category: .wood,
               material: PBRMaterial(albedo: SIMD3<Float>(0.26, 0.15, 0.08), metallic: 0.0, roughness: 0.55, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "pine", name: "Pino", category: .wood,
               material: PBRMaterial(albedo: SIMD3<Float>(0.70, 0.55, 0.30), metallic: 0.0, roughness: 0.65, ao: 1.0, emission: .zero, emissionIntensity: 0)),
    ]

    static let glasses: [Preset] = [
        Preset(id: "glass", name: "Vidrio", category: .glass,
               material: PBRMaterial(albedo: SIMD3<Float>(0.95, 0.95, 0.95), metallic: 0.0, roughness: 0.08, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "obsidian", name: "Obsidiana", category: .glass,
               material: PBRMaterial(albedo: SIMD3<Float>(0.06, 0.04, 0.08), metallic: 0.1, roughness: 0.05, ao: 1.0, emission: .zero, emissionIntensity: 0)),
    ]

    static let others: [Preset] = [
        Preset(id: "emerald", name: "Esmeralda", category: .other,
               material: PBRMaterial(albedo: SIMD3<Float>(0.0, 0.67, 0.29), metallic: 0.2, roughness: 0.12, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "sapphire", name: "Zafiro", category: .other,
               material: PBRMaterial(albedo: SIMD3<Float>(0.06, 0.32, 0.73), metallic: 0.2, roughness: 0.10, ao: 1.0, emission: .zero, emissionIntensity: 0)),
        Preset(id: "neon_blue", name: "Neon Azul", category: .other,
               material: PBRMaterial(albedo: SIMD3<Float>(0.1, 0.3, 0.8), metallic: 0.0, roughness: 0.3, ao: 1.0, emission: SIMD3<Float>(0.0, 0.3, 1.0), emissionIntensity: 2.0)),
        Preset(id: "neon_green", name: "Neon Verde", category: .other,
               material: PBRMaterial(albedo: SIMD3<Float>(0.1, 0.8, 0.3), metallic: 0.0, roughness: 0.3, ao: 1.0, emission: SIMD3<Float>(0.0, 1.0, 0.3), emissionIntensity: 2.0)),
        Preset(id: "ceramic_white", name: "Ceramica Blanca", category: .other,
               material: PBRMaterial(albedo: SIMD3<Float>(0.92, 0.91, 0.89), metallic: 0.0, roughness: 0.22, ao: 1.0, emission: .zero, emissionIntensity: 0)),
    ]
}
