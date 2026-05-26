import Foundation
import simd
import Metal

class BrushEngine {
    var currentBrush: BrushType = .round
    var radius: Float = 0.05
    var hardness: Float = 0.8
    var opacity: Float = 1.0
    var color: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 1)
    var pressure: Float = 1.0
    var symmetryEnabled = false
    var symmetryAxis: Int = 0
    
    private var undoStack: [[Vertex]] = []
    private var redoStack: [[Vertex]] = []
    private let maxUndo: Int = 50
    
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
    func getUndoCount() -> Int { undoStack.count }
    func getRedoCount() -> Int { redoStack.count }
    
    func paintStroke(at point: BrushPoint, on mesh: inout Mesh, renderer: PaintRenderer, cmdBuffer: MTLCommandBuffer) {
        let uv = projectToUV(point: point, mesh: mesh)
        renderer.paintStroke(at: uv, color: color, radius: radius, hardness: hardness, commandBuffer: cmdBuffer)
    }
    
    private func projectToUV(point: BrushPoint, mesh: Mesh) -> SIMD2<Float> {
        return SIMD2<Float>(point.position.x * 0.5 + 0.5, point.position.y * 0.5 + 0.5)
    }
    
    func sculptStroke(at point: BrushPoint, on mesh: inout Mesh) {
        applyDeformation(at: point, on: &mesh.vertices)
        if symmetryEnabled {
            var symPoint = point
            symPoint.position[symmetryAxis] = -symPoint.position[symmetryAxis]
            symPoint.normal[symmetryAxis] = -symPoint.normal[symmetryAxis]
            applyDeformation(at: symPoint, on: &mesh.vertices)
        }
    }
    
    private func applyDeformation(at point: BrushPoint, on vertices: inout [Vertex]) {
        let r = self.radius
        let p = point.pressure * self.pressure
        let h = self.hardness
        
        for i in 0..<vertices.count {
            let diff = vertices[i].position - point.position
            let dist = simd_length(diff)
            guard dist < r else { continue }
            
            let t = dist / r
            let falloff: Float
            if t < h { falloff = 1.0 }
            else { falloff = 1.0 - smoothstep(0.0, 1.0, (t - h) / (1.0 - h)) }
            
            switch currentBrush {
            case .round:
                vertices[i].position += vertices[i].normal * (1.0 - t) * falloff * p * 0.01
            case .flat:
                vertices[i].position += vertices[i].normal * falloff * p * 0.01
            case .inflate:
                let dir = simd_normalize(vertices[i].position)
                vertices[i].position += dir * (1.0 - t) * falloff * p * 0.01
            case .pinch:
                let dir = point.position - vertices[i].position
                vertices[i].position += dir * (1.0 - t) * falloff * p * 0.005
            case .smooth:
                let avg = averagePosition(vertices: vertices, index: i, radius: Int(r * 50))
                vertices[i].position = simd_mix(vertices[i].position, avg, falloff * 0.3)
            case .crease:
                let localY = simd_cross(simd_cross(point.normal, SIMD3<Float>(0,1,0)), point.normal)
                let localPos = dot(vertices[i].position - point.position, localY)
                let creaseAmount = abs(localPos) * 2.0 / r
                vertices[i].position -= point.normal * creaseAmount * falloff * p * 0.01
            case .grab:
                let grabDir = point.position - vertices[i].position
                if simd_length(grabDir) > 0.001 {
                    vertices[i].position += simd_normalize(grabDir) * falloff * p * 0.01
                }
            case .clay:
                let h2 = (1.0 - t) * falloff * p * 0.01
                vertices[i].position += point.normal * min(h2, 0.002)
            case .airbrush:
                let jitter = SIMD3<Float>(Float.random(in: -0.001...0.001), Float.random(in: -0.001...0.001), Float.random(in: -0.001...0.001))
                vertices[i].position += (vertices[i].normal + jitter) * (1.0 - t) * falloff * p * 0.005
            case .textured:
                let noise = sin(vertices[i].position.x * 50) * cos(vertices[i].position.y * 50) * sin(vertices[i].position.z * 50) * 0.5 + 0.5
                vertices[i].position += vertices[i].normal * (1.0 - t) * noise * falloff * p * 0.01
            }
            vertices[i].normal = simd_normalize(simd_cross(
                vertices[(i+1) % vertices.count].position - vertices[i].position,
                vertices[(i+2) % vertices.count].position - vertices[i].position
            ))
        }
    }
    
    private func averagePosition(vertices: [Vertex], index: Int, radius: Int) -> SIMD3<Float> {
        var sum = SIMD3<Float>(0,0,0)
        var count: Int = 0
        let start = max(0, index - radius)
        let end = min(vertices.count, index + radius + 1)
        for i in start..<end {
            if i != index {
                sum += vertices[i].position
                count += 1
            }
        }
        return count > 0 ? sum / Float(count) : vertices[index].position
    }
}
