import Foundation
import simd
import Metal
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "Mesh")
struct Vertex: Equatable {
    let id: UUID = UUID()
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var uv: SIMD2<Float>
    
    init(position: SIMD3<Float> = .zero, normal: SIMD3<Float> = .zero, uv: SIMD2<Float> = .zero) {
        self.position = position
        self.normal = normal
        self.uv = uv
    }
}

struct MorphTarget {
    let id: UUID = UUID()
    let name: String
    var offsets: [SIMD3<Float>]
    var weight: Float = 0

    init(name: String, offsets: [SIMD3<Float>], weight: Float = 0) {
        self.name = name
        self.offsets = offsets
        self.weight = weight
    }
}

struct Mesh {
    var vertices: [Vertex]
    var indices: [UInt32]
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var morphTargets: [MorphTarget] = []
    var baseVertices: [Vertex] = []
    private var _cachedAdjacency: [[Int]] = []
    
    init(vertices: [Vertex] = [], indices: [UInt32] = []) {
        self.vertices = vertices
        self.indices = indices
        self.vertexBuffer = nil
        self.indexBuffer = nil
        self.morphTargets = []
        self.baseVertices = []
        self._cachedAdjacency = Self.buildEdgeAdjacency(indices: indices)
    }
    
    static func buildEdgeAdjacency(indices: [UInt32]) -> [[Int]] {
        guard !indices.isEmpty else { return [] }
        let vertexCount = Int(indices.max() ?? 0) + 1
        var neighbors = [[Int]](repeating: [], count: vertexCount)
        for i in stride(from: 0, to: indices.count, by: 3) {
            let a = Int(indices[i])
            let b = Int(indices[i + 1])
            let c = Int(indices[i + 2])
            neighbors[a].append(contentsOf: [b, c])
            neighbors[b].append(contentsOf: [a, c])
            neighbors[c].append(contentsOf: [a, b])
        }
        for i in 0..<neighbors.count {
            neighbors[i] = Array(Set(neighbors[i]))
        }
        return neighbors
    }
    
    var edgeAdjacentIndices: [[Int]] {
        get { _cachedAdjacency }
        set { _cachedAdjacency = newValue }
    }
    
    mutating func applyMorphs() {
        guard !morphTargets.isEmpty else { return }
        if baseVertices.isEmpty {
            baseVertices = vertices
        }
        vertices = baseVertices
        for target in morphTargets {
            let w = target.weight
            guard w != 0, target.offsets.count == vertices.count else { continue }
            for i in 0..<vertices.count {
                vertices[i].position += target.offsets[i] * w
            }
        }
        recalculateNormals()
    }

    private mutating func recalculateNormals() {
        guard !indices.isEmpty else { return }
        for i in 0..<vertices.count {
            vertices[i].normal = .zero
        }
        for i in stride(from: 0, to: indices.count, by: 3) {
            let i0 = Int(indices[i]), i1 = Int(indices[i+1]), i2 = Int(indices[i+2])
            guard i0 < vertices.count, i1 < vertices.count, i2 < vertices.count else { continue }
            let e1 = vertices[i1].position - vertices[i0].position
            let e2 = vertices[i2].position - vertices[i0].position
            let n = simd_normalize(simd_cross(e1, e2))
            vertices[i0].normal += n
            vertices[i1].normal += n
            vertices[i2].normal += n
        }
        for i in 0..<vertices.count {
            let len = simd_length(vertices[i].normal)
            if len > Float(1e-6) { vertices[i].normal /= len }
        }
    }

    mutating func uploadToGPU(device: MTLDevice) {
        guard !vertices.isEmpty else { return }
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: .storageModeShared)
        if !indices.isEmpty {
            indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt32>.stride * indices.count, options: .storageModeShared)
        }
    }
}

extension Mesh: Equatable {
    static func == (lhs: Mesh, rhs: Mesh) -> Bool {
        guard lhs.vertices.count == rhs.vertices.count,
              lhs.indices == rhs.indices else { return false }
        for i in 0..<lhs.vertices.count {
            if lhs.vertices[i] != rhs.vertices[i] { return false }
        }
        return true
    }
}

protocol VertexProvider {
    func providePoints() -> [SketchPoint]
}

protocol VertexUpdater {
    func updateMesh(scene: Scene3D) -> Mesh?
}
