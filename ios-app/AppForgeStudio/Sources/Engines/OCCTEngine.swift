import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "OCCTEngine")

class OCCTEngine {
    static let shared = OCCTEngine()
    private init() {}
    
    func createBox(width: Double, height: Double, depth: Double) -> Shape {
        return Shape.box(width: width, height: height, depth: depth)
    }
    
    func createCylinder(radius: Double, height: Double) -> Shape {
        return Shape.cylinder(radius: radius, height: height)
    }
    
    func createSphere(radius: Double) -> Shape {
        return Shape.sphere(radius: radius)
    }
    
    func createTorus(majorRadius: Double, minorRadius: Double) -> Shape {
        return Shape.torus(majorRadius: majorRadius, minorRadius: minorRadius)
    }
    
    func createCone(radius: Double, height: Double) -> Shape {
        return Shape.cone(radius: radius, height: height)
    }
    
    func union(_ a: Shape, _ b: Shape) -> Shape {
        return a + b
    }
    
    func subtract(_ a: Shape, _ b: Shape) -> Shape {
        return a - b
    }
    
    func intersect(_ a: Shape, _ b: Shape) -> Shape {
        return a & b
    }
    
    func fillet(shape: Shape, radius: Double) -> Shape {
        return shape.filleted(radius: radius)
    }
    
    func chamfer(shape: Shape, radius: Double) -> Shape {
        return shape.chamfered(radius: radius)
    }
    
    func shell(shape: Shape, thickness: Double) -> Shape {
        return shape.shelled(thickness: thickness)
    }
    
    func extrude(profile: Shape, direction: (dx: Double, dy: Double, dz: Double), distance: Double) -> Shape {
        return profile.extruded(direction: direction, distance: distance)
    }
    
    func revolve(profile: Shape, angle: Double) -> Shape {
        return profile.revolved(angle: angle)
    }
    
    func sweep(profile: Shape, along pathPoints: [SIMD3<Double>]) -> Shape {
        guard pathPoints.count >= 2 else { return profile }
        return profile.swept(along: pathPoints)
    }
    
    
    func loft(profiles: [Shape], ruled: Bool = false) -> Shape {
        return Shape.loft(profiles: profiles, ruled: ruled)
    }
    
    // MARK: - History Tree
    
    func executeWithHistory(label: String, action: @escaping () -> Void) {
        historyTree.push(CADHistoryEntry(label: label, snapshotBefore: "", redoAction: action))
        action()
    }
    
    func undoLastOperation() -> Bool {
        guard let _ = historyTree.undo() else { return false }
        return true
    }
    
    func redoLastOperation() -> Bool {
        guard let _ = historyTree.redo() else { return false }
        return true
    }
    
    func exportSTEP(shape: Shape, to url: URL) throws {
        try Exporter.writeSTEP(shape: shape, to: url)
    }
    
    func exportSTL(shape: Shape, to url: URL, deflection: Double = 0.05) throws {
        try Exporter.writeSTL(shape: shape, to: url, deflection: deflection)
    }
    
    func importSTEP(from url: URL) throws -> Shape {
        return try Importer.readSTEP(from: url)
    }
    
    func triangulate(shape: Shape, deflection: Double = 0.1) -> (vertices: [Float], indices: [UInt32]) {
        let mesh = shape.triangulated(deflection: deflection)
        var verts: [Float] = []
        var idxs: [UInt32] = []
        for node in mesh.nodes {
            verts.append(Float(node.x))
            verts.append(Float(node.y))
            verts.append(Float(node.z))
        }
        for triangle in mesh.triangles {
            idxs.append(UInt32(triangle.i1))
            idxs.append(UInt32(triangle.i2))
            idxs.append(UInt32(triangle.i3))
        }
        return (verts, idxs)
    }
    
    // MARK: - Sketch 2D Primitives
    
    func createLine(from: SIMD3<Double>, to: SIMD3<Double>) -> Shape {
        return Shape.line(from: from, to: to)
    }
    
    func createCircle(center: SIMD3<Double>, radius: Double) -> Shape {
        return Shape.circle(center: center, radius: radius)
    }
    
    func createRectangle(origin: SIMD3<Double>, size: SIMD2<Double>) -> Shape {
        return Shape.rect(origin: origin, size: size)
    }
    
    func createArc(center: SIMD3<Double>, radius: Double, startAngle: Double, endAngle: Double) -> Shape {
        return Shape.arc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle)
    }
    
    func createPolygon(points: [SIMD3<Double>]) -> Shape {
        return Shape.polygon(points: points)
    }
    
    func loft(profiles: [Shape]) -> Shape {
        guard profiles.count >= 2 else { return profiles.first ?? Shape() }
        return Shape.loft(profiles: profiles)
    }
    
    // MARK: - Mesh <-> Shape Bridge
    
    func meshToShape(_ mesh: Mesh) -> Shape? {
        guard mesh.vertices.count >= 3, mesh.indices.count >= 3 else { return nil }
        
        let points: [SIMD3<Double>] = mesh.vertices.map { v in
            SIMD3<Double>(Double(v.position.x), Double(v.position.y), Double(v.position.z))
        }
        
        var triangles: [(SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)] = []
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            guard i + 2 < mesh.indices.count else { break }
            let i0 = Int(mesh.indices[i])
            let i1 = Int(mesh.indices[i+1])
            let i2 = Int(mesh.indices[i+2])
            guard i0 < points.count, i1 < points.count, i2 < points.count else { continue }
            triangles.append((points[i0], points[i1], points[i2]))
        }
        
        guard !triangles.isEmpty else { return nil }
        
        do {
            if triangles.count == 1 {
                let (p0, p1, p2) = triangles[0]
                return try Shape.face(p0: p0, p1: p1, p2: p2)
            } else {
                var faces: [Shape] = []
                for (p0, p1, p2) in triangles {
                    if let face = try? Shape.face(p0: p0, p1: p1, p2: p2) {
                        faces.append(face)
                    }
                }
                guard !faces.isEmpty else { return nil }
                let shell = Shape.shell(faces: faces)
                return Shape.solid(shell: shell)
            }
        } catch {
            var minBounds = SIMD3<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
            var maxBounds = SIMD3<Float>(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
            for v in mesh.vertices {
                minBounds = simd_min(minBounds, v.position)
                maxBounds = simd_max(maxBounds, v.position)
            }
            let size = maxBounds - minBounds
            return createBox(width: Double(size.x), height: Double(size.y), depth: Double(size.z))
        }
    }
    
    func shapeToMesh(_ shape: Shape) -> Mesh {
        do {
            let triangles = try shape.triangulate()
            let vertices = triangles.vertices.map { tv in
                Vertex(position: SIMD3<Float>(Float(tv.x), Float(tv.y), Float(tv.z)),
                       normal: SIMD3<Float>(0, 0, 1),
                       uv: SIMD2<Float>(0, 0))
            }
            return Mesh(vertices: vertices, indices: triangles.indices)
        } catch {
            return Mesh()
        }
    }
    
    // MARK: - Measurements on Shape
    
    func measureVolume(_ shape: Shape) -> Double {
        return shape.volume()
    }
    
    func measureArea(_ shape: Shape) -> Double {
        return shape.area()
    }
    
    func measureBoundingBox(_ shape: Shape) -> (min: SIMD3<Double>, max: SIMD3<Double>, size: SIMD3<Double>) {
        let box = shape.boundingBox()
        return (box.min, box.max, box.size)
    }

    // MARK: - STEP Export

    func exportSTEP(shape: Shape, to url: URL) throws {
        let stepData = shape.exportSTEP()
        try stepData.write(to: url, atomically: true, encoding: .utf8)
    }
}
