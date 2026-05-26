import Foundation
import simd
import Combine
import CoreGraphics

struct InferredConstraint {
    let constraint: GeometryConstraint
    let confidence: Float
}

struct CADEntity {
    let id: UUID
    var type: CADEntityType

    var startPosition: SIMD3<Float>?
    var endPosition: SIMD3<Float>?
    var centerPosition: SIMD3<Float>?
    var radius: Float?

    var direction: SIMD3<Float>? {
        guard let s = startPosition, let e = endPosition else { return nil }
        return simd_normalize(e - s)
    }

    var length: Float? {
        guard let s = startPosition, let e = endPosition else { return nil }
        return simd_distance(s, e)
    }
}

enum CADEntityType: String, CaseIterable {
    case point
    case line
    case circle
    case arc
}

class ConstraintEngine: ObservableObject {
    @Published var currentSnapPoint: SnapPoint?
    @Published var inferredSnapPoints: [SnapPoint] = []

    var scene: Scene3D?

    private let snapEngine = SnapEngine.shared
    private let angleTolerance: Float = 3.0 * .pi / 180.0

    func findSnapPoints(
        position: SIMD3<Float>,
        direction: SIMD3<Float>
    ) -> [SnapPoint] {
        guard let scene = scene else { return [] }

        let projection: (SIMD3<Float>) -> CGPoint = { worldPos in
            let sx = CGFloat(worldPos.x / 4.0 + 0.5) * 300
            let sy = CGFloat(1 - (worldPos.y / 3.0 + 0.5)) * 400
            return CGPoint(x: sx, y: sy)
        }

        let allSnaps = snapEngine.getSnapPoints(in: scene, projection: projection)

        let filtered = allSnaps.filter { snap in
            let delta = snap.position - position
            let dist = simd_length(delta)
            guard dist > 0.001 else { return true }
            let dir = delta / dist
            let alignment = simd_dot(dir, direction)
            return alignment > cos(angleTolerance * 3)
        }

        let sorted = filtered.sorted { a, b in
            simd_distance(a.position, position) < simd_distance(b.position, position)
        }

        let result = Array(sorted.prefix(8))

        DispatchQueue.main.async {
            self.inferredSnapPoints = result
            self.currentSnapPoint = result.first
        }

        return result
    }

    func inferConstraints(
        for entity: CADEntity,
        with neighbors: [CADEntity]
    ) -> [InferredConstraint] {
        var results: [InferredConstraint] = []

        for neighbor in neighbors where neighbor.id != entity.id {
            if entity.type == .line, neighbor.type == .line {
                if let dirA = entity.direction, let dirB = neighbor.direction {
                    let dot = abs(simd_dot(dirA, dirB))
                    let angle = acos(clamp(dot, -1, 1))

                    if angle < angleTolerance {
                        let constraint = GeometryConstraint(
                            type: .collinear,
                            entityIDs: [entity.id, neighbor.id],
                            label: "Parallel"
                        )
                        let confidence = 1.0 - (angle / angleTolerance)
                        results.append(InferredConstraint(
                            constraint: constraint,
                            confidence: clamp(confidence, 0, 1)
                        ))

                        if let snapPos = neighbor.startPosition ?? neighbor.centerPosition {
                            let screenPos = CGPoint(
                                x: CGFloat(snapPos.x / 4.0 + 0.5) * 300,
                                y: CGFloat(1 - (snapPos.y / 3.0 + 0.5)) * 400
                            )
                            DispatchQueue.main.async {
                                self.currentSnapPoint = SnapPoint(
                                    position: snapPos,
                                    screenPosition: screenPos,
                                    type: .vertex
                                )
                            }
                        }
                    } else if angle > .pi / 2 - angleTolerance && angle < .pi / 2 + angleTolerance {
                        let constraint = GeometryConstraint(
                            type: .perpendicular,
                            entityIDs: [entity.id, neighbor.id,
                                        entity.id, neighbor.id],
                            label: "Perpendicular"
                        )
                        let deviation = abs(angle - .pi / 2) / angleTolerance
                        let confidence = 1.0 - deviation
                        results.append(InferredConstraint(
                            constraint: constraint,
                            confidence: clamp(confidence, 0, 1)
                        ))
                    }
                }

                if let lenA = entity.length, let lenB = neighbor.length {
                    let ratio = abs(lenA - lenB) / max(lenA, lenB)
                    if ratio < 0.02 {
                        let constraint = GeometryConstraint(
                            type: .equal,
                            entityIDs: [entity.id, neighbor.id,
                                        entity.id, neighbor.id],
                            label: "Equal"
                        )
                        let confidence = 1.0 - (ratio / 0.02)
                        results.append(InferredConstraint(
                            constraint: constraint,
                            confidence: clamp(confidence, 0, 1)
                        ))
                    }
                }
            }

            if let endA = entity.endPosition, let endB = neighbor.endPosition {
                let dist = simd_distance(endA, endB)
                if dist < 0.1 {
                    let constraint = GeometryConstraint(
                        type: .distance,
                        entityIDs: [entity.id, neighbor.id],
                        value: 0,
                        label: "Coincident"
                    )
                    let confidence = 1.0 - (dist / 0.1)
                    results.append(InferredConstraint(
                        constraint: constraint,
                        confidence: clamp(confidence, 0, 1)
                    ))

                    let screenPos = CGPoint(
                        x: CGFloat(endB.x / 4.0 + 0.5) * 300,
                        y: CGFloat(1 - (endB.y / 3.0 + 0.5)) * 400
                    )
                    DispatchQueue.main.async {
                        self.currentSnapPoint = SnapPoint(
                            position: endB,
                            screenPosition: screenPos,
                            type: .vertex
                        )
                    }
                }
            } else if let startA = entity.startPosition, let startB = neighbor.startPosition {
                let dist = simd_distance(startA, startB)
                if dist < 0.1 {
                    let constraint = GeometryConstraint(
                        type: .distance,
                        entityIDs: [entity.id, neighbor.id],
                        value: 0,
                        label: "Coincident"
                    )
                    let confidence = 1.0 - (dist / 0.1)
                    results.append(InferredConstraint(
                        constraint: constraint,
                        confidence: clamp(confidence, 0, 1)
                    ))

                    let screenPos = CGPoint(
                        x: CGFloat(startB.x / 4.0 + 0.5) * 300,
                        y: CGFloat(1 - (startB.y / 3.0 + 0.5)) * 400
                    )
                    DispatchQueue.main.async {
                        self.currentSnapPoint = SnapPoint(
                            position: startB,
                            screenPosition: screenPos,
                            type: .vertex
                        )
                    }
                }
            }

            if entity.type == .line,
               neighbor.type == .circle || neighbor.type == .arc {
                if let radius = neighbor.radius,
                   let center = neighbor.centerPosition,
                   let start = entity.startPosition,
                   let dir = entity.direction {
                    let toStart = start - center
                    let projLen = simd_dot(toStart, dir)
                    let closest = start - dir * projLen
                    let distToCenter = simd_distance(closest, center)
                    let tangentDist = abs(distToCenter - radius)
                    let confidence = tangentDist < 0.05
                        ? 1.0 - tangentDist / 0.05
                        : 0.0
                    if confidence > 0 {
                        let constraint = GeometryConstraint(
                            type: .tangent,
                            entityIDs: [neighbor.id, entity.id],
                            value: radius,
                            label: "Tangent"
                        )
                        results.append(InferredConstraint(
                            constraint: constraint,
                            confidence: clamp(confidence, 0, 1)
                        ))
                    }
                }
            }
        }

        if entity.type == .line, let dir = entity.direction {
            let up = SIMD3<Float>(0, 1, 0)
            let right = SIMD3<Float>(1, 0, 0)
            let dotUp = abs(simd_dot(dir, up))
            let dotRight = abs(simd_dot(dir, right))
            let angleUp = acos(clamp(dotUp, -1, 1))
            let angleRight = acos(clamp(dotRight, -1, 1))
            let axisTolerance: Float = 3.0 * .pi / 180.0

            if angleUp < axisTolerance {
                let constraint = GeometryConstraint(
                    type: .vertical,
                    entityIDs: [entity.id],
                    label: "Vertical"
                )
                let confidence = 1.0 - (angleUp / axisTolerance)
                results.append(InferredConstraint(
                    constraint: constraint,
                    confidence: clamp(confidence, 0, 1)
                ))
            }

            if angleRight < axisTolerance {
                let constraint = GeometryConstraint(
                    type: .horizontal,
                    entityIDs: [entity.id],
                    label: "Horizontal"
                )
                let confidence = 1.0 - (angleRight / axisTolerance)
                results.append(InferredConstraint(
                    constraint: constraint,
                    confidence: clamp(confidence, 0, 1)
                ))
            }
        }

        return results.sorted { $0.confidence > $1.confidence }
    }

    func clearSnapState() {
        currentSnapPoint = nil
        inferredSnapPoints = []
    }
}

private func clamp(_ value: Float, _ minVal: Float, _ maxVal: Float) -> Float {
    return Swift.min(Swift.max(value, minVal), maxVal)
}
