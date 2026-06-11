import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "Scene3D")
struct Scene3D {
    var models: [Model]
    var strokes: [BrushStroke]
    var camera: Camera
    var lighting: Lighting
    var cadHistory = CADHistoryTree()
    var constraintManager = GeometryConstraintManager()
    var vertexProvider: VertexProvider? = nil
    var vertexUpdater: VertexUpdater? = nil
    
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
        var pointLights: [PointLight]
        
        struct DirectionalLight {
            var direction: SIMD3<Float>
            var color: SIMD3<Float>
            var intensity: Float
        }
        
        struct PointLight {
            var position: SIMD3<Float>
            var color: SIMD3<Float>
            var intensity: Float
            var range: Float
            
            static let `default` = PointLight(
                position: SIMD3<Float>(2, 2, 2),
                color: SIMD3<Float>(1, 1, 1),
                intensity: 2.0,
                range: 10.0
            )
        }
        
        static var `default`: Lighting {
            Lighting(ambientColor: SIMD3<Float>(0.03, 0.03, 0.03),
                     directionalLight: DirectionalLight(direction: SIMD3<Float>(0, -1, -0.5),
                                                         color: SIMD3<Float>(1, 1, 1),
                                                         intensity: 1.0),
                     pointLights: [
                        PointLight.default
                     ])
        }
        
        static var `studio`: Lighting {
            Lighting(
                ambientColor: SIMD3<Float>(0.02, 0.02, 0.02),
                directionalLight: DirectionalLight(
                    direction: SIMD3<Float>(0.3, -1.0, -0.5),
                    color: SIMD3<Float>(1.0, 0.98, 0.95),
                    intensity: 0.7
                ),
                pointLights: [
                    PointLight(position: SIMD3<Float>(3, 2, 3), color: SIMD3<Float>(1, 0.95, 0.9), intensity: 1.5, range: 12),
                    PointLight(position: SIMD3<Float>(-3, 1, -2), color: SIMD3<Float>(0.6, 0.7, 1.0), intensity: 1.0, range: 10),
                    PointLight(position: SIMD3<Float>(0, -0.5, 3), color: SIMD3<Float>(0.2, 0.3, 0.4), intensity: 0.4, range: 8),
                ]
            )
        }
    }
    
    init() {
        self.models = []
        self.strokes = []
        self.camera = .default
        self.lighting = .default
        configurePositionProvider()
    }

    mutating func addModel(_ model: Model) {
        models.append(model)
        resolveSceneConstraints()
    }

    mutating func addStroke(_ stroke: BrushStroke) {
        strokes.append(stroke)
        resolveSceneConstraints()
    }

    mutating func configurePositionProvider() {
        let currentModels = models
        constraintManager.entityPositionProvider = { entityID in
            for model in currentModels {
                for vertex in model.meshes.flatMap({ $0.vertices }) {
                    if vertex.id == entityID {
                        return vertex.position
                    }
                }
            }
            return nil
        }
    }

    mutating func resolveSceneConstraints() {
        configurePositionProvider()
        constraintManager.resolveConstraints()
    }

    private mutating func applyPositions(_ positions: [UUID: SIMD3<Float>]) {
        for i in 0..<models.count {
            for j in 0..<models[i].meshes.count {
                for k in 0..<models[i].meshes[j].vertices.count {
                    let vid = models[i].meshes[j].vertices[k].id
                    if let newPos = positions[vid] {
                        models[i].meshes[j].vertices[k].position = newPos
                    }
                }
            }
        }
    }
}