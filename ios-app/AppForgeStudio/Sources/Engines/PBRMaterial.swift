import Foundation
import simd
import Metal
import MetalKit
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "PBRMaterial")
// MARK: - Material PBR

struct PBRMaterial: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var albedo: SIMD3<Float>
    var roughness: Float
    var metalness: Float
    var ao: Float
    var normalScale: Float
    var emission: SIMD3<Float>
    var emissionIntensity: Float
    var albedoTexturePath: String?
    var normalTexturePath: String?
    var metallicTexturePath: String?
    var roughnessTexturePath: String?
    var aoTexturePath: String?
    var emissiveTexturePath: String?
    
    init(id: UUID = UUID(), name: String = "Material",
         albedo: SIMD3<Float> = SIMD3<Float>(0.8, 0.8, 0.8),
         roughness: Float = 0.5,
         metalness: Float = 0.0,
         ao: Float = 1.0,
         normalScale: Float = 1.0,
         emission: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
         emissionIntensity: Float = 0.0,
         albedoTexturePath: String? = nil,
         normalTexturePath: String? = nil,
         metallicTexturePath: String? = nil,
         roughnessTexturePath: String? = nil,
         aoTexturePath: String? = nil,
         emissiveTexturePath: String? = nil) {
        self.id = id
        self.name = name
        self.albedo = albedo
        self.roughness = roughness
        self.metalness = metalness
        self.ao = ao
        self.normalScale = normalScale
        self.emission = emission
        self.emissionIntensity = emissionIntensity
        self.albedoTexturePath = albedoTexturePath
        self.normalTexturePath = normalTexturePath
        self.metallicTexturePath = metallicTexturePath
        self.roughnessTexturePath = roughnessTexturePath
        self.aoTexturePath = aoTexturePath
        self.emissiveTexturePath = emissiveTexturePath
    }
    
    init(id: UUID = UUID(),
         name: String = "Material",
         albedo: SIMD3<Float> = SIMD3<Float>(0.8, 0.8, 0.8),
         roughness: Float = 0.5,
         metalness: Float = 0.0,
         ao: Float = 1.0,
         normalScale: Float = 1.0,
         emission: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
         emissionIntensity: Float = 0.0,
         textures: [PBRTextureSlot: String]) {
        self.id = id
        self.name = name
        self.albedo = albedo
        self.roughness = roughness
        self.metalness = metalness
        self.ao = ao
        self.normalScale = normalScale
        self.emission = emission
        self.emissionIntensity = emissionIntensity
        self.albedoTexturePath = textures[.albedo]
        self.normalTexturePath = textures[.normal]
        self.metallicTexturePath = textures[.metallic]
        self.roughnessTexturePath = textures[.roughness]
        self.aoTexturePath = textures[.ao]
        self.emissiveTexturePath = textures[.emissive]
    }
    
    enum PBRTextureSlot: String, Codable, CaseIterable {
        case albedo
        case normal
        case metallic
        case roughness
        case ao
        case emissive
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, roughness, metalness, ao, normalScale, emissionIntensity
        case albedoR, albedoG, albedoB
        case emissionR, emissionG, emissionB
        case albedoTexturePath, normalTexturePath, metallicTexturePath
        case roughnessTexturePath, aoTexturePath, emissiveTexturePath
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        roughness = try container.decode(Float.self, forKey: .roughness)
        metalness = try container.decode(Float.self, forKey: .metalness)
        ao = try container.decode(Float.self, forKey: .ao)
        normalScale = try container.decode(Float.self, forKey: .normalScale)
        emissionIntensity = try container.decode(Float.self, forKey: .emissionIntensity)
        let ar = try container.decode(Float.self, forKey: .albedoR)
        let ag = try container.decode(Float.self, forKey: .albedoG)
        let ab = try container.decode(Float.self, forKey: .albedoB)
        albedo = SIMD3<Float>(ar, ag, ab)
        let er = try container.decode(Float.self, forKey: .emissionR)
        let eg = try container.decode(Float.self, forKey: .emissionG)
        let eb = try container.decode(Float.self, forKey: .emissionB)
        emission = SIMD3<Float>(er, eg, eb)
        albedoTexturePath = try container.decodeIfPresent(String.self, forKey: .albedoTexturePath)
        normalTexturePath = try container.decodeIfPresent(String.self, forKey: .normalTexturePath)
        metallicTexturePath = try container.decodeIfPresent(String.self, forKey: .metallicTexturePath)
        roughnessTexturePath = try container.decodeIfPresent(String.self, forKey: .roughnessTexturePath)
        aoTexturePath = try container.decodeIfPresent(String.self, forKey: .aoTexturePath)
        emissiveTexturePath = try container.decodeIfPresent(String.self, forKey: .emissiveTexturePath)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(roughness, forKey: .roughness)
        try container.encode(metalness, forKey: .metalness)
        try container.encode(ao, forKey: .ao)
        try container.encode(normalScale, forKey: .normalScale)
        try container.encode(emissionIntensity, forKey: .emissionIntensity)
        try container.encode(albedo.x, forKey: .albedoR)
        try container.encode(albedo.y, forKey: .albedoG)
        try container.encode(albedo.z, forKey: .albedoB)
        try container.encode(emission.x, forKey: .emissionR)
        try container.encode(emission.y, forKey: .emissionG)
        try container.encode(emission.z, forKey: .emissionB)
        try container.encodeIfPresent(albedoTexturePath, forKey: .albedoTexturePath)
        try container.encodeIfPresent(normalTexturePath, forKey: .normalTexturePath)
        try container.encodeIfPresent(metallicTexturePath, forKey: .metallicTexturePath)
        try container.encodeIfPresent(roughnessTexturePath, forKey: .roughnessTexturePath)
        try container.encodeIfPresent(aoTexturePath, forKey: .aoTexturePath)
        try container.encodeIfPresent(emissiveTexturePath, forKey: .emissiveTexturePath)
    }
    
    func loadTextures(device: MTLDevice, loader: MTKTextureLoader) -> [String: MTLTexture]? {
        var textures: [String: MTLTexture] = [:]
        let slots: [(String?, String)] = [
            (albedoTexturePath, "albedo"),
            (normalTexturePath, "normal"),
            (metallicTexturePath, "metallic"),
            (roughnessTexturePath, "roughness"),
            (aoTexturePath, "ao"),
            (emissiveTexturePath, "emissive")
        ]
        for (path, slot) in slots {
            guard let path = path else { continue }
            let url = URL(fileURLWithPath: path)
            guard let texture = try? loader.newTexture(URL: url, options: nil) else { continue }
            textures[slot] = texture
        }
        return textures.isEmpty ? nil : textures
    }
}

// MARK: - Presets de materiales

struct PBRMaterialPresets {
    static let plastic = PBRMaterial(name: "Plastico", albedo: SIMD3<Float>(0.2, 0.6, 0.9), roughness: 0.4, metalness: 0.0, ao: 1.0)
    static let metal = PBRMaterial(name: "Metal", albedo: SIMD3<Float>(0.8, 0.8, 0.8), roughness: 0.2, metalness: 1.0, ao: 0.8)
    static let wood = PBRMaterial(name: "Madera", albedo: SIMD3<Float>(0.6, 0.4, 0.2), roughness: 0.8, metalness: 0.0, ao: 0.9)
    static let rubber = PBRMaterial(name: "Goma", albedo: SIMD3<Float>(0.1, 0.1, 0.1), roughness: 0.9, metalness: 0.0, ao: 0.7)
    static let stone = PBRMaterial(name: "Piedra", albedo: SIMD3<Float>(0.5, 0.5, 0.5), roughness: 0.85, metalness: 0.0, ao: 0.6)
    static let glass = PBRMaterial(name: "Cristal", albedo: SIMD3<Float>(0.9, 0.95, 1.0), roughness: 0.05, metalness: 0.0, ao: 0.3, emission: SIMD3<Float>(0.02, 0.03, 0.05), emissionIntensity: 0.2)
    static let gold = PBRMaterial(name: "Oro", albedo: SIMD3<Float>(1.0, 0.84, 0.0), roughness: 0.1, metalness: 1.0, ao: 0.7)
    static let copper = PBRMaterial(name: "Cobre", albedo: SIMD3<Float>(0.95, 0.64, 0.38), roughness: 0.15, metalness: 1.0, ao: 0.7)
    
    static let all: [PBRMaterial] = [plastic, metal, wood, rubber, stone, glass, gold, copper]
}

// MARK: - Material Manager

class MaterialManager: ObservableObject {
    @Published var materials: [PBRMaterial] = []
    @Published var selectedMaterialID: UUID?
    
    var selectedMaterial: PBRMaterial? {
        guard let id = selectedMaterialID else { return nil }
        return materials.first { $0.id == id }
    }
    
    private let defaultsKey = "AppForgeStudio.materials"
    
    init() {
        loadDefaults()
    }
    
    func loadDefaults() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([PBRMaterial].self, from: data) {
            materials = decoded
        } else {
            materials = MaterialPresets.all
        }
        selectedMaterialID = materials.first?.id
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(materials) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
    
    func addMaterial(name: String = "Nuevo Material", from source: PBRMaterial? = nil) {
        let base = source ?? MaterialPresets.plastic
        let material = PBRMaterial(name: name, albedo: base.albedo, roughness: base.roughness,
                                    metalness: base.metalness, ao: base.ao, normalScale: base.normalScale,
                                    emission: base.emission, emissionIntensity: base.emissionIntensity,
                                    albedoTexturePath: base.albedoTexturePath,
                                    normalTexturePath: base.normalTexturePath,
                                    metallicTexturePath: base.metallicTexturePath,
                                    roughnessTexturePath: base.roughnessTexturePath,
                                    aoTexturePath: base.aoTexturePath,
                                    emissiveTexturePath: base.emissiveTexturePath)
        materials.append(material)
        selectedMaterialID = material.id
        save()
    }
    
    func duplicateMaterial(_ id: UUID) {
        guard let source = materials.first(where: { $0.id == id }) else { return }
        addMaterial(name: source.name + " (copia)", from: source)
    }
    
    func deleteMaterial(_ id: UUID) {
        materials.removeAll { $0.id == id }
        if selectedMaterialID == id {
            selectedMaterialID = materials.first?.id
        }
        save()
    }
    
    func updateMaterial(_ material: PBRMaterial) {
        guard let idx = materials.firstIndex(where: { $0.id == material.id }) else { return }
        materials[idx] = material
        save()
    }
}