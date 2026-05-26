import Foundation
import simd
import ModelIO
import MetalKit
import OSLog

enum ExportFormat: String, CaseIterable {
    case obj = "OBJ"
    case stl = "STL"
    case usdz = "USDZ"
    case step = "STEP"
    case gltf = "GLTF"
    case fbx = "FBX"
}

enum ExportError: Error, LocalizedError {
    case unsupportedFormat
    case noModel
    case writeFailed(String)
    case invalidModel(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "Formato no soportado"
        case .noModel: return "No hay modelo para exportar"
        case .writeFailed(let msg): return "Error al escribir: \(msg)"
        case .invalidModel(let msg): return msg
        }
    }
}

class ExportService {
    private let device: MTLDevice
    private let logger = Logger(subsystem: "com.appforgestudio", category: "ExportService")
    let occtEngine: OCCTEngine
    let csgEngine: CSGEngine

    init(device: MTLDevice, occtEngine: OCCTEngine = .shared, csgEngine: CSGEngine = .shared) {
        self.device = device
        self.occtEngine = occtEngine
        self.csgEngine = csgEngine
    }

    func export(model: Model, format: ExportFormat, to url: URL) -> Result<Void, ExportError> {
        guard !model.meshes.isEmpty, model.meshes.contains(where: { !$0.vertices.isEmpty }) else {
            return .failure(.invalidModel("El modelo no tiene vertices para exportar"))
        }
        do {
            switch format {
            case .usdz:
                try exportUSDZ(model: model, to: url)
            case .obj:
                try exportOBJ(model: model, to: url)
            case .stl:
                try exportSTL(model: model, to: url)
            case .step:
                try exportSTEP(model: model, to: url)
            case .gltf:
                try exportGLTF(model: model, to: url)
            case .fbx:
                try exportFBX(model: model, to: url)
            }
            return .success(())
        } catch let error as ExportError {
            return .failure(error)
        } catch {
            return .failure(.writeFailed(error.localizedDescription))
        }
    }

    func exportToOBJ(model: Model, url: URL) throws {
        guard let asset = buildMDLAsset(from: model) else {
            throw ExportError.invalidModel("No valid meshes found for OBJ export")
        }
        try asset.export(to: url)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExportError.writeFailed("OBJ export failed - file was not written to disk")
        }
    }

    func exportToSTL(model: Model, url: URL) throws {
        guard let asset = buildMDLAsset(from: model) else {
            throw ExportError.invalidModel("No valid meshes found for STL export")
        }
        try asset.export(to: url, fileType: "stl")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExportError.writeFailed("STL export failed - file was not written to disk")
        }
    }

    func exportToUSDZ(model: Model, url: URL) throws {
        guard let asset = buildMDLAsset(from: model) else {
            throw ExportError.invalidModel("No se pudo construir el asset USDZ")
        }
        try asset.export(to: url, fileType: "usdz")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExportError.writeFailed("USDZ export failed - file was not written to disk")
        }
    }

    func exportToSTEP(model: Model, url: URL) throws {
        guard !model.meshes.isEmpty else {
            throw ExportError.invalidModel("Model has no meshes for STEP export")
        }
        // Export via OCCTSwiftIO for B-rep fidelity STEP (AP214)
        // For now, uses the first mesh triangulated from any OCCT-native shape.
        // Future: track CADShape alongside Model for native B-rep STEP export.
        try exportSTEPAsText(model: model, to: url)
    }

    private func exportSTEPAsText(model: Model, to url: URL) throws {
        var stepContent = "ISO-10303-21;\nHEADER;\nFILE_DESCRIPTION(('View exchange'),'1');\n"
        stepContent += "FILE_NAME('\(url.lastPathComponent)','\(ISO8601DateFormatter().string(from: Date()))',('AppForgeStudio'),(''),'','','');\n"
        stepContent += "FILE_SCHEMA(('AP214'));\nENDSEC;\nDATA;\n"
        var vertexId = 1
        var faceId = 1
        for mesh in model.meshes {
            for v in mesh.vertices {
                stepContent += "#\(vertexId)=CARTESIAN_POINT('',(\(v.position.x),\(v.position.y),\(v.position.z)));\n"
                vertexId += 1
            }
            for i in stride(from: 0, to: mesh.indices.count, by: 3) {
                guard i + 2 < mesh.indices.count else { break }
                let i1 = Int(mesh.indices[i]) + 1
                let i2 = Int(mesh.indices[i+1]) + 1
                let i3 = Int(mesh.indices[i+2]) + 1
                stepContent += "#\(faceId)=POLYLOOP('',(#\(i1),#\(i2),#\(i3)));\n"
                faceId += 1
            }
        }
        stepContent += "ENDSEC;\nEND-ISO-10303-21;"
        try stepContent.write(to: url, atomically: true, encoding: .utf8)
    }

    func exportToGLTF(model: Model, url: URL) throws {
        guard !model.meshes.isEmpty else {
            throw ExportError.invalidModel("No valid meshes found for GLTF export")
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
            for i in mesh.indices { indicesList.append(i + vertexOffset) }
            vertexOffset += UInt32(mesh.vertices.count)
        }
        let gltf: [String: Any] = [
            "asset": ["version": "2.0", "generator": "AppForgeStudio"],
            "scene": 0,
            "scenes": [["nodes": [0]]],
            "nodes": [["mesh": 0, "name": model.name]],
            "meshes": [["primitives": [["attributes": ["POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2], "indices": 3]]]],
            "accessors": [
                ["bufferView": 0, "componentType": 5126, "count": verticesList.count, "type": "VEC3", "max": [Float.greatestFiniteMagnitude], "min": [-Float.greatestFiniteMagnitude]],
                ["bufferView": 1, "componentType": 5126, "count": verticesList.count, "type": "VEC3"],
                ["bufferView": 2, "componentType": 5126, "count": verticesList.count, "type": "VEC2"],
                ["bufferView": 3, "componentType": 5125, "count": indicesList.count, "type": "SCALAR"]
            ],
            "bufferViews": [
                ["buffer": 0, "byteOffset": 0, "byteLength": verticesList.count * 12, "target": 34962],
                ["buffer": 0, "byteOffset": verticesList.count * 12, "byteLength": verticesList.count * 12, "target": 34962],
                ["buffer": 0, "byteOffset": verticesList.count * 24, "byteLength": verticesList.count * 8, "target": 34962],
                ["buffer": 0, "byteOffset": verticesList.count * 32, "byteLength": indicesList.count * 4, "target": 34963]
            ],
            "buffers": [["byteLength": verticesList.count * 32 + indicesList.count * 4, "uri": url.lastPathComponent.replacingOccurrences(of: ".gltf", with: ".bin")]]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: gltf, options: .prettyPrinted) else {
            throw ExportError.writeFailed("GLTF serialization failed")
        }
        try data.write(to: url)
    }

    private func exportOBJ(model: Model, to url: URL) throws {
        try exportToOBJ(model: model, url: url)
    }

    private func exportSTL(model: Model, to url: URL) throws {
        try exportToSTL(model: model, url: url)
    }

    private func exportUSDZ(model: Model, to url: URL) throws {
        try exportToUSDZ(model: model, url: url)
    }

    private func exportSTEP(model: Model, to url: URL) throws {
        try exportToSTEP(model: model, url: url)
    }

    private func exportGLTF(model: Model, to url: URL) throws {
        try exportToGLTF(model: model, url: url)
    }

    private func exportFBX(model: Model, to url: URL) throws {
        let now = Date()
        let cal = Calendar.current
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)
        let day = cal.component(.day, from: now)
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let second = cal.component(.second, from: now)
        let millis = cal.component(.nanosecond, from: now) / 1_000_000

        var fbx = ""
        fbx += "; FBX 7.4.0 project file\n; Generated by AppForge Studio\n\n"
        fbx += "FBXHeaderExtension:  {\n\tFBXHeaderVersion: 1003\n\tFBXVersion: 7400\n"
        fbx += "\tCreationTimeStamp:  {\n\t\tVersion: 1000\n\t\tYear: \(year)\n\t\tMonth: \(month)\n\t\tDay: \(day)\n\t\tHour: \(hour)\n\t\tMinute: \(minute)\n\t\tSecond: \(second)\n\t\tMillisecond: \(millis)\n\t}\n\tCreator: \"AppForge Studio\"\n}\n\n"
        fbx += "GlobalSettings:  {\n\tVersion: 1000\n\tProperties70:  {\n\t\tP: \"UpAxis\", \"int\", \"Integer\", \"\",1\n\t\tP: \"UpAxisSign\", \"int\", \"Integer\", \"\",1\n\t\tP: \"FrontAxis\", \"int\", \"Integer\", \"\",2\n\t\tP: \"FrontAxisSign\", \"int\", \"Integer\", \"\",1\n\t\tP: \"CoordAxis\", \"int\", \"Integer\", \"\",0\n\t\tP: \"CoordAxisSign\", \"int\", \"Integer\", \"\",1\n\t\tP: \"OriginalUpAxis\", \"int\", \"Integer\", \"\",1\n\t\tP: \"OriginalUpAxisSign\", \"int\", \"Integer\", \"\",1\n\t\tP: \"UnitScaleFactor\", \"double\", \"Number\", \"\",1.000000\n\t\tP: \"OriginalUnitScaleFactor\", \"double\", \"Number\", \"\",1.000000\n\t}\n}\n\n"
        fbx += "Documents:  {\n\tCount: 1\n\tDocument: 0, \"Scene\", \"Scene\" {\n\t\tProperties70:  {\n\t\t\tP: \"SourceObject\", \"object\", \"\", \"\"\n\t\t\tP: \"ActiveAnimStackName\", \"KString\", \"\", \"\", \"\"\n\t\t}\n\t\tRootNode: 0\n\t}\n}\n\nReferences:  {\n}\n\n"

        let totalMeshes = model.meshes.count
        let hasMaterials = model.usesPBR
        var definitionCount = 3
        if hasMaterials { definitionCount += 1 }
        if totalMeshes > 1 { definitionCount += 1 }

        fbx += "Definitions:  {\n\tVersion: 100\n\tCount: \(definitionCount)\n"
        fbx += "\tObjectType: \"GlobalSettings\" { Count: 1 }\n"
        fbx += "\tObjectType: \"Model\" { Count: \(totalMeshes + 1) }\n"
        fbx += "\tObjectType: \"Geometry\" { Count: \(totalMeshes) }\n"
        if hasMaterials { fbx += "\tObjectType: \"Material\" { Count: \(totalMeshes) }\n" }
        fbx += "\tObjectType: \"Document\" { Count: 1 }\n}\n\n"

        fbx += "Objects:  {\n"
        var geomIDs: [Int64] = []
        var materialIDs: [Int64] = []
        var childModelIDs: [Int64] = []

        for (meshIndex, mesh) in model.meshes.enumerated() {
            let geomID: Int64 = Int64(100 + meshIndex)
            geomIDs.append(geomID)
            fbx += "\tGeometry: \(geomID), \"Geometry::mesh_\(meshIndex)\", \"Mesh\" {\n"
            fbx += "\t\tProperties70:  {\n\t\t\tP: \"Color\", \"ColorRGB\", \"Color\", \"\",\(fmt(model.color.x)),\(fmt(model.color.y)),\(fmt(model.color.z))\n\t\t}\n"
            fbx += "\t\tVertices: "
            for v in mesh.vertices { fbx += "\(fmt(v.position.x)),\(fmt(v.position.y)),\(fmt(v.position.z))," }
            fbx = String(fbx.dropLast()) + "\n"
            fbx += "\t\tPolygonVertexIndex: "
            for i in stride(from: 0, to: mesh.indices.count, by: 3) {
                fbx += "\(mesh.indices[i]),\(mesh.indices[i+1]),\(-(Int64(mesh.indices[i+2]) + 1)),"
            }
            fbx = String(fbx.dropLast()) + "\n"
            fbx += "\t\tGeometryVersion: 124\n"
            fbx += "\t\tLayerElementNormal: 0 {\n\t\t\tVersion: 101\n\t\t\tName: \"\"\n\t\t\tMappingInformationType: \"ByPolygonVertex\"\n\t\t\tReferenceInformationType: \"Direct\"\n\t\t\tNormals: "
            for i in mesh.indices { let n = mesh.vertices[Int(i)].normal; fbx += "\(fmt(n.x)),\(fmt(n.y)),\(fmt(n.z))," }
            fbx = String(fbx.dropLast()) + "\n\t\t}\n"
            fbx += "\t\tLayerElementUV: 0 {\n\t\t\tVersion: 101\n\t\t\tName: \"UVMap\"\n\t\t\tMappingInformationType: \"ByPolygonVertex\"\n\t\t\tReferenceInformationType: \"IndexToDirect\"\n\t\t\tUV: "
            for i in mesh.indices { let uv = mesh.vertices[Int(i)].uv; fbx += "\(fmt(uv.x)),\(fmt(1.0 - uv.y))," }
            fbx = String(fbx.dropLast()) + "\n"
            fbx += "\t\t\tUVIndex: "
            for j in 0..<mesh.indices.count { fbx += "\(j)," }
            fbx = String(fbx.dropLast()) + "\n\t\t}\n"
            if hasMaterials {
                fbx += "\t\tLayerElementMaterial: 0 {\n\t\t\tVersion: 101\n\t\t\tName: \"\"\n\t\t\tMappingInformationType: \"AllSame\"\n\t\t\tReferenceInformationType: \"IndexToDirect\"\n\t\t\tMaterials: 0\n\t\t}\n"
            }
            fbx += "\t\tLayer: 0 {\n\t\t\tLayerElement:  { Type: \"LayerElementNormal\" TypedIndex: 0 }\n\t\t\tLayerElement:  { Type: \"LayerElementUV\" TypedIndex: 0 }\n"
            if hasMaterials { fbx += "\t\t\tLayerElement:  { Type: \"LayerElementMaterial\" TypedIndex: 0 }\n" }
            fbx += "\t\t}\n\t}\n"
        }

        let meshName = model.name.isEmpty ? "Model" : model.name
        fbx += "\tModel: 0, \"Scene::RootNode\", \"Null\" {\n\t\tVersion: 232\n\t\tProperties70:  {\n\t\t\tP: \"RotationActive\", \"bool\", \"\", \"\",1\n\t\t\tP: \"InheritType\", \"enum\", \"\", \"\",1\n\t\t\tP: \"ScalingMax\", \"Vector3D\", \"Vector\", \"\",0,0,0\n\t\t\tP: \"DefaultAttributeIndex\", \"int\", \"Integer\", \"\",0\n\t\t}\n\t}\n"

        for meshIndex in 0..<totalMeshes {
            let childID: Int64 = Int64(300 + meshIndex)
            childModelIDs.append(childID)
            let displayName = totalMeshes > 1 ? "\(meshName)_\(meshIndex)" : meshName
            let pos = model.position; let rot = model.rotation; let scl = model.scale
            fbx += "\tModel: \(childID), \"Model::\(displayName)\", \"Mesh\" {\n\t\tVersion: 232\n\t\tProperties70:  {\n\t\t\tP: \"QuaternionInterpolate\", \"enum\", \"\", \"\",0\n\t\t\tP: \"RotationOffset\", \"Vector3D\", \"Vector\", \"\",0,0,0\n\t\t\tP: \"RotationPivot\", \"Vector3D\", \"Vector\", \"\",0,0,0\n\t\t\tP: \"ScalingOffset\", \"Vector3D\", \"Vector\", \"\",0,0,0\n\t\t\tP: \"ScalingPivot\", \"Vector3D\", \"Vector\", \"\",0,0,0\n\t\t\tP: \"TranslationActive\", \"bool\", \"\", \"\",1\n\t\t\tP: \"Lcl Translation\", \"Lcl Translation\", \"\", \"A+\",\(fmt(pos.x)),\(fmt(pos.y)),\(fmt(pos.z))\n"
            let eulerX = rot.axis.x * rot.angle * 180.0 / Float.pi
            let eulerY = rot.axis.y * rot.angle * 180.0 / Float.pi
            let eulerZ = rot.axis.z * rot.angle * 180.0 / Float.pi
            fbx += "\t\t\tP: \"Lcl Rotation\", \"Lcl Rotation\", \"\", \"A+\",\(fmt(eulerX)),\(fmt(eulerY)),\(fmt(eulerZ))\n"
            fbx += "\t\t\tP: \"Lcl Scaling\", \"Lcl Scaling\", \"\", \"A+\",\(fmt(scl.x)),\(fmt(scl.y)),\(fmt(scl.z))\n"
            fbx += "\t\t\tP: \"RotationActive\", \"bool\", \"\", \"\",1\n\t\t\tP: \"InheritType\", \"enum\", \"\", \"\",1\n\t\t\tP: \"DefaultAttributeIndex\", \"int\", \"Integer\", \"\",0\n\t\t}\n\t}\n"
        }

        if hasMaterials {
            for meshIndex in 0..<totalMeshes {
                let matID: Int64 = Int64(200 + meshIndex)
                materialIDs.append(matID)
                let mat = model.pbrMaterial
                fbx += "\tMaterial: \(matID), \"Material::\(mat.name)\", \"\" {\n\t\tVersion: 102\n\t\tShadingModel: \"phong\"\n\t\tMultiLayer: 0\n\t\tProperties70:  {\n"
                fbx += "\t\t\tP: \"DiffuseColor\", \"ColorRGB\", \"Color\", \"\",\(fmt(mat.albedo.x)),\(fmt(mat.albedo.y)),\(fmt(mat.albedo.z))\n"
                fbx += "\t\t\tP: \"DiffuseFactor\", \"double\", \"Number\", \"\",\(fmt(mat.albedo.x * 0.5 + mat.albedo.y * 0.3 + mat.albedo.z * 0.2))\n"
                fbx += "\t\t\tP: \"SpecularColor\", \"ColorRGB\", \"Color\", \"\",\(fmt(1.0 - mat.roughness)),\(fmt(1.0 - mat.roughness)),\(fmt(1.0 - mat.roughness))\n"
                fbx += "\t\t\tP: \"SpecularFactor\", \"double\", \"Number\", \"\",\(fmt(1.0 - mat.roughness))\n"
                fbx += "\t\t\tP: \"Shininess\", \"double\", \"Number\", \"\",\(fmt((1.0 - mat.roughness) * 128.0))\n"
                fbx += "\t\t\tP: \"EmissiveColor\", \"ColorRGB\", \"Color\", \"\",\(fmt(mat.emission.x * mat.emissionIntensity)),\(fmt(mat.emission.y * mat.emissionIntensity)),\(fmt(mat.emission.z * mat.emissionIntensity))\n"
                fbx += "\t\t\tP: \"EmissiveFactor\", \"double\", \"Number\", \"\",\(fmt(mat.emissionIntensity))\n\t\t}\n\t}\n"
            }
        }
        fbx += "}\n\nConnections:  {\n"
        for meshIndex in 0..<totalMeshes {
            fbx += "\tC: \"OO\",\(geomIDs[meshIndex]),\(childModelIDs[meshIndex])\n"
            fbx += "\tC: \"OO\",\(childModelIDs[meshIndex]),0\n"
        }
        if hasMaterials {
            for meshIndex in 0..<totalMeshes {
                fbx += "\tC: \"OO\",\(materialIDs[meshIndex]),\(childModelIDs[meshIndex])\n"
                fbx += "\tC: \"OP\",\(materialIDs[meshIndex]),\(geomIDs[meshIndex]), \"P\"\n"
            }
        }
        fbx += "}\n"
        try fbx.write(to: url, atomically: true, encoding: .ascii)
    }

    private func fmt(_ value: Float) -> String {
        if value == 0 { return "0" }
        let s = String(format: "%.6f", value)
        var trimmed = s
        while trimmed.hasSuffix("0") && trimmed.contains(".") { trimmed = String(trimmed.dropLast()) }
        if trimmed.hasSuffix(".") { trimmed = String(trimmed.dropLast()) }
        return trimmed
    }

    private func fmt(_ value: Double) -> String {
        if value == 0 { return "0" }
        let s = String(format: "%.6f", value)
        var trimmed = s
        while trimmed.hasSuffix("0") && trimmed.contains(".") { trimmed = String(trimmed.dropLast()) }
        if trimmed.hasSuffix(".") { trimmed = String(trimmed.dropLast()) }
        return trimmed
    }

    private func buildMDLAsset(from model: Model) -> MDLAsset? {
        let asset = MDLAsset()
        for mesh in model.meshes {
            let allocator = MTKMeshBufferAllocator(device: device)
            let vertexData = mesh.vertices.withUnsafeBytes { Data($0) }
            let indexData = mesh.indices.withUnsafeBytes { Data($0) }
            let vtxBuffer = allocator.newBuffer(with: vertexData, type: .vertex)
            let idxBuffer = allocator.newBuffer(with: indexData, type: .index)
            let vertexCount = mesh.vertices.count
            let indexCount = mesh.indices.count
            let mdlMesh = MDLMesh(
                vertexBuffer: vtxBuffer,
                vertexCount: vertexCount,
                descriptor: MDLVertexDescriptor(),
                submeshes: [MDLSubmesh(
                    indexBuffer: idxBuffer,
                    indexCount: indexCount,
                    indexType: .uInt32,
                    geometryType: .triangles,
                    material: nil
                )]
            )
            asset.add(mdlMesh)
        }
        return asset
    }
}
