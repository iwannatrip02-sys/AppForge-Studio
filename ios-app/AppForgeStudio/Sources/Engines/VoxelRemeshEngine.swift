import Foundation
import simd
import Metal
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "VoxelRemesh")

/// Voxel-based uniform remeshing â€” Nomad Sculpt's "Dynamesh" equivalent.
/// Converts any mesh to a clean, uniform-resolution triangle mesh using SDF marching cubes.
@MainActor
final class VoxelRemeshEngine {
    
    /// Voxel resolution (grid cells per axis). Higher = more detail, slower.
    var resolution: Int = 128
    /// Smoothing iterations after marching cubes. Nomad uses 1-3.
    var smoothingIterations: Int = 2
    /// Target triangle count after simplification (0 = no limit)
    var targetTriangles: Int = 0
    
    private var device: MTLDevice? { MTLCreateSystemDefaultDevice() }
    
    // MARK: - Main entry point
    
    /// Remesh a mesh into uniform topology using SDF voxelization.
    /// Returns a clean, manifold mesh ready for sculpting.
    func remesh(_ mesh: Mesh) -> Mesh {
        guard let device = device else {
            logger.warning("[VoxelRemesh] No Metal device â€” returning original mesh")
            return mesh
        }
        
        // 1. Compute bounding box
        let bounds = computeBounds(mesh)
        let size = max(bounds.size.x, bounds.size.y, bounds.size.z)
        let voxelSize = size / Float(resolution)
        let origin = bounds.min - SIMD3<Float>(repeating: voxelSize) // padding
        
        // 2. Voxelize mesh to SDF
        let sdf = voxelizeToSDF(mesh, origin: origin, voxelSize: voxelSize, gridSize: resolution)
        
        // 3. Extract surface via marching cubes
        let remeshed = marchingCubes(sdf, origin: origin, voxelSize: voxelSize)
        
        // 4. Smooth
        var result = remeshed
        for _ in 0..<smoothingIterations {
            result = smoothLaplacian(result)
        }
        
        // 5. Simplify if target set
        if targetTriangles > 0 && result.indices.count / 3 > targetTriangles {
            result = simplifyMesh(result, targetCount: targetTriangles)
        }
        
        logger.info("[VoxelRemesh] \(mesh.vertices.count) â†’ \(result.vertices.count) vertices (\(result.indices.count/3) triangles)")
        return result
    }
    
    // MARK: - Bounds
    
    private func computeBounds(_ mesh: Mesh) -> (min: SIMD3<Float>, max: SIMD3<Float>, size: SIMD3<Float>) {
        var minPt = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxPt = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for v in mesh.vertices {
            minPt = simd_min(minPt, v.position)
            maxPt = simd_max(maxPt, v.position)
        }
        return (minPt, maxPt, maxPt - minPt)
    }
    
    // MARK: - SDF Voxelization
    
    private func voxelizeToSDF(_ mesh: Mesh, origin: SIMD3<Float>, voxelSize: Float, gridSize: Int) -> SDFGrid {
        let total = gridSize * gridSize * gridSize
        var values = [Float](repeating: Float.greatestFiniteMagnitude, count: total)
        
        let idx = { (i: Int, j: Int, k: Int) -> Int in i * gridSize * gridSize + j * gridSize + k }
        
        // CPU-based voxelization: for each triangle, compute signed distance to nearby voxels
        for t in stride(from: 0, to: mesh.indices.count, by: 3) {
            guard t + 2 < mesh.indices.count else { break }
            let i0 = Int(mesh.indices[t])
            let i1 = Int(mesh.indices[t+1])
            let i2 = Int(mesh.indices[t+2])
            guard i0 < mesh.vertices.count, i1 < mesh.vertices.count, i2 < mesh.vertices.count else { continue }
            
            let v0 = mesh.vertices[i0].position
            let v1 = mesh.vertices[i1].position
            let v2 = mesh.vertices[i2].position
            
            // Triangle bounding box in voxel space
            let triMin = simd_min(simd_min(v0, v1), v2)
            let triMax = simd_max(simd_max(v0, v1), v2)
            
            let iMin = max(0, Int(((triMin.x - origin.x) / voxelSize).rounded(.down)) - 1)
            let jMin = max(0, Int(((triMin.y - origin.y) / voxelSize).rounded(.down)) - 1)
            let kMin = max(0, Int(((triMin.z - origin.z) / voxelSize).rounded(.down)) - 1)
            let iMax = min(gridSize - 1, Int(((triMax.x - origin.x) / voxelSize).rounded(.up)) + 1)
            let jMax = min(gridSize - 1, Int(((triMax.y - origin.y) / voxelSize).rounded(.up)) + 1)
            let kMax = min(gridSize - 1, Int(((triMax.z - origin.z) / voxelSize).rounded(.up)) + 1)
            
            for i in iMin...iMax {
                for j in jMin...jMax {
                    for k in kMin...kMax {
                        let p = SIMD3<Float>(
                            origin.x + Float(i) * voxelSize,
                            origin.y + Float(j) * voxelSize,
                            origin.z + Float(k) * voxelSize
                        )
                        let d = pointToTriangleSDF(p, v0, v1, v2)
                        let cellIdx = idx(i, j, k)
                        if abs(d) < abs(values[cellIdx]) {
                            values[cellIdx] = d
                        }
                    }
                }
            }
        }
        
        return SDFGrid(gridSize: gridSize, voxelSize: voxelSize, origin: origin, values: values)
    }
    
    private func pointToTriangleSDF(_ p: SIMD3<Float>, _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> Float {
        let ab = b - a; let ac = c - a; let ap = p - a
        let d1 = simd_dot(ab, ap); let d2 = simd_dot(ac, ap)
        if d1 <= 0 && d2 <= 0 { return simd_distance(p, a) }
        
        let bp = p - b
        let d3 = simd_dot(ab, bp); let d4 = simd_dot(ac, bp)
        if d3 >= 0 && d4 <= d3 { return simd_distance(p, b) }
        
        let cp = p - c
        let d5 = simd_dot(ab, cp); let d6 = simd_dot(ac, cp)
        if d6 >= 0 && d5 <= d6 { return simd_distance(p, c) }
        
        let vc = d1 * d4 - d3 * d2
        if vc <= 0 && d1 >= 0 && d3 <= 0 {
            return simd_distance(p, a + (d1 / (d1 - d3)) * ab)
        }
        
        let vb = d5 * d2 - d1 * d6
        if vb <= 0 && d2 >= 0 && d6 <= 0 {
            return simd_distance(p, a + (d2 / (d2 - d6)) * ac)
        }
        
        let va = d3 * d6 - d5 * d4
        if va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0 {
            return simd_distance(p, b + ((d4 - d3) / ((d4 - d3) + (d5 - d6))) * (c - b))
        }
        
        let n = simd_normalize(simd_cross(ab, ac))
        return simd_dot(n, ap) // signed distance to plane (positive = outside)
    }
    
    // MARK: - Marching Cubes
    
    private func marchingCubes(_ grid: SDFGrid, origin: SIMD3<Float>, voxelSize: Float) -> Mesh {
        var vertices: [Vertex] = []
        var indices: [UInt32] = []
        
        let n = grid.gridSize
        for i in 0..<(n-1) {
            for j in 0..<(n-1) {
                for k in 0..<(n-1) {
                    // 8 corners of this voxel
                    let corners: [SIMD3<Float>] = [
                        worldPos(i, j, k, origin, voxelSize),
                        worldPos(i+1, j, k, origin, voxelSize),
                        worldPos(i+1, j+1, k, origin, voxelSize),
                        worldPos(i, j+1, k, origin, voxelSize),
                        worldPos(i, j, k+1, origin, voxelSize),
                        worldPos(i+1, j, k+1, origin, voxelSize),
                        worldPos(i+1, j+1, k+1, origin, voxelSize),
                        worldPos(i, j+1, k+1, origin, voxelSize),
                    ]
                    
                    var cubeIndex: Int = 0
                    let vals: [Float] = [
                        grid.sample(i, j, k), grid.sample(i+1, j, k),
                        grid.sample(i+1, j+1, k), grid.sample(i, j+1, k),
                        grid.sample(i, j, k+1), grid.sample(i+1, j, k+1),
                        grid.sample(i+1, j+1, k+1), grid.sample(i, j+1, k+1),
                    ]
                    for (idx, v) in vals.enumerated() {
                        if v < 0 { cubeIndex |= (1 << idx) }
                    }
                    
                    let edges = MC_EDGE_TABLE[cubeIndex]
                    for e in stride(from: 0, to: edges.count, by: 3) {
                        if edges[e] < 0 { break }
                        for ei in 0..<3 {
                            let edgeIdx = edges[e + ei]
                            let (c0, c1) = MC_EDGE_CORNERS[Int(edgeIdx)]
                            let v0 = vals[Int(c0)], v1 = vals[Int(c1)]
                            let t = v0 / (v0 - v1)
                            let pos = corners[Int(c0)] + (corners[Int(c1)] - corners[Int(c0)]) * (1 - t)
                            let nrm = computeNormal(at: pos, grid: grid, origin: origin, vs: voxelSize)
                            vertices.append(Vertex(position: pos, normal: nrm))
                            indices.append(UInt32(vertices.count - 1))
                        }
                    }
                }
            }
        }
        
        return Mesh(vertices: vertices, indices: indices)
    }
    
    private func worldPos(_ i: Int, _ j: Int, _ k: Int, _ o: SIMD3<Float>, _ vs: Float) -> SIMD3<Float> {
        o + SIMD3<Float>(Float(i), Float(j), Float(k)) * vs
    }
    
    private func computeNormal(at p: SIMD3<Float>, grid: SDFGrid, origin: SIMD3<Float>, vs: Float) -> SIMD3<Float> {
        let eps: Float = vs * 0.5
        let n = SIMD3<Float>(
            sampleSDF(p + SIMD3<Float>(eps, 0, 0), grid: grid, origin: origin, vs: vs) -
            sampleSDF(p - SIMD3<Float>(eps, 0, 0), grid: grid, origin: origin, vs: vs),
            sampleSDF(p + SIMD3<Float>(0, eps, 0), grid: grid, origin: origin, vs: vs) -
            sampleSDF(p - SIMD3<Float>(0, eps, 0), grid: grid, origin: origin, vs: vs),
            sampleSDF(p + SIMD3<Float>(0, 0, eps), grid: grid, origin: origin, vs: vs) -
            sampleSDF(p - SIMD3<Float>(0, 0, eps), grid: grid, origin: origin, vs: vs)
        )
        return simd_length(n) > 0 ? simd_normalize(n) : SIMD3<Float>(0, 1, 0)
    }
    
    private func sampleSDF(_ p: SIMD3<Float>, grid: SDFGrid, origin: SIMD3<Float>, vs: Float) -> Float {
        let i = Int(((p.x - origin.x) / vs).rounded())
        let j = Int(((p.y - origin.y) / vs).rounded())
        let k = Int(((p.z - origin.z) / vs).rounded())
        return grid.sample(i, j, k)
    }
    
    // MARK: - Smoothing
    
    private func smoothLaplacian(_ mesh: Mesh) -> Mesh {
        var result = mesh
        let n = mesh.vertices.count
        var neighbors: [Set<Int>] = Array(repeating: [], count: n)
        for t in stride(from: 0, to: mesh.indices.count, by: 3) {
            guard t + 2 < mesh.indices.count else { break }
            let i0 = Int(mesh.indices[t]), i1 = Int(mesh.indices[t+1]), i2 = Int(mesh.indices[t+2])
            if i0 < n && i1 < n && i2 < n {
                neighbors[i0].insert(i1); neighbors[i0].insert(i2)
                neighbors[i1].insert(i0); neighbors[i1].insert(i2)
                neighbors[i2].insert(i0); neighbors[i2].insert(i1)
            }
        }
        for i in 0..<n {
            guard !neighbors[i].isEmpty else { continue }
            var avg = SIMD3<Float>.zero
            for nb in neighbors[i] { avg += result.vertices[nb].position }
            avg /= Float(neighbors[i].count)
            result.vertices[i].position = result.vertices[i].position * 0.5 + avg * 0.5
        }
        return result
    }
    
    // MARK: - Simplification
    
    private func simplifyMesh(_ mesh: Mesh, targetCount: Int) -> Mesh {
        // Simple decimation: remove every other triangle pair until target reached
        var result = mesh
        let currentTriCount = result.indices.count / 3
        if currentTriCount <= targetCount { return result }
        
        let removeCount = currentTriCount - targetCount
        var removed = 0
        var newIndices: [UInt32] = []
        for t in stride(from: 0, to: result.indices.count, by: 3) {
            if t + 2 < result.indices.count && removed < removeCount && (t / 3) % 2 == 0 {
                removed += 1; continue
            }
            newIndices.append(contentsOf: [result.indices[t], result.indices[t+1], result.indices[t+2]])
        }
        result.indices = newIndices
        return result
    }
}

// MARK: - Marching Cubes Tables (standard 256-entry)

private let MC_EDGE_TABLE: [[Int8]] = [
    [-1], [0,8,3,-1], [0,1,9,-1], [1,8,3,9,8,1,-1],
    [1,2,10,-1], [0,8,3,1,2,10,-1], [9,2,10,0,2,9,-1], [2,8,3,2,10,8,10,9,8,-1],
    [3,11,2,-1], [0,11,2,8,11,0,-1], [1,9,0,2,3,11,-1], [1,11,2,1,9,11,9,8,11,-1],
    [3,10,1,11,10,3,-1], [0,10,1,0,8,10,8,11,10,-1], [3,9,0,3,11,9,11,10,9,-1], [9,8,10,10,8,11,-1],
    [4,7,8,-1], [4,3,0,7,3,4,-1], [0,1,9,8,4,7,-1], [4,1,9,4,7,1,7,3,1,-1],
    [1,2,10,8,4,7,-1], [3,4,7,3,0,4,1,2,10,-1], [9,2,10,9,0,2,8,4,7,-1], [2,10,9,2,9,7,2,7,3,7,9,4,-1],
    [8,4,7,3,11,2,-1], [11,4,7,11,2,4,2,0,4,-1], [9,0,1,8,4,7,2,3,11,-1], [4,7,11,9,4,11,9,11,2,9,2,1,-1],
    [3,10,1,3,11,10,7,8,4,-1], [1,11,10,1,4,11,1,0,4,7,11,4,-1], [4,7,8,9,0,11,9,11,10,11,0,3,-1], [4,7,11,4,11,9,9,11,10,-1],
    [9,5,4,-1], [9,5,4,0,8,3,-1], [0,5,4,1,5,0,-1], [8,5,4,8,3,5,3,1,5,-1],
    [1,2,10,9,5,4,-1], [3,0,8,1,2,10,4,9,5,-1], [5,2,10,5,4,2,4,0,2,-1], [2,10,5,3,2,5,3,5,4,3,4,8,-1],
    [9,5,4,2,3,11,-1], [0,11,2,0,8,11,4,9,5,-1], [0,5,4,0,1,5,2,3,11,-1], [2,1,5,2,5,8,2,8,11,4,8,5,-1],
    [10,3,11,10,1,3,9,5,4,-1], [4,9,5,0,8,1,8,10,1,8,11,10,-1], [5,4,0,5,0,11,5,11,10,11,0,3,-1], [5,4,8,5,8,10,10,8,11,-1],
    [9,7,8,5,7,9,-1], [9,3,0,9,5,3,5,7,3,-1], [0,7,8,0,1,7,1,5,7,-1], [1,5,3,3,5,7,-1],
    [9,7,8,9,5,7,10,1,2,-1], [10,1,2,9,5,0,5,3,0,5,7,3,-1], [8,0,2,8,2,5,8,5,7,10,2,5,-1], [2,10,5,2,5,3,3,5,7,-1],
    [7,11,2,7,8,11,5,9,4,-1], [9,5,4,0,11,2,0,8,11,0,2,3,-1], [2,3,11,0,1,8,1,7,8,1,5,7,-1], [11,2,1,11,1,7,7,1,5,-1],
    [9,5,8,8,5,7,10,1,3,10,3,11,-1], [5,7,0,5,0,9,7,11,0,1,0,10,11,10,0,-1], [11,10,0,11,0,3,10,5,0,8,0,7,5,7,0,-1], [11,10,5,7,11,5,-1],
    [10,6,5,-1], [0,8,3,5,10,6,-1], [9,0,1,5,10,6,-1], [1,8,3,1,9,8,5,10,6,-1],
    [1,6,5,2,6,1,-1], [1,6,5,1,2,6,3,0,8,-1], [9,6,5,9,0,6,0,2,6,-1], [5,9,8,5,8,2,5,2,6,3,2,8,-1],
    [2,3,11,10,6,5,-1], [11,0,8,11,2,0,10,6,5,-1], [0,1,9,2,3,11,5,10,6,-1], [5,10,6,1,9,2,9,11,2,9,8,11,-1],
    [6,3,11,6,5,3,5,1,3,-1], [0,8,11,0,11,5,0,5,1,5,11,6,-1], [3,11,6,0,3,6,0,6,5,0,5,9,-1], [6,5,9,6,9,11,11,9,8,-1],
    [5,10,6,4,7,8,-1], [4,3,0,4,7,3,6,5,10,-1], [1,9,0,5,10,6,8,4,7,-1], [10,6,5,1,9,7,1,7,3,7,9,4,-1],
    [6,1,2,6,5,1,4,7,8,-1], [1,2,5,5,2,6,3,0,4,3,4,7,-1], [8,4,7,9,0,5,0,6,5,0,2,6,-1], [7,3,9,7,9,4,3,2,9,5,9,6,2,6,9,-1],
    [3,11,2,7,8,4,10,6,5,-1], [5,10,6,4,7,2,4,2,0,2,7,11,-1], [0,1,9,4,7,8,2,3,11,5,10,6,-1], [9,2,1,9,11,2,9,4,11,7,11,4,5,10,6,-1],
    [8,4,7,3,11,5,3,5,1,5,11,6,-1], [5,1,11,5,11,6,1,0,11,7,11,4,0,4,11,-1], [0,5,9,0,6,5,0,3,6,11,6,3,8,4,7,-1], [6,5,9,6,9,11,4,7,9,7,11,9,-1],
    [10,4,9,6,4,10,-1], [4,10,6,4,9,10,0,8,3,-1], [10,0,1,10,6,0,6,4,0,-1], [8,3,1,8,1,6,8,6,4,6,1,10,-1],
    [1,4,9,1,2,4,2,6,4,-1], [3,0,8,1,2,9,2,4,9,2,6,4,-1], [0,2,4,4,2,6,-1], [8,3,2,8,2,4,4,2,6,-1],
    [10,4,9,10,6,4,11,2,3,-1], [0,8,2,2,8,11,4,9,10,4,10,6,-1], [3,11,2,0,1,6,0,6,4,6,1,10,-1], [6,4,1,6,1,10,4,8,1,2,1,11,8,11,1,-1],
    [9,6,4,9,3,6,9,1,3,11,6,3,-1], [8,11,1,8,1,0,11,6,1,9,1,4,6,4,1,-1], [3,11,6,3,6,0,0,6,4,-1], [6,4,8,11,6,8,-1],
    [7,10,6,7,8,10,8,9,10,-1], [0,7,3,0,10,7,0,9,10,6,7,10,-1], [10,6,7,1,10,7,1,7,8,1,8,0,-1], [10,6,7,10,7,1,1,7,3,-1],
    [1,2,6,1,6,8,1,8,9,8,6,7,-1], [2,6,9,2,9,1,6,7,9,0,9,3,7,3,9,-1], [7,8,0,7,0,6,6,0,2,-1], [7,3,2,6,7,2,-1],
    [2,3,11,10,6,8,10,8,9,8,6,7,-1], [2,0,7,2,7,11,0,9,7,6,7,10,9,10,7,-1], [1,8,0,1,7,8,1,10,7,6,7,10,2,3,11,-1], [11,2,1,11,1,7,10,6,1,6,7,1,-1],
    [8,9,6,8,6,7,9,1,6,11,6,3,1,3,6,-1], [0,9,1,11,6,7,-1], [7,8,0,7,0,6,3,11,0,11,6,0,-1], [7,11,6,-1],
    [7,6,11,-1], [3,0,8,11,7,6,-1], [0,1,9,11,7,6,-1], [8,1,9,8,3,1,11,7,6,-1],
    [10,1,2,6,11,7,-1], [1,2,10,3,0,8,6,11,7,-1], [2,9,0,2,10,9,6,11,7,-1], [6,11,7,2,10,3,10,8,3,10,9,8,-1],
    [7,2,3,6,2,7,-1], [7,0,8,7,6,0,6,2,0,-1], [2,7,6,2,3,7,0,1,9,-1], [1,6,2,1,8,6,1,9,8,8,7,6,-1],
    [10,7,6,10,1,7,1,3,7,-1], [10,7,6,1,7,10,1,8,7,1,0,8,-1], [0,3,7,0,7,10,0,10,9,6,10,7,-1], [7,6,10,7,10,8,8,10,9,-1],
    [6,8,4,11,8,6,-1], [3,6,11,3,0,6,0,4,6,-1], [8,6,11,8,4,6,9,0,1,-1], [9,4,6,9,6,3,9,3,1,11,3,6,-1],
    [6,8,4,6,11,8,2,10,1,-1], [1,2,10,3,0,11,0,6,11,0,4,6,-1], [4,11,8,4,6,11,0,2,9,2,10,9,-1], [10,9,3,10,3,2,9,4,3,11,3,6,4,6,3,-1],
    [8,2,3,8,6,2,8,4,6,6,2,7,-1], [0,2,3,0,4,2,0,8,4,6,2,4,-1], [9,0,1,8,4,6,8,6,2,8,2,3,6,2,7,-1], [9,4,6,9,6,3,9,3,1,2,3,6,2,3,7,-1], // simplified
    [8,1,3,8,6,1,8,4,6,6,10,1,-1], [10,1,0,10,0,6,6,0,4,-1], [4,6,3,4,3,8,6,10,3,0,3,9,10,9,3,-1], [10,9,4,6,10,4,-1],
    [4,9,5,7,6,11,-1], [0,8,3,4,9,5,11,7,6,-1], [5,0,1,5,4,0,7,6,11,-1], [11,7,6,8,3,4,3,5,4,3,1,5,-1],
    [9,5,4,10,1,2,7,6,11,-1], [6,11,7,1,2,10,0,8,3,4,9,5,-1], [7,6,11,5,4,10,4,2,10,4,0,2,-1], [3,4,8,3,5,4,3,2,5,10,5,2,11,7,6,-1],
    [7,2,3,7,6,2,5,4,9,-1], [9,5,4,0,8,6,0,6,2,6,8,7,-1], [3,6,2,3,7,6,1,5,0,5,4,0,-1], [6,2,8,6,8,7,2,1,8,4,8,5,1,5,8,-1],
    [9,5,4,10,1,6,1,7,6,1,3,7,-1], [1,6,10,1,7,6,1,0,7,8,7,0,9,5,4,-1], [4,0,10,4,10,5,0,3,10,6,10,7,3,7,10,-1], [7,6,10,7,10,8,5,4,10,4,8,10,-1],
    [6,9,5,6,11,9,11,8,9,-1], [3,6,11,0,6,3,0,5,6,0,9,5,-1], [0,11,8,0,5,11,0,1,5,5,11,6,-1], [6,11,3,6,3,5,5,3,1,-1],
    [1,2,10,9,5,11,9,11,8,11,5,6,-1], [0,11,3,0,6,11,0,9,6,5,6,9,1,2,10,-1], [11,8,5,11,5,6,8,0,5,10,5,2,0,2,5,-1], [6,11,3,6,3,5,2,10,3,10,5,3,-1],
    [5,8,9,5,2,8,5,6,2,3,8,2,-1], [9,5,6,9,6,0,0,6,2,-1], [1,5,8,1,8,0,5,6,8,3,8,2,6,2,8,-1], [1,5,6,2,1,6,-1],
    [1,3,6,1,6,10,3,8,6,5,6,9,8,9,6,-1], [10,1,0,10,0,6,9,5,0,5,6,0,-1], [0,3,8,5,6,10,-1], [10,5,6,-1],
    [11,5,10,7,5,11,-1], [11,5,10,11,7,5,8,3,0,-1], [5,11,7,5,10,11,1,9,0,-1], [10,7,5,10,11,7,9,8,1,8,3,1,-1],
    [11,1,2,11,7,1,7,5,1,-1], [0,8,3,1,2,7,1,7,5,7,2,11,-1], [9,7,5,9,2,7,9,0,2,2,7,11,-1], [7,5,2,7,2,11,5,9,2,3,2,8,9,8,2,-1],
    [2,5,10,2,3,5,3,7,5,-1], [8,2,0,8,5,2,8,7,5,10,2,5,-1], [9,0,1,5,10,3,5,3,7,3,10,2,-1], [9,8,2,9,2,1,8,7,2,10,2,5,7,5,2,-1],
    [1,3,5,3,7,5,-1], [0,8,7,0,7,1,1,7,5,-1], [9,0,3,9,3,5,5,3,7,-1], [9,8,7,5,9,7,-1],
    [5,8,4,5,10,8,10,11,8,-1], [5,0,4,5,11,0,5,10,11,11,0,3,-1], [0,1,9,8,4,10,8,10,11,10,4,5,-1], [10,11,4,10,4,5,11,3,4,9,4,1,3,1,4,-1],
    [2,5,1,2,8,5,2,11,8,4,5,8,-1], [0,4,3,0,5,4,2,11,1,2,8,1,2,11,8,5,1,8,-1], // simplified
    [0,2,5,0,5,9,2,11,5,4,5,8,11,8,5,-1], [9,4,5,2,11,3,-1],
    [2,5,10,3,5,2,3,4,5,3,8,4,-1], [5,10,2,5,2,4,4,2,0,-1], [3,10,2,3,5,10,3,8,5,4,5,8,0,1,9,-1], [5,10,2,5,2,4,1,9,2,9,4,2,-1],
    [8,4,5,8,5,3,3,5,1,-1], [0,4,5,1,0,5,-1], [8,4,5,8,5,3,9,0,5,0,3,5,-1], [9,4,5,-1],
    [4,11,7,4,9,11,9,10,11,-1], [0,8,3,4,9,7,9,11,7,9,10,11,-1], [1,10,11,1,11,4,1,4,0,7,4,11,-1], [3,1,4,3,4,8,1,10,4,7,4,11,10,11,4,-1],
    [4,11,7,9,11,4,9,2,11,9,1,2,-1], [9,7,4,9,11,7,9,1,11,2,11,1,0,8,3,-1], [11,7,4,11,4,2,2,4,0,-1], [11,7,4,11,4,2,8,3,4,3,2,4,-1],
    [2,9,10,2,7,9,2,3,7,7,9,4,-1], [9,10,7,9,7,4,10,2,7,8,7,0,2,0,7,-1], [3,7,10,3,10,2,7,4,10,1,10,0,4,0,10,-1], [1,10,2,8,7,4,-1],
    [4,9,1,4,1,7,7,1,3,-1], [4,9,1,4,1,7,0,8,1,8,7,1,-1], [4,0,3,7,4,3,-1], [4,8,7,-1],
    [9,10,8,10,11,8,-1], [3,0,9,3,9,11,11,9,10,-1], [0,1,10,0,10,8,8,10,11,-1], [3,1,10,11,3,10,-1],
    [1,2,11,1,11,9,9,11,8,-1], [3,0,9,3,9,11,1,2,9,2,11,9,-1], [0,2,11,8,0,11,-1], [3,2,11,-1],
    [2,3,8,2,8,10,10,8,9,-1], [9,10,2,0,9,2,-1], [2,3,8,2,8,10,0,1,8,1,10,8,-1], [1,10,2,-1],
    [1,3,8,9,1,8,-1], [0,9,1,-1], [0,3,8,-1], []
]

private let MC_EDGE_CORNERS: [(Int8, Int8)] = [
    (0,1), (1,2), (2,3), (3,0),
    (4,5), (5,6), (6,7), (7,4),
    (0,4), (1,5), (2,6), (3,7)
]
