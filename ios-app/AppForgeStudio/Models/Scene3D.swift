import Foundation
import simd

struct Scene3D {
    var models: [Model]
    var strokes: [BrushStroke]
    var camera: Camera
    var lighting: Lighting
    var cadHistory = CADHistoryTree()
    var constraintManager = GeometryConstraintManager()
    
    struct Camera {
        var position: SIMD3<Float>
        var target: SIMD3<Float>
        var up: SIMD3<Float>
        var fov: Float
        var nearPlane: Float
        var farPlane: Float
        
        static var `default`: Camera {
            Camera(position: SIMD3<Float>(0, 0, 3),
                   target: SIMD3<Float>(0, 0, 0),
                   up: SIMD3<Float>(0, 1, 0),
                   fov: 45,
                   nearPlane: 0.1,
                   farPlane: 100)
        }
    }
    
    struct Lighting {
        var ambientColor: SIMD3<Float>
        var directionalLight: DirectionalLight
        
        struct DirectionalLight {
            var direction: SIMD3<Float>
            var color: SIMD3<Float>
            var intensity: Float
        }
        
        static var `default`: Lighting {
            Lighting(ambientColor: SIMD3<Float>(0.2, 0.2, 0.2),
                     directionalLight: DirectionalLight(direction: SIMD3<Float>(0, -1, -1),
                                                        color: SIMD3<Float>(1, 1, 1),
                                                        intensity: 0.8))
        }
    }
    
    init() {
        self.models = []
        self.strokes = []
        self.camera = .default
        self.lighting = .default
    }
    
    mutating func addModel(_ model: Model) {
        models.append(model)
    }
    
    mutating func addStroke(_ stroke: BrushStroke) {
        strokes.append(stroke)
    }
}
