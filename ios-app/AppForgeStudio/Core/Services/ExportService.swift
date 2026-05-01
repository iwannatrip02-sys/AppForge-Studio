import Foundation
import ModelIO
import MetalKit

enum ExportError: Error {
    case invalidModel(String)
    case exportFailed(String)
    case stepGenerationFailed(String)
    case fileWriteFailed(String)
}

class ExportService {
    let device: MTLDevice
    let occtEngine: OCCTEngine
    let csgEngine: CSGEngine
    
    init(device: MTLDevice, occtEngine: OCCTEngine = .shared, csgEngine: CSGEngine = .shared) {
        self.device = device
        self.occtEngine = occtEngine
        self.csgEngine = csgEngine
    }
    
    func exportToOBJ(model: Model, url: URL) throws {
        guard let asset = buildMDLAsset(from: model) else {
            throw ExportError.invalidModel("No valid meshes found in model for OBJ export")
        }
        do {
            try asset.export(to: url)
        } catch {
            throw ExportError.exportFailed("OBJ export failed - \(error.localizedDescription)")
        }
    }
    
    func exportToSTL(model: Model, url: URL) throws {
        guard let asset = buildMDLAsset(from: model) else {
            throw ExportError.invalidModel("No valid meshes found in model for STL export")
        }
        do {
            try asset.export(to: url, fileType: "stl")
        } catch {
            throw ExportError.exportFailed("STL export failed - \(error.localizedDescription)")
        }
    }
    
    func exportToUSDZ(model: Model, url: URL) throws {
        guard let asset = buildMDLAsset(from: model) else {
            throw ExportError.invalidModel("No valid meshes found in model for USDZ export")
        }
        do {
            try asset.export(to: url, fileType: "usdz")
        } catch {
            throw ExportError.exportFailed("USDZ export failed - \(error.localizedDescription)")
        }
    }
    
    func exportToSTEP(model: Model, url: URL) throws {
        guard !model.meshes.isEmpty else {
            throw ExportError.invalidModel("Model has no meshes for STEP export")
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let currentDate = dateFormatter.string(from: Date())
        
        var stepContent = "ISO-10303-21;\nHEADER;\nFILE_DESCRIPTION(('View exchange'),'1');\nFILE_NAME('\(url.lastPathComponent)','\(currentDate)',('Author'),('Org'),'Preprocessor Ver','','');\nFILE_SCHEMA(('AP214'));\nENDSEC;\nDATA;\n"
        var vertexId = 1
        var faceId = 1
        for mesh in model.meshes {
            for v in mesh.vertices {
                stepContent += "#\(vertexId)=CARTESIAN_POINT('',(\(v.position.x),\(v.position.y),\(v.position.z)));\n"
                vertexId += 1
            }
            for i in stride(from: 0, to: mesh.indices.count, by: 3) {
                let i1 = Int(mesh.indices[i]) + 1
                let i2 = Int(mesh.indices[i+1]) + 1
                let i3 = Int(mesh.indices[i+2]) + 1
                stepContent += "#\(faceId)=POLYLOOP('',(#\(i1),#\(i2),#\(i3)));\n"
                faceId += 1
            }
        }
        stepContent += "ENDSEC;\nEND-ISO-10303-21;"
        do {
            try stepContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.fileWriteFailed("STEP export failed - \(error.localizedDescription)")
        }
    }
    
    func exportToGLTF(model: Model, url: URL) throws {
        guard !model.meshes.isEmpty else {
            throw ExportError.invalidModel("No valid meshes found in model for GLTF export")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        var verticesList: [[String: Any]] = []
        var indicesList: [UInt32] = []
        var vertexOffset: UInt32 = 0
        for mesh in model.meshes {
            for v in mesh.vertices {
                verticesList.append(["pos": [v.position.x, v.position.y, v.position.z], "nml": [v.normal.x, v.normal.y, v.normal.z], "uv": [v.uv.x, v.uv.y]])
            }
            for i in mesh.indices {
                indicesList.append(i + vertexOffset)
            }
            vertexOffset += UInt32(mesh.vertices.count)
        }
        let gltf: [String: Any] = [
            "asset": ["version": "2.0", "generator": "AppForgeStudio"],
            "scene": 0,
            "scenes": [["nodes": [0]]],
            "nodes": [["mesh": 0, "name": model.name]],
            "meshes": [["primitives": [["attributes": ["POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2], "indices": 3]]]],
            "accessors": [
                ["bufferView": 0, "componentType": 5126, "count": \(verticesList.count), "type": "VEC3"],
                ["bufferView": 1, "componentType": 5126, "count": \(verticesList.count), "type": "VEC3"],
                ["bufferView": 2, "componentType": 5126, "count": \(verticesList.count), "type": "VEC2"],
                ["bufferView": 3, "componentType": 5125, "count": \(indicesList.count), "type": "SCALAR"]
            ],
            "bufferViews": [
                ["buffer": 0, "byteOffset": 0, "byteLength": \(verticesList.count * 12), "target": 34962],
                ["buffer": 0, "byteOffset": \(verticesList.count * 12), "byteLength": \(verticesList.count * 12), "target": 34962],
                ["buffer": 0, "byteOffset": \(verticesList.count * 24), "byteLength": \(verticesList.count * 8), "target": 34962],
                ["buffer": 0, "byteOffset": \(verticesList.count * 32), "byteLength": \(indicesList.count * 4), "target": 34963]
            ],
            "buffers": [["byteLength": \(verticesList.count * 32 + indicesList.count * 4), "uri": ""]]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: gltf, options: .prettyPrinted) {
            var gltfStr = String(data: data, encoding: .utf8) ?? ""
            try gltfStr.write(to: url, atomically: true, encoding: .utf8)
        } else {
            throw ExportError.exportFailed("GLTF serialization failed")
        }
    }

    private func buildMDLAsset(from model: Model) -> MDLAsset? {
        let asset = MDLAsset()
        for mesh in model.meshes {
            let allocator = MTKMeshBufferAllocator(device: device)
            let mdlMesh = MDLMesh(submesh: mesh, allocator: allocator)
            asset.add(mdlMesh)
        }
        return asset
    }
}
