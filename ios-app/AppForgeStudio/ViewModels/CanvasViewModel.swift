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
    @Published var animationEngine: AnimationEngine?
    
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
    
    func resetView() {
        scene.camera = .default
    }
    
    var currentMode: AppMode {
        .hybrid
    }
}

// MARK: - Helpers

struct SphereVertices {
    let vertices: [Vertex]
    let indices: [UInt32]
}

func generateSphereVertices(radius: Float, segments: Int) -> SphereVertices {
    var verts: [Vertex] = []
    var idx: [UInt32] = []
    for lat in 0...segments {
        let theta = Float(lat) * Float.pi / Float(segments)
        let sinTheta = sin(theta)
        let cosTheta = cos(theta)
        for lon in 0...segments {
            let phi = Float(lon) * 2.0 * Float.pi / Float(segments)
            let sinPhi = sin(phi)
            let cosPhi = cos(phi)
            let x = cosPhi * sinTheta
            let y = cosTheta
            let z = sinPhi * sinTheta
            verts.append(Vertex(position: SIMD3<Float>(x*radius, y*radius, z*radius),
                                normal: SIMD3<Float>(x, y, z),
                                uv: SIMD2<Float>(Float(lon)/Float(segments), Float(lat)/Float(segments))))
        }
    }
    for lat in 0..<segments {
        for lon in 0..<segments {
            let first = UInt32(lat * (segments + 1) + lon)
            let second = first + UInt32(segments + 1)
            idx.append(first)
            idx.append(second)
            idx.append(first + 1)
            idx.append(second)
            idx.append(second + 1)
            idx.append(first + 1)
        }
    }
    return SphereVertices(vertices: verts, indices: idx)
}

enum AppMode: String {
    case hybrid = "Hybrid"
    case cad = "CAD"
    case sculpt = "Sculpt"
    case animation = "Animation"
    case render = "Render"
}