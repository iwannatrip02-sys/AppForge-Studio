import Foundation
import simd
import Metal
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "SDFEngine")

struct SDFGrid {
    let gridSize: Int
    let voxelSize: Float
    let origin: SIMD3<Float>
    var values: [Float]

    init(gridSize: Int, voxelSize: Float, origin: SIMD3<Float>, values: [Float]) {
        self.gridSize = gridSize
        self.voxelSize = voxelSize
        self.origin = origin
        self.values = values
    }

    func index(_ i: Int, _ j: Int, _ k: Int) -> Int { return i * gridSize * gridSize + j * gridSize + k }
    func sample(_ i: Int, _ j: Int, _ k: Int) -> Float {
        guard i >= 0, i < gridSize, j >= 0, j < gridSize, k >= 0, k < gridSize else { return Float.greatestFiniteMagnitude }
        return values[index(i, j, k)]
    }
    func worldPos(_ i: Int, _ j: Int, _ k: Int) -> SIMD3<Float> { return origin + SIMD3<Float>(Float(i), Float(j), Float(k)) * voxelSize }
}

enum BooleanOp { case union, intersection, difference }

let edgeVertices: [(Int,Int)] = [(0,1),(1,2),(2,3),(3,0),(4,5),(5,6),(6,7),(7,4),(0,4),(1,5),(2,6),(3,7)]

/// Standard marching cubes triangle table: maps each of 256 cube configurations
/// to edge-index triplets forming triangles. -1 terminates each entry.
private let triTable: [[Int]] = [
    [],
    [0,8,3],
    [0,1,9],
    [1,8,3,9,8,1],
    [1,2,10],
    [0,8,3,1,2,10],
    [9,2,10,0,2,9],
    [2,8,3,2,10,8,10,9,8],
    [3,11,2],
    [0,11,2,8,11,0],
    [1,9,0,2,3,11],
    [1,11,2,1,9,11,9,8,11],
    [3,10,1,11,10,3],
    [0,10,1,0,8,10,8,11,10],
    [3,9,0,3,11,9,11,10,9],
    [9,8,10,10,8,11],
    [4,7,8],
    [4,3,0,7,3,4],
    [0,1,9,8,4,7],
    [4,1,9,4,7,1,7,3,1],
    [1,2,10,8,4,7],
    [3,4,7,3,0,4,1,2,10],
    [9,2,10,9,0,2,8,4,7],
    [2,10,9,2,9,7,2,7,3,7,9,4],
    [8,4,7,3,11,2],
    [11,4,7,11,2,4,2,0,4],
    [9,0,1,8,4,7,2,3,11],
    [4,7,11,9,4,11,9,11,2,9,2,1],
    [3,10,1,3,11,10,7,8,4],
    [1,11,10,1,4,11,1,0,4,7,11,4],
    [4,7,8,9,0,11,9,11,10,11,0,3],
    [4,7,11,4,11,9,9,11,10],
    [9,5,4],
    [9,5,4,0,8,3],
    [0,5,4,1,5,0],
    [8,5,4,8,3,5,3,1,5],
    [1,2,10,9,5,4],
    [3,0,8,1,2,10,4,9,5],
    [5,2,10,5,4,2,4,0,2],
    [2,10,5,3,2,5,3,5,4,3,4,8],
    [9,5,4,2,3,11],
    [0,11,2,0,8,11,4,9,5],
    [0,5,4,0,1,5,2,3,11],
    [2,1,5,2,5,8,2,8,11,4,8,5],
    [10,3,11,10,1,3,9,5,4],
    [4,9,5,0,8,1,8,10,1,8,11,10],
    [5,4,0,5,0,11,5,11,10,11,0,3],
    [5,4,8,5,8,10,10,8,11],
    [9,7,8,5,7,9],
    [9,3,0,9,5,3,5,7,3],
    [0,7,8,0,1,7,1,5,7],
    [1,5,3,3,5,7],
    [9,7,8,9,5,7,10,1,2],
    [10,1,2,9,5,0,5,3,0,5,7,3],
    [8,0,2,8,2,5,8,5,7,10,2,5],
    [2,10,5,2,5,3,3,5,7],
    [7,11,2,7,8,11,5,9,4],
    [9,5,4,0,11,2,0,8,11,0,2,3],
    [2,3,11,0,1,8,1,7,8,1,5,7],
    [11,2,1,11,1,7,7,1,5],
    [9,5,8,8,5,7,10,1,3,10,3,11],
    [5,7,0,5,0,9,7,11,0,1,0,10,11,10,0],
    [11,10,0,11,0,3,10,5,0,8,0,7,5,7,0],
    [11,10,5,7,11,5],
    [10,6,5],
    [0,8,3,5,10,6],
    [9,0,1,5,10,6],
    [1,8,3,1,9,8,5,10,6],
    [1,6,5,2,6,1],
    [1,6,5,1,2,6,3,0,8],
    [9,6,5,9,0,6,0,2,6],
    [5,9,8,5,8,2,5,2,6,3,2,8],
    [2,3,11,10,6,5],
    [11,0,8,11,2,0,10,6,5],
    [0,1,9,2,3,11,5,10,6],
    [5,10,6,1,9,2,9,11,2,9,8,11],
    [6,3,11,6,5,3,5,1,3],
    [0,8,11,0,11,5,0,5,1,5,11,6],
    [3,11,6,0,3,6,0,6,5,0,5,9],
    [6,5,9,6,9,11,11,9,8],
    [5,10,6,4,7,8],
    [4,3,0,4,7,3,6,5,10],
    [1,9,0,5,10,6,8,4,7],
    [10,6,5,1,9,7,1,7,3,7,9,4],
    [6,1,2,6,5,1,4,7,8],
    [1,2,5,5,2,6,3,0,4,3,4,7],
    [8,4,7,9,0,5,0,6,5,0,2,6],
    [7,3,9,7,9,4,3,2,9,5,9,6,2,6,9],
    [3,11,2,7,8,4,10,6,5],
    [5,10,6,4,7,2,4,2,0,2,7,11],
    [0,1,9,4,7,8,2,3,11,5,10,6],
    [9,2,1,9,11,2,9,4,11,7,11,4,5,10,6],
    [8,4,7,3,11,5,3,5,1,5,11,6],
    [5,1,11,5,11,6,1,0,11,7,11,4,0,4,11],
    [0,5,9,0,6,5,0,3,6,11,6,3,8,4,7],
    [6,5,9,6,9,11,4,7,9,7,11,9],
    [10,4,9,6,4,10],
    [4,10,6,4,9,10,0,8,3],
    [10,0,1,10,6,0,6,4,0],
    [8,3,1,8,1,6,8,6,4,6,1,10],
    [1,4,9,1,2,4,2,6,4],
    [3,0,8,1,2,9,2,4,9,2,6,4],
    [0,2,4,4,2,6],
    [8,3,2,8,2,4,4,2,6],
    [10,4,9,10,6,4,11,2,3],
    [0,8,2,2,8,11,4,9,10,4,10,6],
    [3,11,2,0,1,6,0,6,4,6,1,10],
    [6,4,1,6,1,10,4,8,1,2,1,11,8,11,1],
    [9,6,4,9,3,6,9,1,3,11,6,3],
    [8,11,1,8,1,0,11,6,1,9,1,4,6,4,1],
    [3,11,6,3,6,0,0,6,4],
    [6,4,8,11,6,8],
    [7,10,6,7,8,10,8,9,10],
    [0,7,3,0,10,7,0,9,10,6,7,10],
    [10,6,7,1,10,7,1,7,8,1,8,0],
    [10,6,7,10,7,1,1,7,3],
    [1,2,6,1,6,8,1,8,9,8,6,7],
    [2,6,9,2,9,1,6,7,9,0,9,3,7,3,9],
    [7,8,0,7,0,6,6,0,2],
    [7,3,2,6,7,2],
    [2,3,11,10,6,8,10,8,9,8,6,7],
    [2,0,7,2,7,11,0,9,7,6,7,10,9,10,7],
    [1,8,0,1,7,8,1,10,7,6,7,10,2,3,11],
    [11,2,1,11,1,7,10,6,1,6,7,1],
    [8,9,6,8,6,7,9,1,6,11,6,3,1,3,6],
    [0,9,1,11,6,7],
    [7,8,0,7,0,6,3,11,0,11,6,0],
    [7,11,6],
    [7,6,11],
    [3,0,8,11,7,6],
    [0,1,9,11,7,6],
    [8,1,9,8,3,1,11,7,6],
    [10,1,2,6,11,7],
    [1,2,10,3,0,8,6,11,7],
    [2,9,0,2,10,9,6,11,7],
    [6,11,7,2,10,3,10,8,3,10,9,8],
    [7,2,3,6,2,7],
    [7,0,8,7,6,0,6,2,0],
    [2,7,6,2,3,7,0,1,9],
    [1,6,2,1,8,6,1,9,8,8,7,6],
    [10,7,6,10,1,7,1,3,7],
    [10,7,6,1,7,10,1,8,7,1,0,8],
    [0,3,7,0,7,10,0,10,9,6,10,7],
    [7,6,10,7,10,8,8,10,9],
    [6,8,4,11,8,6],
    [3,6,11,3,0,6,0,4,6],
    [8,6,11,8,4,6,9,0,1],
    [9,4,6,9,6,3,9,3,1,11,3,6],
    [6,8,4,6,11,8,2,10,1],
    [1,2,10,3,0,11,0,6,11,0,4,6],
    [4,11,8,4,6,11,0,2,9,2,10,9],
    [10,9,3,10,3,2,9,4,3,11,3,6,4,6,3],
    [8,2,3,8,6,2,8,4,6,6,2,7],
    [0,2,3,0,4,2,0,8,4,6,2,4],
    [9,0,1,8,4,6,8,6,2,8,2,3,6,2,7],
    [9,4,6,9,6,3,9,3,1,2,3,6,2,3,7],
    [8,1,3,8,6,1,8,4,6,6,10,1],
    [10,1,0,10,0,6,6,0,4],
    [4,6,3,4,3,8,6,10,3,0,3,9,10,9,3],
    [10,9,4,6,10,4],
    [4,9,5,7,6,11],
    [0,8,3,4,9,5,11,7,6],
    [5,0,1,5,4,0,7,6,11],
    [11,7,6,8,3,4,3,5,4,3,1,5],
    [9,5,4,10,1,2,7,6,11],
    [6,11,7,1,2,10,0,8,3,4,9,5],
    [7,6,11,5,4,10,4,2,10,4,0,2],
    [3,4,8,3,5,4,3,2,5,10,5,2,11,7,6],
    [7,2,3,7,6,2,5,4,9],
    [9,5,4,0,8,6,0,6,2,6,8,7],
    [3,6,2,3,7,6,1,5,0,5,4,0],
    [6,2,8,6,8,7,2,1,8,4,8,5,1,5,8],
    [9,5,4,10,1,6,1,7,6,1,3,7],
    [1,6,10,1,7,6,1,0,7,8,7,0,9,5,4],
    [4,0,10,4,10,5,0,3,10,6,10,7,3,7,10],
    [7,6,10,7,10,8,5,4,10,4,8,10],
    [6,9,5,6,11,9,11,8,9],
    [3,6,11,0,6,3,0,5,6,0,9,5],
    [0,11,8,0,5,11,0,1,5,5,11,6],
    [6,11,3,6,3,5,5,3,1],
    [1,2,10,9,5,11,9,11,8,11,5,6],
    [0,11,3,0,6,11,0,9,6,5,6,9,1,2,10],
    [11,8,5,11,5,6,8,0,5,10,5,2,0,2,5],
    [6,11,3,6,3,5,2,10,3,10,5,3],
    [5,8,9,5,2,8,5,6,2,3,8,2],
    [9,5,6,9,6,0,0,6,2],
    [1,5,8,1,8,0,5,6,8,3,8,2,6,2,8],
    [1,5,6,2,1,6],
    [1,3,6,1,6,10,3,8,6,5,6,9,8,9,6],
    [10,1,0,10,0,6,9,5,0,5,6,0],
    [0,3,8,5,6,10],
    [10,5,6],
    [11,5,10,7,5,11],
    [11,5,10,11,7,5,8,3,0],
    [5,11,7,5,10,11,1,9,0],
    [10,7,5,10,11,7,9,8,1,8,3,1],
    [11,1,2,11,7,1,7,5,1],
    [0,8,3,1,2,7,1,7,5,7,2,11],
    [9,7,5,9,2,7,9,0,2,2,7,11],
    [7,5,2,7,2,11,5,9,2,3,2,8,9,8,2],
    [2,5,10,2,3,5,3,7,5],
    [8,2,0,8,5,2,8,7,5,10,2,5],
    [9,0,1,5,10,3,5,3,7,3,10,2],
    [9,8,2,9,2,1,8,7,2,10,2,5,7,5,2],
    [1,3,5,3,7,5],
    [0,8,7,0,7,1,1,7,5],
    [9,0,3,9,3,5,5,3,7],
    [9,8,7,5,9,7],
    [5,8,4,5,10,8,10,11,8],
    [5,0,4,5,11,0,5,10,11,11,0,3],
    [0,1,9,8,4,10,8,10,11,10,4,5],
    [10,11,4,10,4,5,11,3,4,9,4,1,3,1,4],
    [2,5,1,2,8,5,2,11,8,4,5,8],
    [0,4,3,0,5,4,2,11,1,2,8,1,2,11,8,5,1,8],
    [0,2,5,0,5,9,2,11,5,4,5,8,11,8,5],
    [9,4,5,2,11,3],
    [2,5,10,3,5,2,3,4,5,3,8,4],
    [5,10,2,5,2,4,4,2,0],
    [3,10,2,3,5,10,3,8,5,4,5,8,0,1,9],
    [5,10,2,5,2,4,1,9,2,9,4,2],
    [8,4,5,8,5,3,3,5,1],
    [0,4,5,1,0,5],
    [8,4,5,8,5,3,9,0,5,0,3,5],
    [9,4,5],
    [4,11,7,4,9,11,9,10,11],
    [0,8,3,4,9,7,9,11,7,9,10,11],
    [1,10,11,1,11,4,1,4,0,7,4,11],
    [3,1,4,3,4,8,1,10,4,7,4,11,10,11,4],
    [4,11,7,9,11,4,9,2,11,9,1,2],
    [9,7,4,9,11,7,9,1,11,2,11,1,0,8,3],
    [11,7,4,11,4,2,2,4,0],
    [11,7,4,11,4,2,8,3,4,3,2,4],
    [2,9,10,2,7,9,2,3,7,7,9,4],
    [9,10,7,9,7,4,10,2,7,8,7,0,2,0,7],
    [3,7,10,3,10,2,7,4,10,1,10,0,4,0,10],
    [1,10,2,8,7,4],
    [4,9,1,4,1,7,7,1,3],
    [4,9,1,4,1,7,0,8,1,8,7,1],
    [4,0,3,7,4,3],
    [4,8,7],
    [9,10,8,10,11,8],
    [3,0,9,3,9,11,11,9,10],
    [0,1,10,0,10,8,8,10,11],
    [3,1,10,11,3,10],
    [1,2,11,1,11,9,9,11,8],
    [3,0,9,3,9,11,1,2,9,2,11,9],
    [0,2,11,8,0,11],
    [3,2,11],
    [2,3,8,2,8,10,10,8,9],
    [9,10,2,0,9,2],
    [2,3,8,2,8,10,0,1,8,1,10,8],
    [1,10,2],
    [1,3,8,9,1,8],
    [0,9,1],
    [0,3,8],
    []
]

private func interpolateEdge(_ g: SDFGrid, _ ei: Int, _ i: Int, _ j: Int, _ k: Int) -> SIMD3<Float> {
    let offsets: [(Int,Int,Int)] = [(0,0,0),(1,0,0),(1,1,0),(0,1,0),(0,0,1),(1,0,1),(1,1,1),(0,1,1)]
    let (di1, dj1, dk1) = offsets[edgeVertices[ei].0]
    let (di2, dj2, dk2) = offsets[edgeVertices[ei].1]
    let v1 = g.sample(i+di1, j+dj1, k+dk1)
    let v2 = g.sample(i+di2, j+dj2, k+dk2)
    let p1 = g.worldPos(i+di1, j+dj1, k+dk1)
    let p2 = g.worldPos(i+di2, j+dj2, k+dk2)
    if abs(v2 - v1) < 1e-8 { return p1 }
    let t = -v1 / (v2 - v1)
    return p1 + (p2 - p1) * t
}

func marchingCubes(grid: SDFGrid, voxelI: Int, voxelJ: Int, voxelK: Int, vertices: inout [SIMD3<Float>], triangles: inout [UInt32]) {
    let cubeValues = [
        grid.sample(voxelI, voxelJ, voxelK),
        grid.sample(voxelI+1, voxelJ, voxelK),
        grid.sample(voxelI+1, voxelJ+1, voxelK),
        grid.sample(voxelI, voxelJ+1, voxelK),
        grid.sample(voxelI, voxelJ, voxelK+1),
        grid.sample(voxelI+1, voxelJ, voxelK+1),
        grid.sample(voxelI+1, voxelJ+1, voxelK+1),
        grid.sample(voxelI, voxelJ+1, voxelK+1)
    ]
    var cubeIndex = 0
    for v in 0..<8 { if cubeValues[v] < 0 { cubeIndex |= 1 << v } }
    if cubeIndex == 0 || cubeIndex == 255 { return }

    let edges = [
        interpolateEdge(grid, 0, voxelI, voxelJ, voxelK),
        interpolateEdge(grid, 1, voxelI, voxelJ, voxelK),
        interpolateEdge(grid, 2, voxelI, voxelJ, voxelK),
        interpolateEdge(grid, 3, voxelI, voxelJ, voxelK),
        interpolateEdge(grid, 4, voxelI, voxelJ, voxelK),
        interpolateEdge(grid, 5, voxelI, voxelJ, voxelK),
        interpolateEdge(grid, 6, voxelI, voxelJ, voxelK),
        interpolateEdge(grid, 7, voxelI, voxelJ, voxelK),
        interpolateEdge(grid, 8, voxelI, voxelJ, voxelK),
        interpolateEdge(grid, 9, voxelI, voxelJ, voxelK),
        interpolateEdge(grid, 10, voxelI, voxelJ, voxelK),
        interpolateEdge(grid, 11, voxelI, voxelJ, voxelK)
    ]

    let tri = triTable[cubeIndex]
    var localVerts: [SIMD3<Float>] = []
    for tIdx in stride(from: 0, to: tri.count, by: 3) {
        let e0 = tri[tIdx]
        let e1 = tri[tIdx+1]
        let e2 = tri[tIdx+2]
        localVerts.append(edges[e0])
        localVerts.append(edges[e1])
        localVerts.append(edges[e2])
    }

    let baseIndex = UInt32(vertices.count)
    for v in localVerts { vertices.append(v) }
    for vi in 0..<UInt32(localVerts.count / 3) {
        triangles.append(baseIndex + vi * 3)
        triangles.append(baseIndex + vi * 3 + 1)
        triangles.append(baseIndex + vi * 3 + 2)
    }
}

struct SDFEngine {
    static func pointToTriangle(_ p: SIMD3<Float>, a: SIMD3<Float>, b: SIMD3<Float>, c: SIMD3<Float>) -> Float {
        let ab = b - a, ac = c - a, ap = p - a
        let d1 = simd_dot(ab, ap), d2 = simd_dot(ac, ap)
        if d1 <= 0 && d2 <= 0 { return simd_distance(p, a) }
        let bp = p - b, d3 = simd_dot(ab, bp), d4 = simd_dot(ac, bp)
        if d3 >= 0 && d4 <= 0 { return simd_distance(p, b) }
        let cp = p - c, d5 = simd_dot(ab, cp), d6 = simd_dot(ac, cp)
        if d5 >= 0 && d6 >= 0 { return simd_distance(p, c) }
        let vc = simd_dot(simd_cross(ab, ac), ap)
        if vc >= 0 && d1 >= 0 && d3 <= 0 { return simd_distance(p, a + ab * (d1 / simd_dot(ab, ab))) }
        let vb = -d5 * simd_dot(ac, ac) + d6 * simd_dot(ab, ac)
        if vb >= 0 && d2 >= 0 && d6 <= 0 { return simd_distance(p, a + ac * (d2 / simd_dot(ac, ac))) }
        let va = simd_dot(simd_cross(ab, ac), ap)
        if va >= 0 && vb >= 0 && vc >= 0 {
            let denom = simd_dot(simd_cross(ab, ac), simd_cross(ab, ac))
            if denom == 0 { return simd_distance(p, a) }
            let u = vb / denom, v = vc / denom
            return simd_distance(p, a * (1 - u - v) + b * u + c * v)
        }
        return simd_distance(p, a)
    }

    static func signedDistance(_ p: SIMD3<Float>, vertices: [SIMD3<Float>], indices: [UInt32]) -> Float {
        var absDist = Float.greatestFiniteMagnitude
        for i in 0..<(indices.count / 3) {
            let i0 = Int(indices[i*3]), i1 = Int(indices[i*3+1]), i2 = Int(indices[i*3+2])
            guard i0 < vertices.count, i1 < vertices.count, i2 < vertices.count else { continue }
            let d = pointToTriangle(p, a: vertices[i0], b: vertices[i1], c: vertices[i2])
            if d < absDist { absDist = d }
        }
        if absDist == Float.greatestFiniteMagnitude { return absDist }
        var intersections = 0
        for i in 0..<(indices.count / 3) {
            let i0 = Int(indices[i*3]), i1 = Int(indices[i*3+1]), i2 = Int(indices[i*3+2])
            guard i0 < vertices.count, i1 < vertices.count, i2 < vertices.count else { continue }
            let a = vertices[i0], b = vertices[i1], c = vertices[i2]
            let edge1 = b - a, edge2 = c - a
            let h = simd_cross(SIMD3<Float>(1,0,0), edge2)
            let det = simd_dot(edge1, h)
            if abs(det) < 1e-8 { continue }
            let f = 1.0 / det, s = p - a
            let u = f * simd_dot(s, h)
            if u < 0 || u > 1 { continue }
            let q = simd_cross(s, edge1)
            let v = f * simd_dot(SIMD3<Float>(1,0,0), q)
            if v < 0 || u + v > 1 { continue }
            let t = f * simd_dot(edge2, q)
            if t > 1e-8 { intersections += 1 }
        }
        return intersections % 2 == 1 ? -absDist : absDist
    }

    static func meshToSDFGridCPU(mesh: Mesh, gridSize: Int = 64, voxelSize: Float? = nil) -> SDFGrid {
        guard !mesh.vertices.isEmpty, !mesh.indices.isEmpty else {
            return SDFGrid(gridSize: gridSize, voxelSize: 1, origin: .zero,
                          values: Array(repeating: Float.greatestFiniteMagnitude, count: gridSize*gridSize*gridSize))
        }
        let rawVerts: [SIMD3<Float>] = mesh.vertices.map { $0.position }
        var minB = rawVerts[0], maxB = rawVerts[0]
        for v in rawVerts { minB = simd_min(minB, v); maxB = simd_max(maxB, v) }
        let extent = maxB - minB
        let maxExtent = max(extent.x, max(extent.y, extent.z))
        let vSize = voxelSize ?? (maxExtent / Float(gridSize - 1))
        let origin = minB - SIMD3<Float>(repeating: vSize * 0.5)
        var values = Array(repeating: Float.greatestFiniteMagnitude, count: gridSize*gridSize*gridSize)
        for i in 0..<gridSize { for j in 0..<gridSize { for k in 0..<gridSize {
            let wp = origin + SIMD3<Float>(Float(i), Float(j), Float(k)) * vSize
            values[i * gridSize*gridSize + j * gridSize + k] = signedDistance(wp, vertices: rawVerts, indices: mesh.indices)
        }}}
        return SDFGrid(gridSize: gridSize, voxelSize: vSize, origin: origin, values: values)
    }

    static func marchingCubesGPU(grid: SDFGrid, device: MTLDevice) -> Mesh {
        let gs = grid.gridSize
        guard gs > 1, gs < 256 else {
            logger.error("SDFEngine.marchingCubesGPU: gridSize \(gs) out of valid range [2, 255]")
            return Mesh()
        }

        guard let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "marching_cubes_gpu"),
              let pipeline = try? device.makeComputePipelineState(function: function),
              let commandQueue = device.makeCommandQueue() else {
            return Mesh()
        }

        let totalSize = gs * gs * gs
        let activeSize = (gs - 1) * (gs - 1) * (gs - 1)

        guard let sdfBuffer = device.makeBuffer(bytes: grid.values, length: MemoryLayout<Float>.stride * totalSize, options: .storageModeShared),
              let gridSizeBuffer = device.makeBuffer(bytes: [UInt32(gs)], length: MemoryLayout<UInt32>.stride, options: .storageModeShared),
              let voxelSizeBuffer = device.makeBuffer(bytes: [Float(grid.voxelSize)], length: MemoryLayout<Float>.stride, options: .storageModeShared),
              let cubeActive = device.makeBuffer(length: MemoryLayout<UInt32>.stride * activeSize, options: .storageModeShared),
              let vertexCounter = device.makeBuffer(length: MemoryLayout<UInt32>.stride, options: .storageModeShared)
        else { return Mesh() }

        var originArr: [Float] = [grid.origin.x, grid.origin.y, grid.origin.z]
        guard let originBuf = device.makeBuffer(bytes: originArr, length: MemoryLayout<Float>.stride * 3, options: .storageModeShared)
        else { return Mesh() }

        let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let gridWidth = max(1, gs - 1)
        let grid3D = MTLSize(width: gridWidth, height: gridWidth, depth: gridWidth)

        guard grid3D.width > 0, grid3D.height > 0, grid3D.depth > 0 else {
            logger.error("SDFEngine.marchingCubesGPU: invalid dispatch dimensions")
            return Mesh()
        }

        let cmdBuffer = commandQueue.makeCommandBuffer()!
        let encoder = cmdBuffer.makeComputeCommandEncoder()!

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(sdfBuffer, offset: 0, index: 0)
        encoder.setBuffer(gridSizeBuffer, offset: 0, index: 1)
        encoder.setBuffer(voxelSizeBuffer, offset: 0, index: 2)
        encoder.setBuffer(originBuf, offset: 0, index: 3)
        encoder.setBuffer(cubeActive, offset: 0, index: 4)
        encoder.setBuffer(vertexCounter, offset: 0, index: 5)

        encoder.dispatchThreads(grid3D, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()

        var allVerts: [SIMD3<Float>] = []
        var allIndices: [UInt32] = []
        for i in 0..<(gs - 1) {
            for j in 0..<(gs - 1) {
                for k in 0..<(gs - 1) {
                    marchingCubes(grid: grid, voxelI: i, voxelJ: j, voxelK: k, vertices: &allVerts, triangles: &allIndices)
                }
            }
        }

        let vertices = allVerts.map { Vertex(position: $0, normal: SIMD3<Float>(0, 0, 1), uv: SIMD2<Float>(0, 0)) }
        return Mesh(vertices: vertices, indices: allIndices)
    }

    static func voxelize(vertices: [SIMD3<Float>], indices: [UInt32], gridSize: Int = 64) -> SDFGrid {
        guard !vertices.isEmpty, !indices.isEmpty else {
            return SDFGrid(gridSize: gridSize, voxelSize: 1, origin: .zero,
                          values: Array(repeating: Float.greatestFiniteMagnitude, count: gridSize*gridSize*gridSize))
        }
        var minB = vertices[0], maxB = vertices[0]
        for v in vertices { minB = simd_min(minB, v); maxB = simd_max(maxB, v) }
        let extent = maxB - minB
        let maxExtent = max(extent.x, max(extent.y, extent.z))
        let voxelSize = maxExtent / Float(gridSize - 1)
        let origin = minB - SIMD3<Float>(repeating: voxelSize * 0.5)
        var values = Array(repeating: Float.greatestFiniteMagnitude, count: gridSize*gridSize*gridSize)
        for i in 0..<gridSize { for j in 0..<gridSize { for k in 0..<gridSize {
            let wp = origin + SIMD3<Float>(Float(i), Float(j), Float(k)) * voxelSize
            values[i * gridSize*gridSize + j * gridSize + k] = signedDistance(wp, vertices: vertices, indices: indices)
        }}}
        return SDFGrid(gridSize: gridSize, voxelSize: voxelSize, origin: origin, values: values)
    }

    static func combineSDFs(_ a: SDFGrid, _ b: SDFGrid, operation: BooleanOp) -> SDFGrid {
        precondition(a.gridSize == b.gridSize)
        var combined = Array(repeating: Float.greatestFiniteMagnitude, count: a.values.count)
        for i in 0..<a.values.count {
            switch operation {
            case .union: combined[i] = min(a.values[i], b.values[i])
            case .intersection: combined[i] = max(a.values[i], b.values[i])
            case .difference: combined[i] = max(a.values[i], -b.values[i])
            }
        }
        return SDFGrid(gridSize: a.gridSize, voxelSize: a.voxelSize, origin: a.origin, values: combined)
    }

    static func reconstructMesh(from grid: SDFGrid) -> ([SIMD3<Float>], [UInt32]) {
        var vertices: [SIMD3<Float>] = []
        var triangles: [UInt32] = []
        for i in 0..<(grid.gridSize - 1) {
            for j in 0..<(grid.gridSize - 1) {
                for k in 0..<(grid.gridSize - 1) {
                    marchingCubes(grid: grid, voxelI: i, voxelJ: j, voxelK: k, vertices: &vertices, triangles: &triangles)
                }
            }
        }
        return (vertices, triangles)
    }

    static func booleanOperation(meshAVerts: [SIMD3<Float>], meshAIndices: [UInt32],
                                  meshBVerts: [SIMD3<Float>], meshBIndices: [UInt32],
                                  operation: BooleanOp, gridSize: Int = 64) -> ([SIMD3<Float>], [UInt32]) {
        let gridA = voxelize(vertices: meshAVerts, indices: meshAIndices, gridSize: gridSize)
        let gridB = voxelize(vertices: meshBVerts, indices: meshBIndices, gridSize: gridSize)
        let combined = combineSDFs(gridA, gridB, operation: operation)
        return reconstructMesh(from: combined)
    }
}
