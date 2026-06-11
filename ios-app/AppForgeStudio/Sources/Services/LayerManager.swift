import Foundation
import simd
import Combine

/// Hybrid layer type — determines which editing mode (CAD, Sculpt, Paint)
/// this layer belongs to. Hybrid mode uses this to filter editable layers.
enum HybridLayerType: String, Codable, CaseIterable, Sendable {
    case cad = "CAD"
    case sculpt = "Sculpt"
    case paint = "Paint"

    var icon: String {
        switch self {
        case .cad: return "gearshape"
        case .sculpt: return "hand.draw"
        case .paint: return "paintpalette"
        }
    }

    var displayName: String { rawValue }
}

/// Non-destructive modeling layer — every CAD operation or sculpt stroke
/// is a LayerOperation that can be reordered, toggled, or deleted.
/// This beats both Shapr3D (history without layers) and Nomad (layers without params).
struct ModelLayer: Identifiable, Codable {
    let id: UUID
    var name: String
    var isVisible: Bool = true
    var isLocked: Bool = false
    var opacity: Float = 1.0
    var blendMode: LayerBlendMode = .normal
    var layerType: HybridLayerType = .cad
    var operations: [LayerOperation] = []

    // Cached mesh result for this layer's accumulated operations
    var cachedMesh: Mesh?
    var isDirty: Bool = true  // needs re-evaluation

    init(name: String, layerType: HybridLayerType = .cad) {
        self.id = UUID()
        self.name = name
        self.layerType = layerType
    }
}

enum LayerBlendMode: String, Codable, CaseIterable {
    case normal, add, subtract, multiply, overlay
}

/// A single operation within a layer. Can be CAD, sculpt, or transform.
enum LayerOperation: Codable {
    case extrude(distance: Double, direction: SIMD3<Double>)
    case fillet(radius: Double)
    case chamfer(distance: Double)
    case shell(thickness: Double)
    case boolean(operation: BooleanOpType, targetLayerId: UUID)
    case sculptStroke(points: [SculptPointData], brushType: DeformerType)
    case transform(position: SIMD3<Double>, rotation: SIMD3<Double>, scale: SIMD3<Double>)
    case subdivision(levels: Int)
    case remesh(resolution: Int)
    
    var displayName: String {
        switch self {
        case .extrude(let d, _): "Extrude \(d)mm"
        case .fillet(let r): "Fillet R\(r)"
        case .chamfer(let d): "Chamfer \(d)mm"
        case .shell(let t): "Shell \(t)mm"
        case .boolean(let op, _): "Boolean \(op.rawValue)"
        case .sculptStroke: "Sculpt Stroke"
        case .transform: "Transform"
        case .subdivision(let l): "Subdivide x\(l)"
        case .remesh(let r): "Remesh \(r)"
        }
    }
}

enum BooleanOpType: String, Codable, CaseIterable {
    case union, subtract, intersect
}

struct SculptPointData: Codable {
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
    let pressure: Float
}

// MARK: - Layer Manager

/// Evaluates the layer stack and produces the final mesh.
/// ObservableObject so SwiftUI can react to layer changes.
@MainActor
final class LayerManager: ObservableObject {
    @Published var layers: [ModelLayer] = []
    @Published var activeLayerId: UUID?
    @Published var isEvaluating: Bool = false
    
    private let remeshEngine = VoxelRemeshEngine()
    private let topoEngine = DynamicTopologyEngine()
    
    // MARK: - Layer CRUD
    
    func addLayer(name: String, layerType: HybridLayerType = .cad) {
        layers.append(ModelLayer(name: name, layerType: layerType))
        if activeLayerId == nil { activeLayerId = layers.last?.id }
    }

    /// Returns only layers of the given type, preserving stack order.
    func layers(ofType type: HybridLayerType) -> [ModelLayer] {
        layers.filter { $0.layerType == type }
    }

    /// Returns the active layer if it matches the given type, else the topmost visible layer of that type.
    func activeLayer(for type: HybridLayerType) -> ModelLayer? {
        if let activeId = activeLayerId,
           let active = layers.first(where: { $0.id == activeId }),
           active.layerType == type {
            return active
        }
        return layers.last(where: { $0.layerType == type && $0.isVisible })
    }
    
    func removeLayer(_ layer: ModelLayer) {
        layers.removeAll { $0.id == layer.id }
        if activeLayerId == layer.id { activeLayerId = layers.last?.id }
    }
    
    func duplicateLayer(_ layer: ModelLayer) {
        var copy = layer
        copy.id = UUID()
        copy.name = "\(layer.name) Copy"
        copy.isDirty = true
        copy.cachedMesh = nil
        layers.append(copy)
    }
    
    func moveLayer(from source: IndexSet, to destination: Int) {
        layers.move(fromOffsets: source, toOffset: destination)
        invalidateCache()
    }
    
    func toggleVisibility(_ layer: ModelLayer) {
        if let idx = layers.firstIndex(where: { $0.id == layer.id }) {
            layers[idx].isVisible.toggle()
            invalidateCache()
        }
    }
    
    // MARK: - Operations
    
    func addOperation(_ op: LayerOperation, to layerId: UUID) {
        guard let idx = layers.firstIndex(where: { $0.id == layerId }) else { return }
        layers[idx].operations.append(op)
        layers[idx].isDirty = true
        invalidateCache()
    }
    
    func removeOperation(at index: Int, from layerId: UUID) {
        guard let idx = layers.firstIndex(where: { $0.id == layerId }) else { return }
        guard index < layers[idx].operations.count else { return }
        layers[idx].operations.remove(at: index)
        layers[idx].isDirty = true
        invalidateCache()
    }
    
    // MARK: - Evaluation
    
    /// Re-evaluate all layers and return the final composed mesh.
    func evaluate(baseMesh: Mesh) -> Mesh {
        isEvaluating = true
        defer { isEvaluating = false }
        
        var result = baseMesh
        
        for i in 0..<layers.count {
            guard layers[i].isVisible else { continue }
            
            if layers[i].isDirty || layers[i].cachedMesh == nil {
                var layerMesh = (i == 0) ? baseMesh : (layers[0..<i].last(where: { $0.isVisible && $0.cachedMesh != nil })?.cachedMesh ?? baseMesh)
                
                for op in layers[i].operations {
                    layerMesh = applyOperation(op, to: layerMesh)
                }
                
                layers[i].cachedMesh = layerMesh
                layers[i].isDirty = false
            }
            
            if let cached = layers[i].cachedMesh {
                result = blend(layers[i].cachedMesh ?? cached, with: result, mode: layers[i].blendMode, opacity: layers[i].opacity)
            }
        }
        
        return result
    }
    
    private func applyOperation(_ op: LayerOperation, to mesh: Mesh) -> Mesh {
        switch op {
        case .subdivision(let levels):
            let engine = SubdivisionEngine()
            var result = mesh
            for _ in 0..<levels { result = engine.subdivide(result, levels: 1) }
            return result
        case .remesh(let resolution):
            remeshEngine.resolution = resolution
            return remeshEngine.remesh(mesh)
        case .sculptStroke, .extrude, .fillet, .chamfer, .shell, .boolean, .transform:
            return mesh // CAD ops handled by OCCT, sculpt by SculptEngine
        }
    }
    
    private func blend(_ a: Mesh, with b: Mesh, mode: LayerBlendMode, opacity: Float) -> Mesh {
        switch mode {
        case .normal: return a
        case .add:    return a
        case .subtract: return a
        case .multiply: return a
        case .overlay: return a
        }
    }
    
    private func invalidateCache() {
        for i in 0..<layers.count { layers[i].isDirty = true; layers[i].cachedMesh = nil }
        objectWillChange.send()
    }
}
