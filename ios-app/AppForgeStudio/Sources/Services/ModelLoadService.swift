import Foundation
import Metal
import ModelIO
import MetalKit
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "ModelLoadService")
enum ModelLoadError: Error {
    case fileNotFound(String)
    case invalidFormat(String)
    case meshCreationFailed(String)
}

class ModelLoadService {
    let device: MTLDevice
    let cacheService: ModelCacheService?
    
    init(device: MTLDevice, cacheService: ModelCacheService? = nil) {
        self.device = device
        self.cacheService = cacheService
    }
    
    func loadModel(url: URL) -> Result<Model, ModelLoadError> {
        if let cached = cacheService?.cachedModel(for: url) {
            return .success(cached)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(.fileNotFound(url.lastPathComponent))
        }
        let asset = MDLAsset(url: url)
        var meshes: [Mesh] = []
        for i in 0..<asset.count {
            guard let object = asset.object(at: i) as? MDLMesh else { continue }
            guard let mesh = createMesh(from: object) else {
                return .failure(.meshCreationFailed(url.lastPathComponent))
            }
            meshes.append(mesh)
        }
        if meshes.isEmpty {
            return .failure(.meshCreationFailed(url.lastPathComponent))
        }
        let model = Model(name: url.lastPathComponent)
        model.meshes = meshes
        cacheService?.cache(model, for: url)
        return .success(model)
    }
    
    func createPrimitive(type: PrimitiveType) -> Model? {
        let allocator = MTKMeshBufferAllocator(device: device)
        let mesh: MDLMesh
        switch type {
        case .box:
            mesh = MDLMesh(boxWithExtent: SIMD3<Float>(1,1,1), segments: SIMD3<UInt32>(2,2,2), inwardNormals: false, geometryType: .triangles, allocator: allocator)
        case .sphere:
            mesh = MDLMesh(sphereWithExtent: SIMD3<Float>(1,1,1), segments: SIMD2<UInt32>(24,24), inwardNormals: false, geometryType: .triangles, allocator: allocator)
        case .cylinder:
            mesh = MDLMesh(cylinderWithExtent: SIMD3<Float>(1,1,1), segments: SIMD2<UInt32>(24,24), inwardNormals: false, topCap: true, bottomCap: true, geometryType: .triangles, allocator: allocator)
        case .plane:
            mesh = MDLMesh(planeWithExtent: SIMD3<Float>(2,0,2), segments: SIMD2<UInt32>(2,2), geometryType: .triangles, allocator: allocator)
        case .torus:
            mesh = MDLMesh(cylinderWithExtent: SIMD3<Float>(0.8,0.3,0.8), segments: SIMD2<UInt32>(24,24), inwardNormals: false, topCap: false, bottomCap: false, geometryType: .triangles, allocator: allocator)
        }
        guard var result = createMesh(from: mesh) else { return nil }
        result.uploadToGPU(device: device)
        let model = Model(name: type.rawValue)
        model.meshes = [result]
        return model
    }
    
    // MARK: - Private Helpers
    
    private func createMesh(from mdMesh: MDLMesh) -> Mesh? {
        guard let mtkMesh = try? MTKMesh(mesh: mdMesh, device: device) else { return nil }
        let vertexCount = mtkMesh.vertexCount
        let buffer = mtkMesh.vertexBuffers[0]
        let vertexPtr = buffer.buffer.contents().bindMemory(to: Float.self, capacity: vertexCount * 8)
        var vertices: [Vertex] = []
        for i in 0..<vertexCount {
            let pos = SIMD3<Float>(vertexPtr[i*8], vertexPtr[i*8+1], vertexPtr[i*8+2])
            let norm = SIMD3<Float>(vertexPtr[i*8+3], vertexPtr[i*8+4], vertexPtr[i*8+5])
            let uv = SIMD2<Float>(vertexPtr[i*8+6], vertexPtr[i*8+7])
            vertices.append(Vertex(position: pos, normal: norm, uv: uv))
        }
        var indices: [UInt32] = []
        for sub in mtkMesh.submeshes {
            let indexBuffer = sub.indexBuffer
            let indexPtr = indexBuffer.buffer.contents().bindMemory(to: UInt32.self, capacity: sub.indexCount)
            for i in 0..<sub.indexCount {
                indices.append(indexPtr[i])
            }
        }
        return Mesh(vertices: vertices, indices: indices)
    }
}

enum PrimitiveType: String, CaseIterable {
    case box = "Box"
    case sphere = "Sphere"
    case cylinder = "Cylinder"
    case plane = "Plane"
    case torus = "Torus"
}
