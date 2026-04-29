import Foundation
import Satin
import MetalKit
import Combine

class SatinRenderer: ObservableObject {
    let renderer: Renderer
    var scene: Object
    var camera: Camera
    @Published var scene3D: Scene3D?
    private var meshObjects: [Mesh] = []
    
    init(mtkView: MTKView) {
        renderer = Renderer(mtkView: mtkView)
        scene = Object()
        camera = PerspectiveCamera()
        renderer.scene = scene
        renderer.camera = camera
    }
    
    func setup() { renderer.setup() }
    func draw() { renderer.draw() }
    func addMesh(_ mesh: Mesh) { scene.add(mesh) }
    
    func updateScene(_ newScene: inout Scene3D) {
        scene3D = newScene
        for m in meshObjects { scene.remove(m) }
        meshObjects.removeAll()
        for model in newScene.models {
            for mesh in model.meshes {
                addMesh(mesh)
                meshObjects.append(mesh)
            }
        }
    }
}
