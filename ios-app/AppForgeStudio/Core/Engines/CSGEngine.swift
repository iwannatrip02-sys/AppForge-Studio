import Foundation
import simd
import Metal

// MARK: - Nodo del BSP Tree

class BSPNode {
    var plane: (normal: SIMD3<Float>, distance: Float)?
    var front: BSPNode?
    var back: BSPNode?
    var triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
    
    init() {}
}

// MARK: - Motor CSG con BSP Tree

class CSGEngine {
    static let shared = CSGEngine()
    
    private init() {}
    
    // MARK: - Conversion Mesh a triangulos
    
    private func meshToTriangles(_ mesh: Mesh) -> [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] {
        var tris: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
        let verts = mesh.vertices
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            let i0 = Int(mesh.indices[i])
            let i1 = Int(mesh.indices[i+1])
            let i2 = Int(mesh.indices[i+2])
            guard i0 < verts.count, i1 < verts.count, i2 < verts.count else { continue }
            tris.append((verts[i0].position, verts[i1].position, verts[i2].position))
        }
        return tris
    }
    
    private func trianglesToMesh(_ tris: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)], device: MTLDevice?) -> Mesh {
        var verts: [Vertex] = []
        var idx: [UInt32] = []
        var vertMap: [String: UInt32] = [:]
        
        func addVertex(_ pos: SIMD3<Float>) -> UInt32 {
            let key = "\(pos.x),\(pos.y),\(pos.z)"
            if let existing = vertMap[key] { return existing }
            let newIdx = UInt32(verts.count)
            let normal = simd_normalize(pos)
            verts.append(Vertex(position: pos, normal: normal, uv: SIMD2<Float>(0, 0)))
            vertMap[key] = newIdx
            return newIdx
        }
        
        for tri in tris {
            idx.append(addVertex(tri.0))
            idx.append(addVertex(tri.1))
            idx.append(addVertex(tri.2))
        }
        
        var mesh = Mesh(vertices: verts, indices: idx)
        if let d = device { mesh.uploadToGPU(device: d) }
        return mesh
    }
    
    // MARK: - Clasificacion de triangulo respecto a un plano
    
    private enum Side { case front, back, coplanar, spanning }
    
    private func classifyTriangle(_ t: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>), normal: SIMD3<Float>, distance: Float) -> Side {
        var frontCount = 0
        var backCount = 0
        let points = [t.0, t.1, t.2]
        for p in points {
            let d = simd_dot(normal, p) - distance
            if d > 0.001 { frontCount += 1 }
            else if d < -0.001 { backCount += 1 }
        }
        if frontCount == 3 { return .front }
        if backCount == 3 { return .back }
        if frontCount == 0 && backCount == 0 { return .coplanar }
        return .spanning
    }
    
    private func splitTriangle(_ t: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>), normal: SIMD3<Float>, distance: Float) -> (front: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)], back: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)]) {
        var frontTris: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
        var backTris: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
        let points = [t.0, t.1, t.2]
        var frontPoints: [SIMD3<Float>] = []
        var backPoints: [SIMD3<Float>] = []
        for i in 0..<3 {
            let a = points[i]
            let b = points[(i + 1) % 3]
            let dA = simd_dot(normal, a) - distance
            let dB = simd_dot(normal, b) - distance
            if dA >= 0 { frontPoints.append(a) }
            if dA <= 0 { backPoints.append(a) }
            if (dA > 0 && dB < 0) || (dA < 0 && dB > 0) {
                let t_param = dA / (dA - dB)
                let intersection = a + t_param * (b - a)
                frontPoints.append(intersection)
                backPoints.append(intersection)
            }
        }
        if frontPoints.count >= 3 {
            for i in 1..<frontPoints.count - 1 {
                frontTris.append((frontPoints[0], frontPoints[i], frontPoints[i+1]))
            }
        }
        if backPoints.count >= 3 {
            for i in 1..<backPoints.count - 1 {
                backTris.append((backPoints[0], backPoints[i], backPoints[i+1]))
            }
        }
        return (frontTris, backTris)
    }
    
    // MARK: - Construccion de BSP Tree
    
    private func buildBSP(_ triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)], depth: Int = 0) -> BSPNode? {
        guard !triangles.isEmpty else { return nil }
        let node = BSPNode()
        if depth > 10 || triangles.count < 5 {
            node.triangles = triangles
            return node
        }
        let t = triangles[0]
        let edge1 = t.1 - t.0
        let edge2 = t.2 - t.0
        let normal = simd_normalize(simd_cross(edge1, edge2))
        let distance = simd_dot(normal, t.0)
        node.plane = (normal, distance)
        var frontTris: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
        var backTris: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
        for tri in triangles {
            let side = classifyTriangle(tri, normal: normal, distance: distance)
            switch side {
            case .front: frontTris.append(tri)
            case .back: backTris.append(tri)
            case .coplanar: node.triangles.append(tri)
            case .spanning:
                let (f, b) = splitTriangle(tri, normal: normal, distance: distance)
                frontTris.append(contentsOf: f); backTris.append(contentsOf: b)
            }
        }
        node.front = buildBSP(frontTris, depth: depth + 1)
        node.back = buildBSP(backTris, depth: depth + 1)
        return node
    }
    
    // MARK: - Clip contra BSP
    
    private func clipTriangles(_ triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)], by node: BSPNode?) -> [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] {
        guard let node = node else { return triangles }
        guard let (normal, distance) = node.plane else { return triangles }
        var frontList: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
        for tri in triangles {
            let side = classifyTriangle(tri, normal: normal, distance: distance)
            switch side {
            case .front:
                if let f = node.front { frontList.append(contentsOf: clipTriangles([tri], by: f)) }
                else { frontList.append(tri) }
            case .back:
                if let b = node.back { frontList.append(contentsOf: clipTriangles([tri], by: b)) }
            case .coplanar: frontList.append(tri)
            case .spanning:
                let (f, b) = splitTriangle(tri, normal: normal, distance: distance)
                if let fn = node.front { frontList.append(contentsOf: clipTriangles(f, by: fn)) }
                else { frontList.append(contentsOf: f) }
                if let bn = node.back { _ = clipTriangles(b, by: bn) }
            }
        }
        return frontList
    }
    
    // MARK: - Operaciones Publicas
    
    func union(_ a: Mesh, _ b: Mesh, device: MTLDevice) -> Mesh {
        let trisA = meshToTriangles(a); let trisB = meshToTriangles(b)
        guard let bspB = buildBSP(trisB) else { return a }
        let clippedA = clipTriangles(trisA, by: bspB)
        return trianglesToMesh(clippedA + trisB, device: device)
    }
    
    func subtract(_ a: Mesh, _ b: Mesh, device: MTLDevice) -> Mesh {
        let trisA = meshToTriangles(a); let trisB = meshToTriangles(b)
        guard let bspB = buildBSP(trisB) else { return a }
        return trianglesToMesh(clipTriangles(trisA, by: bspB), device: device)
    }
    
    func intersect(_ a: Mesh, _ b: Mesh, device: MTLDevice) -> Mesh {
        let trisA = meshToTriangles(a); let trisB = meshToTriangles(b)
        guard let bspB = buildBSP(trisB) else { return Mesh() }
        let clippedA = clipTriangles(trisA, by: bspB)
        guard let bspA = buildBSP(clippedA) else { return Mesh() }
        let clippedB = clipTriangles(trisB, by: bspA)
        return trianglesToMesh(clippedA + clippedB, device: device)
    }
    
    func mergeMeshes(_ meshes: [Mesh], device: MTLDevice) -> Mesh {
        guard !meshes.isEmpty else { return Mesh() }
        var allTris: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
        for mesh in meshes { allTris.append(contentsOf: meshToTriangles(mesh)) }
        return trianglesToMesh(allTris, device: device)
    }
}