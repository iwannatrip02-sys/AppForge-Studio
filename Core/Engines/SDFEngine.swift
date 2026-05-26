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
              let vertexCounter = device.makeBuffer(length: MemoryLayout<atomic_uint>.stride, options: .storageModeShared)
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
