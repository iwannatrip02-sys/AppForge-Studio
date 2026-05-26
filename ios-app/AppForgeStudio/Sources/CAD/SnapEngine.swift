import Foundation
import simd
import CoreGraphics

struct SnapPoint: Identifiable {
    let id: UUID = UUID()
    var position: SIMD3<Float>
    var screenPosition: CGPoint
    var type: SnapPointType
}

enum SnapPointType: String, CaseIterable {
    case vertex
    case midpoint
    case center
    case grid
}

class SnapEngine {
    static let shared = SnapEngine()

    var snapThresholdPixels: CGFloat = 50.0

    private init() {}

    func getSnapPoints(
        in scene: Scene3D,
        projection: (SIMD3<Float>) -> CGPoint
    ) -> [SnapPoint] {
        var points: [SnapPoint] = []

        for model in scene.models {
            for mesh in model.meshes {
                for vertex in mesh.vertices {
                    let screen = projection(vertex.position)
                    points.append(SnapPoint(
                        position: vertex.position,
                        screenPosition: screen,
                        type: .vertex
                    ))
                }

                for i in stride(from: 0, to: mesh.indices.count, by: 3) {
                    let i0 = Int(mesh.indices[i])
                    let i1 = Int(mesh.indices[i + 1])
                    let i2 = Int(mesh.indices[i + 2])
                    guard i0 < mesh.vertices.count,
                          i1 < mesh.vertices.count,
                          i2 < mesh.vertices.count else { continue }
                    let p0 = mesh.vertices[i0].position
                    let p1 = mesh.vertices[i1].position
                    let p2 = mesh.vertices[i2].position
                    let center = (p0 + p1 + p2) / 3.0
                    points.append(SnapPoint(
                        position: center,
                        screenPosition: projection(center),
                        type: .center
                    ))
                }

                for i in stride(from: 0, to: mesh.indices.count, by: 3) {
                    let i0 = Int(mesh.indices[i])
                    let i1 = Int(mesh.indices[i + 1])
                    guard i0 < mesh.vertices.count,
                          i1 < mesh.vertices.count else { continue }
                    let mid = (mesh.vertices[i0].position + mesh.vertices[i1].position) * 0.5
                    points.append(SnapPoint(
                        position: mid,
                        screenPosition: projection(mid),
                        type: .midpoint
                    ))
                }
            }
        }

        return points
    }

    func nearestSnap(
        to screenPoint: CGPoint,
        among points: [SnapPoint]
    ) -> SnapPoint? {
        guard !points.isEmpty else { return nil }
        var best: SnapPoint? = nil
        var bestDist: CGFloat = .infinity
        for p in points {
            let dx = p.screenPosition.x - screenPoint.x
            let dy = p.screenPosition.y - screenPoint.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < bestDist {
                bestDist = dist
                best = p
            }
        }
        if let best = best, bestDist < snapThresholdPixels {
            return best
        }
        return nil
    }

    func isNearSnapPoint(
        _ screenPoint: CGPoint,
        among points: [SnapPoint]
    ) -> Bool {
        return nearestSnap(to: screenPoint, among: points) != nil
    }
}
