import Foundation
import simd
import SwiftUI
import Combine
import Core.Managers

struct SketchPoint: Identifiable {
    let id: UUID
    var position: SIMD2<Float>
    init(id: UUID = UUID(), position: SIMD2<Float>) { self.id = id; self.position = position }
}

struct SketchLine: Identifiable {
    let id: UUID; var start: UUID; var end: UUID
    init(id: UUID = UUID(), start: UUID, end: UUID) { self.id = id; self.start = start; self.end = end }
}

struct SketchCircle: Identifiable {
    let id: UUID; var center: UUID; var radius: Float
    init(id: UUID = UUID(), center: UUID, radius: Float) { self.id = id; self.center = center; self.radius = radius }
}

struct SketchRectangle: Identifiable {
    let id: UUID; var origin: UUID; var size: SIMD2<Float>
    init(id: UUID = UUID(), origin: UUID, size: SIMD2<Float>) { self.id = id; self.origin = origin; self.size = size }
}

struct SketchArc: Identifiable {
    let id: UUID; var center: UUID; var radius: Float; var startAngle: Float; var endAngle: Float
    init(id: UUID = UUID(), center: UUID, radius: Float, startAngle: Float, endAngle: Float) { self.id = id; self.center = center; self.radius = radius; self.startAngle = startAngle; self.endAngle = endAngle }
}

enum SketchEntity {
    case point(SketchPoint), line(SketchLine), circle(SketchCircle), rectangle(SketchRectangle), arc(SketchArc)
    var id: UUID {
        switch self {
        case .point(let p): return p.id; case .line(let l): return l.id
        case .circle(let c): return c.id; case .rectangle(let r): return r.id; case .arc(let a): return a.id
        }
    }
}

enum Constraint: Identifiable {
    case horizontal(UUID, lineID: UUID), vertical(UUID, lineID: UUID)
    case perpendicular(UUID, UUID, UUID, UUID), tangent(UUID, UUID), concentric(UUID, UUID)
    case equal(UUID, UUID), dimension(UUID, UUID, Float), angle(UUID, UUID, Float)
    var id: UUID { UUID() }
    // MARK: - Conversion to GeometryConstraint
    func toGeometryConstraint() -> GeometryConstraint {
        switch self {
        case .horizontal(let id, let lineID):
            return GeometryConstraint(id: id, type: .horizontal, entityIDs: [lineID])
        case .vertical(let id, let lineID):
            return GeometryConstraint(id: id, type: .vertical, entityIDs: [lineID])
        case .perpendicular(let id, let a, let b, _):
            return GeometryConstraint(id: id, type: .perpendicular, entityIDs: [a, b])
        case .tangent(let id, let b):
            return GeometryConstraint(id: id, type: .tangent, entityIDs: [id, b])
        case .concentric(let id, let b):
            return GeometryConstraint(id: id, type: .concentric, entityIDs: [id, b])
        case .equal(let id, let b):
            return GeometryConstraint(id: id, type: .equal, entityIDs: [id, b])
        case .dimension(let id, let a, let val):
            return GeometryConstraint(id: id, type: .distance, entityIDs: [id, a], value: val)
        case .angle(let id, let a, let val):
            return GeometryConstraint(id: id, type: .angle, entityIDs: [id, a], value: val)
        }
    }
}

enum SketchTool: String, CaseIterable { case select = "Seleccionar"; case point = "Punto"; case line = "Linea"; case circle = "Circulo"; case rectangle = "Rectangulo"; case arc = "Arco" }

class CADSketchEngine: ObservableObject {
    @Published var constraintManager = GeometryConstraintManager()
    var historyTree = CADHistoryTree()
    @Published var points: [SketchPoint] = []
    @Published var entities: [SketchEntity] = []
    var constraints: [GeometryConstraint] { constraintManager.constraints }
    @Published var gridSize: Float = 0.01
    @Published var isDirty: Bool = false
    
    func snapToGrid(_ pos: SIMD2<Float>) -> SIMD2<Float> {
        let g = gridSize
        return SIMD2<Float>(round(pos.x / g) * g, round(pos.y / g) * g)
    }
    
    func addPoint(_ p: SketchPoint) { points.append(p); entities.append(.point(p)); isDirty = true }
    
    func removeEntity(id: UUID) {
        entities.removeAll { $0.id == id }; points.removeAll { $0.id == id }
        isDirty = true
    }
    
    func addConstraint(_ c: Constraint) { constraintManager.addConstraint(c.toGeometryConstraint()); isDirty = true }
    func removeConstraint(at index: Int) { constraintManager.removeConstraint(at: index); isDirty = true }
    
    func extrudeSketch(distance: Float) -> Mesh {
        let engine = ExtrusionEngine()
        var mesh = Mesh()
        let sketchPoints = collectSketchPoints()
        guard sketchPoints.count >= 3 else { return mesh }
        let faceIndices = Array(0..<UInt32(sketchPoints.count))
        let direction = SIMD3<Float>(0, 0, 1)
        var tempMesh = Mesh(vertices: sketchPoints.map { p in
            Vertex(position: SIMD3<Float>(p.position.x, p.position.y, 0), normal: SIMD3<Float>(0, 0, 1), uv: SIMD2<Float>(0, 0))
        }, indices: faceIndices)
        mesh = engine.extrude(mesh: &tempMesh, faceIndices: faceIndices, direction: direction, distance: distance)
        return mesh
    }
    
    private func collectSketchPoints() -> [SketchPoint] {
        var collected: [UUID: SketchPoint] = [:]
        for entity in entities {
            switch entity {
            case .point(let p): collected[p.id] = p
            case .line(let l):
                if let s = points.first(where: { $0.id == l.start }) { collected[s.id] = s }
                if let e = points.first(where: { $0.id == l.end }) { collected[e.id] = e }
            case .circle(let c):
                if let cp = points.first(where: { $0.id == c.center }) { collected[cp.id] = cp }
            case .rectangle(let r):
                if let op = points.first(where: { $0.id == r.origin }) {
                    collected[op.id] = op
                    let c2 = SketchPoint(position: op.position + SIMD2<Float>(r.size.x, 0))
                    let c3 = SketchPoint(position: op.position + r.size)
                    let c4 = SketchPoint(position: op.position + SIMD2<Float>(0, r.size.y))
                    collected[c2.id] = c2; collected[c3.id] = c3; collected[c4.id] = c4
                }
            case .arc(let a):
                if let cp = points.first(where: { $0.id == a.center }) {
                    collected[cp.id] = cp
                    let mid = (a.startAngle + a.endAngle) / 2
                    let ap = SketchPoint(position: cp.position + SIMD2<Float>(cos(mid), sin(mid)) * a.radius)
                    collected[ap.id] = ap
                }
            }
        }
        return Array(collected.values)
    }
    
    func clearAll() { points.removeAll(); entities.removeAll(); constraintManager.clearAll(); isDirty = true }
}
