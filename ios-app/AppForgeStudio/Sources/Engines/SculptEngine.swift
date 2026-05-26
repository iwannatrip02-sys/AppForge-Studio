import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "SculptEngine")
struct SculptPoint {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var pressure: Float
    var dragDelta: SIMD3<Float>
}

enum DeformerType: String, Codable, CaseIterable {
    case inflate, pinch, smooth, crease, grab, flatten, twist, move, bend, shear
}

class SculptEngine {
    private var deformer: DeformerType = .inflate
    var radius: Float = 0.05
    var strength: Float = 0.5
    var symmetryEnabled = false
    var symmetryAxis: Int = 0

    var pendingStrokes: [SculptPoint] = []
    
    private var undoStack: [[Vertex]] = []
    private var redoStack: [[Vertex]] = []
    private let maxUndo: Int = 50
    
    func setDeformer(_ type: DeformerType) {
        deformer = type
    }
    
    func apply(at point: SculptPoint, to vertices: inout [Vertex]) {
        saveState(vertices)
        for i in 0..<vertices.count {
            applyDeformer(at: point, to: &vertices[i], adjacency: nil)
        }
        if symmetryEnabled {
            let symPoint = SculptPoint(
                position: mirrored(point.position),
                normal: mirrored(point.normal),
                pressure: point.pressure
            )
            for i in 0..<vertices.count {
                applyDeformer(at: symPoint, to: &vertices[i], adjacency: nil)
            }
        }
    }

    func applySculpt(to mesh: inout Mesh) -> Bool {
        guard !pendingStrokes.isEmpty else { return false }
        let adjList = mesh.edgeAdjacentIndices
        for stroke in pendingStrokes {
            let neighborPositions: [[SIMD3<Float>]] = adjList.map { indices in
                indices.map { mesh.vertices[$0].position }
            }
            for i in 0..<mesh.vertices.count {
                applyDeformer(at: stroke, to: &mesh.vertices[i], adjacency: neighborPositions[i])
            }
            if symmetryEnabled {
                let symPoint = SculptPoint(
                    position: mirrored(stroke.position),
                    normal: mirrored(stroke.normal),
                    pressure: stroke.pressure
                )
                for i in 0..<mesh.vertices.count {
                    applyDeformer(at: symPoint, to: &mesh.vertices[i], adjacency: neighborPositions[i])
                }
            }
        }
        pendingStrokes.removeAll()
        return true
    }
    
    private func applyDeformer(at point: SculptPoint, to vertex: inout Vertex, adjacency: [SIMD3<Float>]?) {
        let dir = vertex.position - point.position
        let dist = simd_length(dir)
        guard dist < radius, dist > 0 else { return }
        let falloff = 1.0 - smoothstep(0, radius, dist)
        let influence = strength * falloff * point.pressure
        
        switch deformer {
        case .inflate:
            vertex.position += vertex.normal * influence
        case .pinch:
            let toCenter = simd_normalize(point.position - vertex.position)
            vertex.position += toCenter * influence * 0.5
        case .smooth:
            SmoothDeformer().deform(vertex: &vertex, at: point, radius: radius, strength: strength, falloff: falloff, adjacency: adjacency)
        case .crease:
            vertex.position += vertex.normal * influence * 1.5
        case .grab:
            let displacement = point.position - vertex.position
            vertex.position += displacement * influence * 0.3
        case .flatten:
            vertex.position -= vertex.normal * influence * 0.5
        case .twist:
            let angle = influence * 0.5
            let cosA = cos(angle)
            let sinA = sin(angle)
            let rel = vertex.position - point.position
            let twisted = SIMD3<Float>(
                rel.x * cosA - rel.z * sinA,
                rel.y,
                rel.x * sinA + rel.z * cosA
            )
            vertex.position = point.position + twisted
        case .move:
            vertex.position += dir * influence * 0.5
        case .bend:
            let rel = vertex.position - point.position
            let angle = influence * rel.z
            let cosA = cos(angle)
            let sinA = sin(angle)
            vertex.position.x = point.position.x + rel.x * cosA - rel.z * sinA
            vertex.position.z = point.position.z + rel.x * sinA + rel.z * cosA
        case .shear:
            vertex.position.x += vertex.position.y * influence
        }
    }
    
    private func mirrored(_ v: SIMD3<Float>) -> SIMD3<Float> {
        var r = v
        r[symmetryAxis] = -r[symmetryAxis]
        return r
    }
    
    private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = clamp((x - edge0) / (edge1 - edge0), 0, 1)
        return t * t * (3 - 2 * t)
    }
    
    private func clamp(_ x: Float, _ min: Float, _ max: Float) -> Float {
        return x < min ? min : (x > max ? max : x)
    }
    
    func saveState(_ vertices: [Vertex]) {
        undoStack.append(vertices)
        if undoStack.count > maxUndo { undoStack.removeFirst() }
        redoStack.removeAll()
    }
    
    func undo(_ vertices: inout [Vertex]) -> Bool {
        guard !undoStack.isEmpty else { return false }
        redoStack.append(vertices)
        vertices = undoStack.removeLast()
        return true
    }
    
    func redo(_ vertices: inout [Vertex]) -> Bool {
        guard !redoStack.isEmpty else { return false }
        undoStack.append(vertices)
        vertices = redoStack.removeLast()
        return true
    }
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
}