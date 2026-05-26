import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "ExtrusionEngine")

class ExtrusionEngine {

    static func extrudeSketch(_ entities: [SketchEntity], points: [SketchPoint], distance: Float) -> Mesh? {
        guard !entities.isEmpty else { return nil }

        let profile = convertSketchToProfile(entities, points: points)
        guard profile.count >= 3 else { return nil }

        let direction: (dx: Double, dy: Double, dz: Double) = (0, 0, Double(distance > 0 ? 1 : -1))
        let absDist = Double(abs(distance))

        let point3D: [SIMD3<Double>] = profile.map { SIMD3<Double>(Double($0.x), Double($0.y), 0) }

        let occt = OCCTEngine()
        let polygon = occt.createPolygon(points: point3D)

        let extruded = occt.extrude(profile: polygon, direction: direction, distance: absDist)

        let mesh = occt.shapeToMesh(extruded)
        guard !mesh.vertices.isEmpty else { return nil }

        return mesh
    }

    static func extrudeSketchBidirectional(_ entities: [SketchEntity], points: [SketchPoint], positiveDistance: Float, negativeDistance: Float) -> Mesh? {
        guard let posMesh = extrudeSketch(entities, points: points, distance: positiveDistance) else { return nil }
        guard let negMesh = extrudeSketch(entities, points: points, distance: -negativeDistance) else { return posMesh }

        var merged = posMesh
        let offset = UInt32(posMesh.vertices.count)
        merged.vertices.append(contentsOf: negMesh.vertices)
        merged.indices.append(contentsOf: negMesh.indices.map { $0 + offset })
        return merged
    }

    static func previewExtrusion(_ entities: [SketchEntity], points: [SketchPoint], distance: Float) -> (vertices: [Vertex], indices: [UInt32]) {
        guard let mesh = extrudeSketch(entities, points: points, distance: distance) else {
            return ([], [])
        }
        return (mesh.vertices, mesh.indices)
    }

    private static func convertSketchToProfile(_ entities: [SketchEntity], points: [SketchPoint]) -> [SIMD2<Float>] {
        var profile: [SIMD2<Float>] = []

        for entity in entities {
            switch entity {
            case .point(let p):
                profile.append(p.position)
            case .line:
                break
            case .circle(let c):
                guard let cp = points.first(where: { $0.id == c.center }) else { continue }
                let segments = 32
                for i in 0..<segments {
                    let angle = Float(i) * 2 * .pi / Float(segments)
                    let x = cp.position.x + c.radius * cos(angle)
                    let y = cp.position.y + c.radius * sin(angle)
                    profile.append(SIMD2<Float>(x, y))
                }
                return profile
            case .rectangle(let r):
                guard let op = points.first(where: { $0.id == r.origin }) else { continue }
                let o = op.position
                let s = r.size
                profile.append(o)
                profile.append(o + SIMD2<Float>(s.x, 0))
                profile.append(o + s)
                profile.append(o + SIMD2<Float>(0, s.y))
                return profile
            case .arc(let a):
                guard let cp = points.first(where: { $0.id == a.center }) else { continue }
                let segments = 16
                let span = a.endAngle - a.startAngle
                for i in 0...segments {
                    let angle = a.startAngle + span * Float(i) / Float(segments)
                    let x = cp.position.x + a.radius * cos(angle)
                    let y = cp.position.y + a.radius * sin(angle)
                    profile.append(SIMD2<Float>(x, y))
                }
                return profile
            }
        }

        return profile
    }
}
