import Foundation
import ModelIO
import MetalKit

class ExportService {
    let device: MTLDevice
    let occtEngine: OCCTEngine
    
    init(device: MTLDevice, occtEngine: OCCTEngine = .shared) {
        self.device = device
        self.occtEngine = occtEngine
    }
    
    func exportToOBJ(model: Model, url: URL) -> Bool {
        guard let asset = buildMDLAsset(from: model) else { return false }
        do {
            try asset.export(to: url)
            return true
        } catch {
            print("ExportService: OBJ export failed - \(error.localizedDescription)")
            return false
        }
    }
    
    func exportToSTL(model: Model, url: URL) -> Bool {
        guard let asset = buildMDLAsset(from: model) else { return false }
        asset.export(to: url, fileType: "stl")
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    func exportToSTEP(model: Model, url: URL) -> Bool {
        // Convierte el primer mesh a Shape OCCT y exporta como STEP
        guard let mesh = model.meshes.first,
              let shape = occtEngine.meshToShape(mesh) else {
            print("ExportService: STEP export failed - no valid mesh for conversion")
            return false
        }
        do {
            try shape.exportSTEP(to: url)
            return true
        } catch {
            print("ExportService: STEP export failed - \(error.localizedDescription)")
            return false
        }
    }
    
    func exportToUSDZ(model: Model, url: URL) -> Bool {
        guard let asset = buildMDLAsset(from: model) else { return false }
        do {
            try asset.export(to: url, fileType: "usdz")
            return true
        } catch {
            print("ExportService: USDZ export failed - \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Private Helpers
    
    private func buildMDLAsset(from model: Model) -> MDLAsset? {
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(bufferAllocator: allocator)
        for mesh in model.meshes {
            if let mdlMesh = meshToMDL(mesh) {
                asset.add(mdlMesh)
            }
        }
        return asset
    }
    
    private func meshToMDL(_ mesh: Mesh) -> MDLMesh? {
        guard !mesh.vertices.isEmpty, !mesh.indices.isEmpty else { return nil }
        let vd = MDLVertexDescriptor()
        vd.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                format: .float4, offset: 0, bufferIndex: 0)
        vd.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                format: .float3,
                                                offset: MemoryLayout<Float>.size * 4,
                                                bufferIndex: 0)
        vd.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                                format: .float2,
                                                offset: MemoryLayout<Float>.size * 7,
                                                bufferIndex: 0)
        vd.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Vertex>.stride)
        let vData = Data(bytes: mesh.vertices,
                         count: MemoryLayout<Vertex>.stride * mesh.vertices.count)
        let iData = Data(bytes: mesh.indices,
                         count: MemoryLayout<UInt32>.stride * mesh.indices.count)
        return MDLMesh(vertexData: vData,
                       vertexCount: mesh.vertices.count,
                       vertexDescriptor: vd,
                       submeshes: [MDLSubmesh(indexData: iData,
                                               indexType: .uInt32,
                                               geometryType: .triangles,
                                               material: nil)])
    }
}
