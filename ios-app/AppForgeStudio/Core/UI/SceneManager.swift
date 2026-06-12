import Foundation
import Combine
import OSLog
import Satin

/// Gestiona la escena 3D con soporte de capas, visibilidad, selección y persistencia
final class SceneManager: ObservableObject {
    static let shared = SceneManager()
    
    @Published var layers: [SceneLayer] = []
    @Published var activeLayerId: UUID?
    @Published var selectedMeshId: UUID?
    @Published var sceneBounds: BoundingBox = BoundingBox()
    
    private let logger = Logger(subsystem: "com.appforgestudio", category: "SceneManager")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Layer Management
    
    func addLayer(name: String? = nil) -> SceneLayer {
        let layerName = name ?? "Layer \(layers.count + 1)"
        let layer = SceneLayer(name: layerName)
        layers.append(layer)
        if activeLayerId == nil {
            activeLayerId = layer.id
        }
        return layer
    }
    
    func removeLayer(id: UUID) {
        logger.debug("Removing layer: \(id.uuidString)")
        layers.removeAll { $0.id == id }
        if activeLayerId == id {
            activeLayerId = layers.first?.id
        }
    }
    
    func toggleLayerVisibility(_ id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else {
            logger.warning("toggleLayerVisibility: layer not found \(id.uuidString)")
            return
        }
        layers[index].isVisible.toggle()
        logger.debug("Toggled visibility for layer \(id.uuidString), now visible: \(layers[index].isVisible)")
    }
    
    func visibleMeshes() -> [ModelWrapper] {
        return self.layers
            .filter { $0.isVisible }
            .flatMap { $0.meshes }
    }
    
    // MARK: - Selection
    
    func selectMesh(_ id: UUID?) {
        selectedMeshId = id
    }
    
    // MARK: - Persistence (Codable wrappers)
    
    func saveToFile(url: URL) throws {
        let snapshot = SceneSnapshot(
            layers: layers,
            activeLayerId: activeLayerId,
            selectedMeshId: selectedMeshId
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(snapshot)
        try data.write(to: url)
    }
    
    func loadFromFile(url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let snapshot = try decoder.decode(SceneSnapshot.self, from: data)
        self.layers = snapshot.layers
        self.activeLayerId = snapshot.activeLayerId
        self.selectedMeshId = snapshot.selectedMeshId
    }
}

// MARK: - Supporting Types

struct SceneLayer: Identifiable, Codable {
    let id: UUID
    var name: String
    var isVisible: Bool
    var meshes: [ModelWrapper]
    
    init(id: UUID = UUID(), name: String, isVisible: Bool = true, meshes: [ModelWrapper] = []) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.meshes = meshes
    }
}

struct ModelWrapper: Identifiable, Codable {
    let id: UUID
    var name: String
    var transform: TransformWrapper
    var materialIndex: Int
    
    init(model: Model) {
        self.id = model.id
        self.name = model.name
        self.transform = TransformWrapper(
            position: model.transform.position,
            rotation: model.transform.rotation,
            scale: model.transform.scale
        )
        self.materialIndex = model.materialIndex
    }
}

struct TransformWrapper: Codable {
    var position: SIMD3<Float>
    var rotation: SIMD3<Float>
    var scale: SIMD3<Float>
}

struct BoundingBox {
    var min: SIMD3<Float> = .zero
    var max: SIMD3<Float> = .zero
}

struct SceneSnapshot: Codable {
    let layers: [SceneLayer]
    let activeLayerId: UUID?
    let selectedMeshId: UUID?
}
