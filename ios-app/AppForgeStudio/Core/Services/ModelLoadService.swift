import Foundation
import Metal
import ModelIO
import MetalKit

class ModelLoadService {
    let device: MTLDevice
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    func loadModel(url: URL) -> Model? {
        guard let asset = MDLAsset(url: url) else { return nil }
        asset.load()
        var meshes: [Mesh] = []
        for i in 0..<asset.count {
            guard let object = asset.object(at: i) as? MDLMesh else { continue }
            guard let mesh = createMesh(from: object) else { continue }
            meshes.append(mesh)
        }
        return meshes.isEmpty ? nil : Model(name: url.lastPathComponent, meshes: meshes)
    }
    
    func createPrimitive(type: PrimitiveType) -> Model {
        let allocator = MTKMeshBufferAllocator(device: device)
        let mesh: MDLMesh
        switch type {
        case .box:
            mesh = MDLMesh(boxWithExtent: SIMD3<Float>(1,1,1), segments: SIMD3<UInt32>(2,2,2), inwardNormals: false, geometryType: .triangles, allocator: allocator)
        case .sphere:
            mesh = MDLMesh(sphereWithExtent: SIMD3<Float>(1,1,1), segments: SIMD2<UInt32>(24,24), inwardNormals: false, geometryType: .triangles, allocator: allocator)
        case .cylinder:
            mesh = MDLMesh(cylinderWithExtent: SIMD3<Float>(1,1,1), segments: SIMD2<UInt32>(24,24), inwardNormals: false, geometryType: .triangles, allocator: allocator)
        case .plane:
            mesh = MDLMesh(planeWithExtent: SIMD3<Float>(2,0,2), segments: SIMD2<UInt32>(2,2), geometryType: .triangles, allocator: allocator)
        case .torus:
            mesh = MDLMesh(cylinderWithExtent: SIMD3<Float>(0.8,0.3,0.8), segments: SIMD2<UInt32>(24,24), inwardNormals: false, geometryType: .triangles, allocator: allocator)
        }
        if var result = createMesh(from: mesh) {
            result.uploadToGPU(device: device)
            return Model(name: type.rawValue, meshes: [result])
        }
        return Model(name: type.rawValue, meshes: [])
    }
    
    private func createMesh(from mdlMesh: MDLMesh) -> Mesh? {
        let vData = mdlMesh.vertexBuffers[0].map().bytes
        let vCount = mdlMesh.vertexCount
        var vertices: [Vertex] = []
        for i in 0..<vCount {
            vertices.append(vData.load(fromByteOffset: i*MemoryLayout<Vertex>.stride, as: Vertex.self))
        }
        let submesh = mdlMesh.submeshes?.firstObject as? MDLSubmesh
        let iData = submesh?.indexBufferData()?.map().bytes
        let iCount = submesh?.indexCount ?? 0
        var indices: [UInt32] = []
        if let data = iData {
            for i in 0..<iCount {
                indices.append(data.load(fromByteOffset: i*MemoryLayout<UInt32>.stride, as: UInt32.self))
            }
        }
        var mesh = Mesh(vertices: vertices, indices: indices)
        mesh.uploadToGPU(device: device)
        return mesh
    }
}

enum PrimitiveType: String, CaseIterable {
    case box="Caja", sphere="Esfera", cylinder="Cilindro", plane="Plano", torus="Toro"
}
