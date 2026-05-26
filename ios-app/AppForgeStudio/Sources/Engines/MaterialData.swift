import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "MaterialData")
struct MaterialData: Codable, Identifiable {
    let id: UUID
    var name: String
    var albedo: SIMD3<Float>
    var metallic: Float
    var roughness: Float
    var normalStrength: Float
    var occlusion: Float
    var emission: SIMD3<Float>
    
    init(id: UUID = UUID(), name: String = "Material",
         albedo: SIMD3<Float> = SIMD3<Float>(0.8, 0.8, 0.8),
         metallic: Float = 0.0,
         roughness: Float = 0.5,
         normalStrength: Float = 1.0,
         occlusion: Float = 1.0,
         emission: SIMD3<Float> = SIMD3<Float>(0, 0, 0)) {
        self.id = id
        self.name = name
        self.albedo = albedo
        self.metallic = metallic
        self.roughness = roughness
        self.normalStrength = normalStrength
        self.occlusion = occlusion
        self.emission = emission
    }
    
    static let defaultMaterials: [MaterialData] = [
        MaterialData(name: "White Plastic", albedo: SIMD3<Float>(0.9, 0.9, 0.9), roughness: 0.8, metallic: 0.0),
        MaterialData(name: "Red Plastic", albedo: SIMD3<Float>(0.9, 0.2, 0.2), roughness: 0.7, metallic: 0.0),
        MaterialData(name: "Blue Plastic", albedo: SIMD3<Float>(0.2, 0.4, 0.9), roughness: 0.7, metallic: 0.0),
        MaterialData(name: "Gold", albedo: SIMD3<Float>(1.0, 0.84, 0.0), roughness: 0.1, metallic: 1.0),
        MaterialData(name: "Silver", albedo: SIMD3<Float>(0.9, 0.9, 0.95), roughness: 0.05, metallic: 1.0),
        MaterialData(name: "Copper", albedo: SIMD3<Float>(0.95, 0.64, 0.54), roughness: 0.1, metallic: 1.0),
        MaterialData(name: "Rubber", albedo: SIMD3<Float>(0.2, 0.2, 0.2), roughness: 0.95, metallic: 0.0),
        MaterialData(name: "Glass", albedo: SIMD3<Float>(0.8, 0.9, 1.0), roughness: 0.0, metallic: 0.0, emission: SIMD3<Float>(0.1, 0.15, 0.2))
    ]
}
