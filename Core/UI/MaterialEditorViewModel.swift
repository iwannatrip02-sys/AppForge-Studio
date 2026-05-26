import Foundation
import SwiftUI
import simd
import Combine
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "MaterialEditorViewModel")
@MainActor
class MaterialEditorViewModel: ObservableObject {
    let canvasVM: CanvasViewModel

    @Published var usesPBR: Bool = false

    @Published var albedoR: Float = 0.7
    @Published var albedoG: Float = 0.7
    @Published var albedoB: Float = 0.7
    @Published var metallic: Float = 0.0
    @Published var roughness: Float = 0.5
    @Published var ao: Float = 1.0
    @Published var emissionR: Float = 0.0
    @Published var emissionG: Float = 0.0
    @Published var emissionB: Float = 0.0
    @Published var emissionIntensity: Float = 0.0

    @Published var selectedPresetCategory: MaterialPresets.Preset.Category = .metal
    @Published var showPresetSheet: Bool = false

    private var isInternalUpdate: Bool = false
    private var cancellables = Set<AnyCancellable>()

    var selectedModel: Model? {
        guard let idx = canvasVM.selectedModelIndex,
              idx < canvasVM.scene.models.count else { return nil }
        return canvasVM.scene.models[idx]
    }

    var albedoColor: Color {
        get { Color(red: Double(albedoR), green: Double(albedoG), blue: Double(albedoB)) }
        set {
            guard let uiColor = UIColor(newValue).c, !isInternalUpdate else { return }
            albedoR = Float(uiColor.red)
            albedoG = Float(uiColor.green)
            albedoB = Float(uiColor.blue)
            pushToModel()
        }
    }

    var emissionColor: Color {
        get { Color(red: Double(emissionR), green: Double(emissionG), blue: Double(emissionB)) }
        set {
            guard let uiColor = UIColor(newValue).c else { return }
            emissionR = Float(uiColor.red)
            emissionG = Float(uiColor.green)
            emissionB = Float(uiColor.blue)
            pushToModel()
        }
    }

    var presetsForSelectedCategory: [MaterialPresets.Preset] {
        MaterialPresets.all.filter { $0.category == selectedPresetCategory }
    }

    var allCategories: [MaterialPresets.Preset.Category] {
        MaterialPresets.Preset.Category.allCases
    }

    init(canvasVM: CanvasViewModel) {
        self.canvasVM = canvasVM
        setupBindings()

        canvasVM.$scene
            .dropFirst()
            .sink { [weak self] _ in
                self?.pullFromModel()
            }
            .store(in: &cancellables)
    }

    private func setupBindings() {
        $usesPBR
            .dropFirst()
            .sink { [weak self] newValue in
                guard let self = self, !self.isInternalUpdate else { return }
                guard let idx = self.canvasVM.selectedModelIndex,
                      idx < self.canvasVM.scene.models.count else { return }
                self.canvasVM.scene.models[idx].usesPBR = newValue
                self.canvasVM.objectWillChange.send()
            }
            .store(in: &cancellables)

        $metallic.dropFirst().sink { [weak self] v in self?.pushScalarToModel(\.metallic, value: v) }.store(in: &cancellables)
        $roughness.dropFirst().sink { [weak self] v in self?.pushScalarToModel(\.roughness, value: v) }.store(in: &cancellables)
        $ao.dropFirst().sink { [weak self] v in self?.pushScalarToModel(\.ao, value: v) }.store(in: &cancellables)
        $emissionIntensity.dropFirst().sink { [weak self] v in self?.pushScalarToModel(\.emissionIntensity, value: v) }.store(in: &cancellables)

        $albedoR.dropFirst().sink { [weak self] _ in self?.pushAlbedoIfNeeded() }.store(in: &cancellables)
        $albedoG.dropFirst().sink { [weak self] _ in self?.pushAlbedoIfNeeded() }.store(in: &cancellables)
        $albedoB.dropFirst().sink { [weak self] _ in self?.pushAlbedoIfNeeded() }.store(in: &cancellables)
        $emissionR.dropFirst().sink { [weak self] _ in self?.pushEmissionIfNeeded() }.store(in: &cancellables)
        $emissionG.dropFirst().sink { [weak self] _ in self?.pushEmissionIfNeeded() }.store(in: &cancellables)
        $emissionB.dropFirst().sink { [weak self] _ in self?.pushEmissionIfNeeded() }.store(in: &cancellables)
    }

    private func pushScalarToModel(_ keyPath: WritableKeyPath<PBRMaterial, Float>, value: Float) {
        guard !isInternalUpdate, let idx = canvasVM.selectedModelIndex,
              idx < canvasVM.scene.models.count else { return }
        canvasVM.scene.models[idx].pbrMaterial[keyPath: keyPath] = value
        canvasVM.objectWillChange.send()
    }

    private func pushAlbedoIfNeeded() {
        guard !isInternalUpdate, let idx = canvasVM.selectedModelIndex,
              idx < canvasVM.scene.models.count else { return }
        canvasVM.scene.models[idx].pbrMaterial.albedo = SIMD3<Float>(albedoR, albedoG, albedoB)
        canvasVM.objectWillChange.send()
    }

    private func pushEmissionIfNeeded() {
        guard !isInternalUpdate, let idx = canvasVM.selectedModelIndex,
              idx < canvasVM.scene.models.count else { return }
        canvasVM.scene.models[idx].pbrMaterial.emission = SIMD3<Float>(emissionR, emissionG, emissionB)
        canvasVM.objectWillChange.send()
    }

    func pullFromModel() {
        guard let model = selectedModel else { return }
        isInternalUpdate = true
        defer { isInternalUpdate = false }

        usesPBR = model.usesPBR
        let mat = model.pbrMaterial
        albedoR = mat.albedo.x
        albedoG = mat.albedo.y
        albedoB = mat.albedo.z
        metallic = mat.metallic
        roughness = mat.roughness
        ao = mat.ao
        emissionR = mat.emission.x
        emissionG = mat.emission.y
        emissionB = mat.emission.z
        emissionIntensity = mat.emissionIntensity
    }

    func pushToModel() {
        guard let idx = canvasVM.selectedModelIndex,
              idx < canvasVM.scene.models.count else { return }
        canvasVM.scene.models[idx].pbrMaterial = PBRMaterial(
            albedo: SIMD3<Float>(albedoR, albedoG, albedoB),
            metallic: metallic,
            roughness: roughness,
            ao: ao,
            emission: SIMD3<Float>(emissionR, emissionG, emissionB),
            emissionIntensity: emissionIntensity
        )
        canvasVM.objectWillChange.send()
    }

    func applyPreset(_ preset: MaterialPresets.Preset) {
        guard let idx = canvasVM.selectedModelIndex,
              idx < canvasVM.scene.models.count else { return }
        canvasVM.scene.models[idx].pbrMaterial = preset.material
        canvasVM.objectWillChange.send()
        pullFromModel()
    }

    func togglePBR() {
        usesPBR.toggle()
    }
}

private extension UIColor {
    var c: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (r, g, b, a)
    }
}
