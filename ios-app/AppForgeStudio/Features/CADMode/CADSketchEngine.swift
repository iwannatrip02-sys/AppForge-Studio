import SwiftUI
import simd
import OSLog
import PencilKit

private let logger = Logger(subsystem: "com.appforgestudio", category: "CADSketchEngine")

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

enum SketchEngineTool: String, CaseIterable { case select = "Seleccionar"; case point = "Punto"; case line = "Linea"; case circle = "Circulo"; case rectangle = "Rectangulo"; case arc = "Arco" }

class CADSketchEngine: ObservableObject {
    @Published var constraintManager = GeometryConstraintManager()
    @Published var historyTree = CADHistoryTree()
    @Published var vertexProvider: VertexProvider? = nil
    @Published var vertexUpdater: VertexUpdater? = nil
    @Published var points: [SketchPoint] = []
    @Published var entities: [SketchEntity] = []
    @Published var gridSize: Float = 0.01
    @Published var isDirty: Bool = false
    @Published var solverConverged: Bool = false
    @Published var pencilMode: Bool = false
    @Published var currentStrokeWidth: CGFloat = 2.0

    private var pendingConstraints: [GeometryConstraint] = []

    init() {
        setupConstraintBindings()
    }

    private func setupConstraintBindings() {
        let weakPoints = { [weak self] (uuid: UUID) -> SIMD3<Float>? in
            guard let self = self else { return nil }
            if let pt = self.points.first(where: { $0.id == uuid }) {
                return SIMD3<Float>(pt.position.x, pt.position.y, 0)
            }
            return nil
        }
        constraintManager.entityPositionProvider = { uuid in
            weakPoints(uuid)
        }
        constraintManager.entityPositionUpdater = { [weak self] uuid, newPos in
            guard let self = self else { return }
            if let idx = self.points.firstIndex(where: { $0.id == uuid }) {
                self.points[idx].position = SIMD2<Float>(newPos.x, newPos.y)
                self.isDirty = true
            }
        }
    }

    func snapToGrid(_ pos: SIMD2<Float>) -> SIMD2<Float> {
        let g = gridSize
        return SIMD2<Float>(round(pos.x / g) * g, round(pos.y / g) * g)
    }

    func addPoint(_ p: SketchPoint) {
        historyTree.beginOperation("addPoint", params: ["x": Double(p.position.x), "y": Double(p.position.y)])
        points.append(p)
        entities.append(.point(p))

        if points.count >= 2 {
            let lastTwo = points.suffix(2)
            let ids = lastTwo.map { $0.id }
            let line = SketchLine(start: ids[0], end: ids[1])
            entities.append(.line(line))
        }

        if !pendingConstraints.isEmpty {
            _ = constraintManager.resolveConstraints()
        }

        isDirty = true
    }

    func removeEntity(id: UUID) {
        entities.removeAll { $0.id == id }
        points.removeAll { $0.id == id }
        isDirty = true
    }

    func addConstraintFromUI(type: ConstraintType, entityIDs: [UUID], value: Float? = nil) {
        let constraint = GeometryConstraint(type: type, entityIDs: entityIDs, value: value)
        constraintManager.addConstraint(constraint)
        constraintManager.resolveConstraints()
        objectWillChange.send()
    }

    func resolvePendingConstraints() {
        let metrics = constraintManager.resolveConstraints(with: &points)
        solverConverged = metrics.converged
    }

    func resolveConstraints(scene: Scene3D) {
        connectToScene(scene)

        let activeConstraints = constraintManager.constraints.filter { $0.isActive }
        if activeConstraints.isEmpty {
            logger.info("CADSketchEngine: no active constraints to resolve")
            return
        }

        historyTree.beginOperation("resolveConstraints", params: ["count": Double(activeConstraints.count)])

        var sketchPoints = points
        let metrics2D = constraintManager.resolveConstraints(with: &sketchPoints)

        if metrics2D.converged {
            points = sketchPoints
            solverConverged = true
        } else {
            solverConverged = false
        }

        constraintManager.resolveConstraints()

        isDirty = true
        logger.info("CADSketchEngine: resolveConstraints completed, converged=\(metrics2D.converged), iterations=\(metrics2D.iterationCount), residual=\(metrics2D.residual)")
    }

    private func connectToScene(_ scene: Scene3D?) {
        guard let scene = scene else {
            setupConstraintBindings()
            return
        }
        constraintManager.entityPositionProvider = { entityID in
            for model in scene.models {
                for mesh in model.meshes {
                    for vertex in mesh.vertices {
                        // Vertex.id exists — using it for entity matching
                        if vertex.id == entityID { return vertex.position }
                    }
                }
            }
            if let pt = self.points.first(where: { $0.id == entityID }) {
                return SIMD3<Float>(pt.position.x, pt.position.y, 0)
            }
            return nil
        }
        constraintManager.entityPositionUpdater = { entityID, newPosition in
            for i in 0..<scene.models.count {
                for j in 0..<scene.models[i].meshes.count {
                    for k in 0..<scene.models[i].meshes[j].vertices.count {
                        // Vertex.id exists — matching and updating
                        if scene.models[i].meshes[j].vertices[k].id == entityID {
                            scene.models[i].meshes[j].vertices[k].position = newPosition
                            return
                        }
                    }
                }
            }
            if let idx = self.points.firstIndex(where: { $0.id == entityID }) {
                self.points[idx].position = SIMD2<Float>(newPosition.x, newPosition.y)
                self.isDirty = true
            }
        }
    }

    func undoLastOperation() {
        historyTree.undo()
        isDirty = true
    }

    func redoLastOperation() {
        historyTree.redo()
        isDirty = true
    }

    func extrudeSketch(distance: Float) -> Mesh {
        // TODO(F3): re-wire ExtrusionEngine → CADShapeExtrusionEngine (API changed to Wire/CADShape)
        // Original ExtrusionEngine.extrude(mesh:faceIndices:direction:distance:) no longer exists.
        return Mesh()
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

    var isClosedSketch: Bool {
        guard entities.count >= 3 else { return false }
        let lines = entities.compactMap { entity -> SketchLine? in
            if case .line(let l) = entity { return l }
            return nil
        }
        guard lines.count >= 2 else { return false }
        let startPoints = Set(lines.map { $0.start })
        let endPoints = Set(lines.map { $0.end })
        return startPoints.count == endPoints.count && startPoints.intersection(endPoints).count > 0
    }

    func clearAll() {
        points.removeAll()
        entities.removeAll()
        constraintManager.clearAll()
        pendingConstraints.removeAll()
        solverConverged = false
        isDirty = true
    }

    func connectToProvider(_ provider: VertexProvider, updater: VertexUpdater) {
        self.vertexProvider = provider
        self.vertexUpdater = updater
        logger.info("CADSketchEngine connected to provider and updater")
    }

    func getSketchLines() -> [(CGPoint, CGPoint)] {
        var lines: [(CGPoint, CGPoint)] = []
        for entity in entities {
            if case .line(let l) = entity {
                if let s = points.first(where: { $0.id == l.start }),
                   let e = points.first(where: { $0.id == l.end }) {
                    lines.append((
                        CGPoint(x: CGFloat(s.position.x), y: CGFloat(s.position.y)),
                        CGPoint(x: CGFloat(e.position.x), y: CGFloat(e.position.y))
                    ))
                }
            }
        }
        return lines
    }

    func setStrokeWidth(_ pressure: CGFloat) {
        currentStrokeWidth = 1.0 + pressure * 8.0
    }

    func importPencilKitStrokes(_ strokes: [PKStroke]) -> [SketchEntity] {
        var result: [SketchEntity] = []

        for stroke in strokes {
            let path = stroke.path
            guard path.creationDate != .distantPast else { continue }

            let count = path.count
            guard count >= 2 else {
                if count == 1 {
                    let pos = path.interpolatedLocation(at: 0)
                    let pt = SketchPoint(position: SIMD2<Float>(Float(pos.x), Float(pos.y)))
                    points.append(pt)
                    entities.append(.point(pt))
                    result.append(.point(pt))
                }
                continue
            }

            var rawPoints: [SIMD2<Float>] = []
            for i in 0..<count {
                let loc = path.interpolatedLocation(at: CGFloat(i) / CGFloat(max(1, count - 1)))
                rawPoints.append(SIMD2<Float>(Float(loc.x), Float(loc.y)))
            }

            let simplified = ramerDouglasPeucker(rawPoints, epsilon: 1.0)

            guard simplified.count >= 2 else { continue }

            let detected = detectShape(from: simplified)
            for entity in detected {
                result.append(entity)
                entities.append(entity)
                switch entity {
                case .point(let p): points.append(p)
                case .line(let l):
                    if !points.contains(where: { $0.id == l.start }) {
                        points.append(SketchPoint(id: l.start, position: simplified.first ?? SIMD2<Float>(0, 0)))
                    }
                    if !points.contains(where: { $0.id == l.end }) {
                        points.append(SketchPoint(id: l.end, position: simplified.last ?? SIMD2<Float>(0, 0)))
                    }
                case .circle(let c):
                    if !points.contains(where: { $0.id == c.center }) {
                        points.append(SketchPoint(id: c.center, position: simplified.first ?? SIMD2<Float>(0, 0)))
                    }
                case .rectangle(let r):
                    if !points.contains(where: { $0.id == r.origin }) {
                        points.append(SketchPoint(id: r.origin, position: simplified.first ?? SIMD2<Float>(0, 0)))
                    }
                case .arc(let a):
                    if !points.contains(where: { $0.id == a.center }) {
                        points.append(SketchPoint(id: a.center, position: simplified.first ?? SIMD2<Float>(0, 0)))
                    }
                }
            }
        }

        isDirty = true
        return result
    }

    private func detectShape(from points: [SIMD2<Float>]) -> [SketchEntity] {
        guard points.count >= 2 else { return [] }

        let first = points.first!
        let last = points.last!
        let totalDist = totalPathLength(points)

        let startEndGap = simd_length(last - first)
        let isClosed = startEndGap < totalDist * 0.1

        if points.count == 2 {
            let startId = UUID()
            let endId = UUID()
            let line = SketchLine(id: UUID(), start: startId, end: endId)
            return [.point(SketchPoint(id: startId, position: first)),
                    .point(SketchPoint(id: endId, position: last)),
                    .line(line)]
        }

        if isClosed {
            let sides = detectCornerCount(points)
            if sides == 4 {
                let minX = points.map(\.x).min()!
                let maxX = points.map(\.x).max()!
                let minY = points.map(\.y).min()!
                let maxY = points.map(\.y).max()!
                let originId = UUID()
                let origin = SketchPoint(id: originId, position: SIMD2<Float>(minX, minY))
                let size = SIMD2<Float>(maxX - minX, maxY - minY)
                let rect = SketchRectangle(id: UUID(), origin: originId, size: size)
                return [.point(origin), .rectangle(rect)]
            } else if deviationFromIdealRadius(points) < 0.15 {
                let center = points.reduce(SIMD2<Float>(0, 0), +) / Float(points.count)
                let avgRadius = points.reduce(Float(0)) { $0 + simd_length($1 - center) } / Float(points.count)
                let centerId = UUID()
                let circle = SketchCircle(id: UUID(), center: centerId, radius: avgRadius)
                return [.point(SketchPoint(id: centerId, position: center)), .circle(circle)]
            } else {
                return splitToLines(points)
            }
        }

        if simd_length(last - first) < totalDist * 0.05 {
            let center = points.reduce(SIMD2<Float>(0, 0), +) / Float(points.count)
            let avgRadius = points.reduce(Float(0)) { $0 + simd_length($1 - center) } / Float(points.count)
            let centerId = UUID()
            let arc = SketchArc(id: UUID(), center: centerId, radius: avgRadius,
                                startAngle: atan2(first.y - center.y, first.x - center.x),
                                endAngle: atan2(last.y - center.y, last.x - center.x))
            return [.point(SketchPoint(id: centerId, position: center)), .arc(arc)]
        }

        return splitToLines(points)
    }

    private func splitToLines(_ points: [SIMD2<Float>]) -> [SketchEntity] {
        var entities: [SketchEntity] = []
        for i in 0..<(points.count - 1) {
            let startId = UUID()
            let endId = UUID()
            entities.append(.point(SketchPoint(id: startId, position: points[i])))
            entities.append(.point(SketchPoint(id: endId, position: points[i + 1])))
            entities.append(.line(SketchLine(id: UUID(), start: startId, end: endId)))
        }
        return entities
    }

    private func totalPathLength(_ points: [SIMD2<Float>]) -> Float {
        guard points.count >= 2 else { return 0 }
        var total: Float = 0
        for i in 0..<(points.count - 1) {
            total += simd_length(points[i + 1] - points[i])
        }
        return total
    }

    private func detectCornerCount(_ points: [SIMD2<Float>]) -> Int {
        guard points.count >= 4 else { return points.count }
        var corners = 0
        let step = max(1, points.count / 20)
        for i in stride(from: 1, to: points.count - 1, by: step) {
            let v1 = points[i] - points[i - 1]
            let v2 = points[(i + 1) % points.count] - points[i]
            let angle = abs(atan2(simd_length(simd_cross(SIMD3<Float>(v1.x, v1.y, 0), SIMD3<Float>(v2.x, v2.y, 0))),
                                   simd_dot(v1, v2)))
            if angle > .pi / 4 {
                corners += 1
            }
        }
        return corners
    }

    private func deviationFromIdealRadius(_ points: [SIMD2<Float>]) -> Float {
        let center = points.reduce(SIMD2<Float>(0, 0), +) / Float(points.count)
        let avgRadius = points.reduce(Float(0)) { $0 + simd_length($1 - center) } / Float(points.count)
        guard avgRadius > 0 else { return 1.0 }
        let variance = points.reduce(Float(0)) { $0 + pow(simd_length($1 - center) - avgRadius, 2) } / Float(points.count)
        return variance / (avgRadius * avgRadius)
    }

    private func ramerDouglasPeucker(_ points: [SIMD2<Float>], epsilon: Float) -> [SIMD2<Float>] {
        guard points.count > 2 else { return points }
        let eps2 = epsilon * epsilon
        var maxDist: Float = 0
        var maxIndex = 0
        let first = points.first!
        let last = points.last!
        let segment = last - first
        let segLen2 = simd_length_squared(segment)

        for i in 1..<(points.count - 1) {
            var dist: Float
            if segLen2 < 1e-9 {
                dist = simd_length_squared(points[i] - first)
            } else {
                let t = max(0, min(1, simd_dot(points[i] - first, segment) / segLen2))
                let proj = first + segment * t
                dist = simd_length_squared(points[i] - proj)
            }
            if dist > maxDist {
                maxDist = dist
                maxIndex = i
            }
        }

        if maxDist > eps2 {
            let left = ramerDouglasPeucker(Array(points[0...maxIndex]), epsilon: epsilon)
            let right = ramerDouglasPeucker(Array(points[maxIndex...]), epsilon: epsilon)
            return left.dropLast() + right
        }

        return [points.first!, points.last!]
    }

    func convertToProfile() -> [SIMD2<Float>]? {
        var profile: [SIMD2<Float>] = []

        let lines = entities.compactMap { entity -> (UUID, UUID)? in
            if case .line(let l) = entity { return (l.start, l.end) }
            return nil
        }

        guard !lines.isEmpty else {
            for entity in entities {
                switch entity {
                case .point(let p): profile.append(p.position)
                case .circle(let c):
                    if let cp = points.first(where: { $0.id == c.center }) {
                        let segments = 32
                        for i in 0..<segments {
                            let angle = Float(i) * 2 * .pi / Float(segments)
                            profile.append(cp.position + SIMD2<Float>(cos(angle) * c.radius, sin(angle) * c.radius))
                        }
                    }
                case .rectangle(let r):
                    if let op = points.first(where: { $0.id == r.origin }) {
                        profile.append(op.position)
                        profile.append(op.position + SIMD2<Float>(r.size.x, 0))
                        profile.append(op.position + r.size)
                        profile.append(op.position + SIMD2<Float>(0, r.size.y))
                    }
                default: break
                }
            }
            return profile.count >= 3 ? profile : nil
        }

        var adj: [UUID: [UUID]] = [:]
        for (s, e) in lines {
            adj[s, default: []].append(e)
            adj[e, default: []].append(s)
        }

        guard let start = adj.keys.first else { return nil }
        var visited: Set<UUID> = []
        var current = start
        var prev: UUID? = nil

        while true {
            visited.insert(current)
            if let pt = points.first(where: { $0.id == current }) {
                profile.append(pt.position)
            }
            let neighbors = adj[current] ?? []
            var next: UUID? = nil
            for n in neighbors {
                if !visited.contains(n) {
                    next = n
                    break
                }
            }
            if let n = next {
                prev = current
                current = n
            } else {
                break
            }
        }

        return profile.count >= 3 ? profile : nil
    }

    func closeProfile() {
        guard entities.count >= 2 else { return }

        let lines = entities.compactMap { entity -> SketchLine? in
            if case .line(let l) = entity { return l }
            return nil
        }
        guard lines.count >= 2 else { return }

        let allStartIDs = Set(lines.map { $0.start })
        let allEndIDs = Set(lines.map { $0.end })
        let onlyStart = allStartIDs.subtracting(allEndIDs)
        let onlyEnd = allEndIDs.subtracting(allStartIDs)

        if let first = onlyStart.first, let last = onlyEnd.first, first != last {
            let closingLine = SketchLine(start: last, end: first)
            entities.append(.line(closingLine))
            isDirty = true
        }
    }

    func logOperation(type: CADOperationType, description: String, affectedIDs: [UUID] = [], parameters: [String: Double] = [:]) {
        let op = CADOperation(type: type, affectedModelIDs: affectedIDs, description: description, parameters: parameters)
        historyTree.pushOperation(op)
        isDirty = true
        logger.info("CADSketchEngine: logged operation '\(description)' type=\(type.rawValue)")
    }
}
