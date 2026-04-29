import Foundation
import simd
import Metal
import Combine

@MainActor
class CanvasViewModel: ObservableObject {
    @Published var scene: Scene3D
    @Published var selectedModelIndex: Int?
    @Published var hoveredModelIndex: Int?
    @Published var isInteracting: Bool = false
    @Published var isEditing: Bool = false
    @Published var showGrid: Bool = true
    @Published var showWireframe: Bool = false
    
    var currentMesh: Mesh {
        get {
            guard let idx = selectedModelIndex,
                  idx < scene.models.count,
                  let firstMesh = scene.models[idx].meshes.first
            else { return Mesh() }
            return firstMesh
        }
        set {
            guard let idx = selectedModelIndex,
                  idx < scene.models.count,
                  !scene.models[idx].meshes.isEmpty
            else { return }
            scene.models[idx].meshes[0] = newValue
            if let device = MTLCreateSystemDefaultDevice() {
                scene.models[idx].meshes[0].uploadToGPU(device: device)
            }
        }
    }

    private var undoStack: [Scene3D] = []
    private var redoStack: [Scene3D] = []
    private let maxUndo: Int = 50

    init() {
        self.scene = Scene3D()
        let verts = generateSphereVertices(radius: 0.8, segments: 32)
        var mesh = Mesh(vertices: verts.vertices, indices: verts.indices)
        if let device = MTLCreateSystemDefaultDevice() {
            mesh.uploadToGPU(device: device)
        }
        let model = Model(name: "Default", meshes: [mesh])
        scene.addModel(model)
    }

    func saveState() {
        undoStack.append(scene)
        if undoStack.count > maxUndo { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func undo() {
        guard !undoStack.isEmpty else { return }
        redoStack.append(scene)
        scene = undoStack.removeLast()
    }

    func redo() {
        guard !redoStack.isEmpty else { return }
        undoStack.append(scene)
        scene = redoStack.removeLast()
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func addModel(_ model: Model) {
        saveState()
        scene.addModel(model)
        selectedModelIndex = scene.models.count - 1
    }

    func removeModel(at index: Int) {
        guard index < scene.models.count else { return }
        saveState()
        scene.models.remove(at: index)
        selectedModelIndex = scene.models.isEmpty ? nil : min(index, scene.models.count - 1)
    }

    func updateCamera(_ camera: Scene3D.Camera) {
        scene.camera = camera
    }

    func resetCamera() {
        scene.camera = .default
    }

    func clearScene() {
        saveState()
        scene.models.removeAll()
        scene.strokes.removeAll()
        selectedModelIndex = nil
    }

    func resetScene() {
        scene = Scene3D()
        let verts = generateSphereVertices(radius: 0.8, segments: 32)
        var mesh = Mesh(vertices: verts.vertices, indices: verts.indices)
        if let device = MTLCreateSystemDefaultDevice() {
            mesh.uploadToGPU(device: device)
        }
        let model = Model(name: "Default", meshes: [mesh])
        scene.addModel(model)
        selectedModelIndex = 0
    }
}
