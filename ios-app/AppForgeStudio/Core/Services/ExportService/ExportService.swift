import Foundation
import simd
import ModelIO
import MetalKit
import SceneKit
import SceneKit.ModelIO
import UIKit
import OCCTSwift
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

// MARK: - Mesh Validation (watertight/manifold pre-export check)

/// Individual validation issue found during mesh inspection.
enum MeshValidationIssue: LocalizedError, CustomStringConvertible {
    case orphanFace(faceIndex: Int, vertexIndex: UInt32, vertexCount: Int)
    case nonManifoldEdge(v0: UInt32, v1: UInt32, faceCount: Int)
    case nanPosition(vertexIndex: Int)
    case nanNormal(vertexIndex: Int)
    case degenerateFace(faceIndex: Int, area: Float)
    case zeroAreaFace(faceIndex: Int)
    case zeroLengthEdge(v0: UInt32, v1: UInt32)

    var description: String {
        switch self {
        case .orphanFace(let fi, let vi, let vc):
            return "Cara \(fi): índice \(vi) fuera de rango (máx \(vc - 1))"
        case .nonManifoldEdge(let v0, let v1, let fc):
            return "Arista (\(v0),\(v1)) compartida por \(fc) caras (non-manifold)"
        case .nanPosition(let vi):
            return "Vértice \(vi): posición contiene NaN"
        case .nanNormal(let vi):
            return "Vértice \(vi): normal contiene NaN"
        case .degenerateFace(let fi, let area):
            return "Cara \(fi): área degenerada (\(String(format: "%.8f", area)))"
        case .zeroAreaFace(let fi):
            return "Cara \(fi): área cero (vértices colineales o duplicados)"
        case .zeroLengthEdge(let v0, let v1):
            return "Arista (\(v0),\(v1)): longitud cero (vértices coincidentes)"
        }
    }

    var errorDescription: String? { description }

    var severity: ValidationSeverity {
        switch self {
        case .orphanFace, .nonManifoldEdge: return .error
        case .nanPosition, .nanNormal: return .error
        case .degenerateFace, .zeroAreaFace, .zeroLengthEdge: return .warning
        }
    }
}

enum ValidationSeverity: String {
    case error = "Error"
    case warning = "Advertencia"
}

/// Result of pre-export mesh validation.
struct MeshValidationReport: CustomStringConvertible {
    let issues: [MeshValidationIssue]
    let meshName: String

    var errorCount: Int { issues.filter { $0.severity == .error }.count }
    var warningCount: Int { issues.filter { $0.severity == .warning }.count }
    var isWatertight: Bool { errorCount == 0 && !issues.contains(where: { if case .nonManifoldEdge = $0 { return true }; return false }) }
    var isManifold: Bool { !issues.contains(where: { if case .nonManifoldEdge = $0 { return true }; return false }) }
    var hasNaN: Bool { issues.contains(where: { if case .nanPosition = $0 { return true }; if case .nanNormal = $0 { return true }; return false }) }
    var isValid: Bool { errorCount == 0 }

    var description: String {
        var lines: [String] = ["Validación de malla '\(meshName)':"]
        if issues.isEmpty {
            lines.append("  ✓ Sin problemas detectados")
        } else {
            for issue in issues {
                lines.append("  [\(issue.severity.rawValue)] \(issue.description)")
            }
        }
        lines.append("  Resumen: \(errorCount) errores, \(warningCount) advertencias")
        lines.append("  Watertight: \(isWatertight ? "Sí" : "No"), Manifold: \(isManifold ? "Sí" : "No"), NaN: \(hasNaN ? "Sí" : "No")")
        return lines.joined(separator: "\n")
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

    // MARK: - Pre-export mesh validation

    /// Validates a mesh for watertightness, manifold edges, NaN values, and degenerate faces.
    /// Reports all issues found; call before export to warn the user.
    static func validateMeshForExport(_ mesh: Mesh, name: String = "mesh") -> MeshValidationReport {
        var issues: [MeshValidationIssue] = []

        let vertexCount = mesh.vertices.count
        let indexCount = mesh.indices.count

        // Check 1: empty mesh
        guard vertexCount > 0 else {
            issues.append(.orphanFace(faceIndex: -1, vertexIndex: 0, vertexCount: 0))
            return MeshValidationReport(issues: issues, meshName: name)
        }
        guard indexCount > 0 else {
            return MeshValidationReport(issues: issues, meshName: name)
        }

        // Check 2: orphan faces — indices referencing non-existent vertices
        for (fi, vi) in mesh.indices.enumerated() {
            if Int(vi) >= vertexCount {
                issues.append(.orphanFace(faceIndex: fi / 3, vertexIndex: vi, vertexCount: vertexCount))
            }
        }

        // Check 3: NaN positions and normals
        for (vi, vertex) in mesh.vertices.enumerated() {
            let p = vertex.position
            if p.x.isNaN || p.y.isNaN || p.z.isNaN || !p.x.isFinite || !p.y.isFinite || !p.z.isFinite {
                issues.append(.nanPosition(vertexIndex: vi))
            }
            let n = vertex.normal
            if n.x.isNaN || n.y.isNaN || n.z.isNaN || !n.x.isFinite || !n.y.isFinite || !n.z.isFinite {
                issues.append(.nanNormal(vertexIndex: vi))
            }
        }

        // Check 4: non-manifold edges — edges shared by >2 faces
        var edgeFaceCount: [UInt64: Int] = [:]
        for fi in stride(from: 0, to: indexCount - 2, by: 3) {
            let a = mesh.indices[fi]
            let b = mesh.indices[fi + 1]
            let c = mesh.indices[fi + 2]

            // Check for degenerate/zero-area faces
            if a == b || b == c || a == c {
                issues.append(.degenerateFace(faceIndex: fi / 3, area: 0))
                continue
            }

            // Caras huérfanas ya reportadas en Check 2 — no indexar fuera de rango
            guard Int(a) < vertexCount, Int(b) < vertexCount, Int(c) < vertexCount else {
                continue
            }

            let pa = mesh.vertices[Int(a)].position
            let pb = mesh.vertices[Int(b)].position
            let pc = mesh.vertices[Int(c)].position
            let area = simd_length(simd_cross(pb - pa, pc - pa)) * 0.5
            if area < 1e-10 {
                issues.append(.zeroAreaFace(faceIndex: fi / 3))
            }
            if area.isNaN || area.isInfinite {
                issues.append(.degenerateFace(faceIndex: fi / 3, area: area))
            }

            // Count edge usage
            let edges = [(a, b), (b, c), (c, a)]
            for (v0, v1) in edges {
                let minV = min(v0, v1)
                let maxV = max(v0, v1)
                // Check zero-length edge
                if minV == maxV {
                    issues.append(.zeroLengthEdge(v0: v0, v1: v1))
                }
                let key = (UInt64(minV) << 32) | UInt64(maxV)
                edgeFaceCount[key, default: 0] += 1
            }
        }

        // Report non-manifold edges
        for (key, count) in edgeFaceCount {
            if count > 2 {
                let v0 = UInt32(key >> 32)
                let v1 = UInt32(key & 0xFFFFFFFF)
                issues.append(.nonManifoldEdge(v0: v0, v1: v1, faceCount: count))
            }
        }

        // Deduplicate issues
        var seen: Set<String> = []
        issues = issues.filter { seen.insert($0.description).inserted }

        return MeshValidationReport(issues: issues, meshName: name)
    }

    /// Validates all meshes in a model and returns a combined report.
    static func validateModelForExport(_ model: Model) -> MeshValidationReport {
        var allIssues: [MeshValidationIssue] = []
        for (i, mesh) in model.meshes.enumerated() {
            let report = validateMeshForExport(mesh, name: "\(model.name).mesh[\(i)]")
            allIssues.append(contentsOf: report.issues)
        }
        return MeshValidationReport(issues: allIssues, meshName: model.name)
    }

    /// Validates and returns a user-facing summary. Use before export to warn.
    func validateAndReport(model: Model) -> String {
        let report = Self.validateModelForExport(model)
        logger.info("\(report.description)")
        return report.description
    }

    func export(model: Model, format: ExportFormat, to url: URL, skipValidation: Bool = false) -> Result<Void, ExportError> {
        // Overlays de escena (`__livePreview`, `__faceHighlight`, gizmos, cotas…) NO
        // son geometría del usuario: nunca se exportan (Ola LiveInteraction · L1 ·
        // tarea 3). Antes solo `exportUSDZScene` filtraba `__`; las rutas de un solo
        // modelo (OBJ/STL/STEP/GLTF/FBX) exportarían el fantasma si se les entregaba.
        guard !model.name.hasPrefix("__") else {
            return .failure(.invalidModel("Los overlays de escena (\(model.name)) no se exportan"))
        }
        guard !model.meshes.isEmpty, model.meshes.contains(where: { !$0.vertices.isEmpty }) else {
            return .failure(.invalidModel("El modelo no tiene vertices para exportar"))
        }

        // Pre-export validation (watertight/manifold/NaN check)
        if !skipValidation {
            let report = Self.validateModelForExport(model)
            logger.info("\(report.description)")
            if !report.isValid {
                logger.warning("Export proceeding with \(report.errorCount) validation errors — output may be invalid")
            }
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
        try asset.export(to: url)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExportError.writeFailed("STL export failed - file was not written to disk")
        }
    }

    func exportToUSDZ(model: Model, url: URL) throws {
        try exportUSDZScene(models: [model], to: url)
    }

    /// USDZ de VARIOS cuerpos con su material PBR real (AR de escena completa).
    /// Antes: material nil → AR Quick Look mostraba plástico gris; el color y
    /// el PBR del modelo se perdían (catálogo §5: "AR realista" pendiente).
    func exportUSDZScene(models: [Model], to url: URL) throws {
        let exportables = models.filter { !$0.name.hasPrefix("__") && !$0.meshes.isEmpty }
        guard !exportables.isEmpty else {
            throw ExportError.invalidModel("No hay cuerpos exportables para AR")
        }
        let master = SCNScene()
        for model in exportables {
            guard let asset = buildMDLAsset(from: model) else { continue }
            // ModelIO no escribe .usdz en iOS ("Unknown extension") — SceneKit sí.
            let scene = SCNScene(mdlAsset: asset)
            let material = scnMaterial(for: model)
            for child in scene.rootNode.childNodes {
                child.enumerateHierarchy { node, _ in
                    node.geometry?.materials = [material]
                }
                master.rootNode.addChildNode(child)
            }
        }
        guard !master.rootNode.childNodes.isEmpty else {
            throw ExportError.invalidModel("No se pudo construir el asset USDZ")
        }
        let success = master.write(to: url, options: nil, delegate: nil, progressHandler: nil)
        guard success, FileManager.default.fileExists(atPath: url.path) else {
            throw ExportError.writeFailed("USDZ export failed - file was not written to disk")
        }
    }

    /// Material SceneKit PBR desde el estado real del modelo: albedo/metalness/
    /// roughness del editor PBR si está activo, si no el color base del cuerpo.
    private func scnMaterial(for model: Model) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        if model.usesPBR {
            let a = model.pbrMaterial.albedo
            material.diffuse.contents = UIColor(red: CGFloat(a.x), green: CGFloat(a.y),
                                                blue: CGFloat(a.z), alpha: 1)
            material.metalness.contents = NSNumber(value: model.pbrMaterial.metalness)
            material.roughness.contents = NSNumber(value: model.pbrMaterial.roughness)
            let e = model.pbrMaterial.emission
            if model.pbrMaterial.emissionIntensity > 0.01 {
                material.emission.contents = UIColor(red: CGFloat(e.x), green: CGFloat(e.y),
                                                     blue: CGFloat(e.z), alpha: 1)
            }
        } else {
            let c = model.color
            material.diffuse.contents = UIColor(red: CGFloat(c.x), green: CGFloat(c.y),
                                                blue: CGFloat(c.z), alpha: CGFloat(c.w))
            // Look de sólido CAD: apenas metálico, semi-mate (coincide con el visor)
            material.metalness.contents = NSNumber(value: 0.1)
            material.roughness.contents = NSNumber(value: 0.55)
        }
        return material
    }

    func exportToSTEP(model: Model, url: URL) throws {
        guard !model.meshes.isEmpty else {
            throw ExportError.invalidModel("Model has no meshes for STEP export")
        }
        // STEP REAL (AP214) vía kernel OCCT: B-rep exacto con NURBS y topología —
        // lo que Fusion/SolidWorks esperan abrir. El generador anterior volcaba la
        // malla triangulada como pseudo-STEP (CARTESIAN_POINT/POLYLOOP inventados)
        // que ningún CAD abría como sólido: placebo de exportación, retirado.
        guard let shape = model.cadShape else {
            throw ExportError.invalidModel(
                "\(model.name) no tiene B-rep (malla esculpida/importada) — usa STL/OBJ/USDZ")
        }
        try Exporter.writeSTEP(shape: shape, to: url)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExportError.writeFailed("STEP export failed - file was not written to disk")
        }
    }

    func exportToGLTF(model: Model, url: URL) throws {
        guard !model.meshes.isEmpty else {
            throw ExportError.invalidModel("No valid meshes found for GLTF export")
        }

        // Collect vertices and indices across all meshes
        var allPositions: [Float] = []
        var allNormals: [Float] = []
        var allTexCoords: [Float] = []
        var allIndices: [UInt32] = []
        var vertexOffset: UInt32 = 0
        var minPos = SIMD3<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxPos = SIMD3<Float>(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)

        for mesh in model.meshes {
            for v in mesh.vertices {
                let p = v.position
                allPositions.append(contentsOf: [p.x, p.y, p.z])
                allNormals.append(contentsOf: [v.normal.x, v.normal.y, v.normal.z])
                allTexCoords.append(contentsOf: [v.uv.x, v.uv.y])
                minPos = SIMD3(min(minPos.x, p.x), min(minPos.y, p.y), min(minPos.z, p.z))
                maxPos = SIMD3(max(maxPos.x, p.x), max(maxPos.y, p.y), max(maxPos.z, p.z))
            }
            for i in mesh.indices { allIndices.append(i + vertexOffset) }
            vertexOffset += UInt32(mesh.vertices.count)
        }

        let vertexCount = allPositions.count / 3
        let indexCount = allIndices.count

        // Build binary buffer: positions (12B ea) + normals (12B ea) + texcoords (8B ea) + indices (4B ea)
        let posByteLen = vertexCount * 12
        let nmlByteLen = vertexCount * 12
        let uvByteLen  = vertexCount * 8
        let idxByteLen = indexCount * 4
        let totalBinLen = posByteLen + nmlByteLen + uvByteLen + idxByteLen

        var binData = Data(capacity: totalBinLen)
        // Write positions (tightly packed float3, 12 bytes each)
        for i in 0..<vertexCount {
            let off = i * 3
            binData.append(contentsOf: withUnsafeBytes(of: allPositions[off]) { Data($0) })
            binData.append(contentsOf: withUnsafeBytes(of: allPositions[off + 1]) { Data($0) })
            binData.append(contentsOf: withUnsafeBytes(of: allPositions[off + 2]) { Data($0) })
        }
        // Write normals
        for i in 0..<vertexCount {
            let off = i * 3
            binData.append(contentsOf: withUnsafeBytes(of: allNormals[off]) { Data($0) })
            binData.append(contentsOf: withUnsafeBytes(of: allNormals[off + 1]) { Data($0) })
            binData.append(contentsOf: withUnsafeBytes(of: allNormals[off + 2]) { Data($0) })
        }
        // Write texcoords
        for i in 0..<vertexCount {
            let off = i * 2
            binData.append(contentsOf: withUnsafeBytes(of: allTexCoords[off]) { Data($0) })
            binData.append(contentsOf: withUnsafeBytes(of: allTexCoords[off + 1]) { Data($0) })
        }
        // Write indices (UInt32 little-endian)
        for idx in allIndices {
            var le = idx.littleEndian
            binData.append(contentsOf: withUnsafeBytes(of: &le) { Data($0) })
        }

        // Verify binary buffer size
        guard binData.count == totalBinLen else {
            throw ExportError.writeFailed("GLTF binary buffer size mismatch: expected \(totalBinLen), got \(binData.count)")
        }

        // Write .bin file alongside .gltf
        let binURL = url.deletingPathExtension().appendingPathExtension("bin")
        try binData.write(to: binURL, options: .atomic)

        let gltf: [String: Any] = [
            "asset": ["version": "2.0", "generator": "AppForgeStudio"],
            "scene": 0,
            "scenes": [["nodes": [0]]],
            "nodes": [["mesh": 0, "name": model.name]],
            "meshes": [[
                "primitives": [[
                    "attributes": ["POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2],
                    "indices": 3,
                    "mode": 4  // TRIANGLES
                ]]
            ]],
            "accessors": [
                ["bufferView": 0, "componentType": 5126, "count": vertexCount, "type": "VEC3",
                 "min": [minPos.x, minPos.y, minPos.z], "max": [maxPos.x, maxPos.y, maxPos.z]],
                ["bufferView": 1, "componentType": 5126, "count": vertexCount, "type": "VEC3"],
                ["bufferView": 2, "componentType": 5126, "count": vertexCount, "type": "VEC2"],
                ["bufferView": 3, "componentType": 5125, "count": indexCount, "type": "SCALAR"]
            ],
            "bufferViews": [
                ["buffer": 0, "byteOffset": 0, "byteLength": posByteLen, "target": 34962],
                ["buffer": 0, "byteOffset": posByteLen, "byteLength": nmlByteLen, "target": 34962],
                ["buffer": 0, "byteOffset": posByteLen + nmlByteLen, "byteLength": uvByteLen, "target": 34962],
                ["buffer": 0, "byteOffset": posByteLen + nmlByteLen + uvByteLen, "byteLength": idxByteLen, "target": 34963]
            ],
            "buffers": [["byteLength": totalBinLen, "uri": binURL.lastPathComponent]]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: gltf, options: .prettyPrinted) else {
            throw ExportError.writeFailed("GLTF JSON serialization failed")
        }
        try jsonData.write(to: url, options: .atomic)

        logger.info("GLTF exported: \(url.path) + \(binURL.path) (\(totalBinLen) bytes binary)")
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
        let allocator = MTKMeshBufferAllocator(device: device)
        var meshCount = 0

        for mesh in model.meshes where !mesh.vertices.isEmpty && !mesh.indices.isEmpty {
            // Buffer empaquetado position(3)+normal(3)+uv(2) = 8 floats/vértice.
            // No volcar Vertex crudo: contiene UUID y padding que ModelIO no entiende.
            var packed = [Float]()
            packed.reserveCapacity(mesh.vertices.count * 8)
            for v in mesh.vertices {
                packed.append(contentsOf: [
                    v.position.x, v.position.y, v.position.z,
                    v.normal.x, v.normal.y, v.normal.z,
                    v.uv.x, v.uv.y,
                ])
            }
            let vertexData = packed.withUnsafeBytes { Data($0) }
            let indexData = mesh.indices.withUnsafeBytes { Data($0) }
            let vtxBuffer = allocator.newBuffer(with: vertexData, type: .vertex)
            let idxBuffer = allocator.newBuffer(with: indexData, type: .index)

            let descriptor = MDLVertexDescriptor()
            descriptor.attributes[0] = MDLVertexAttribute(
                name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
            descriptor.attributes[1] = MDLVertexAttribute(
                name: MDLVertexAttributeNormal, format: .float3, offset: 12, bufferIndex: 0)
            descriptor.attributes[2] = MDLVertexAttribute(
                name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: 24, bufferIndex: 0)
            descriptor.layouts[0] = MDLVertexBufferLayout(stride: 32)

            let mdlMesh = MDLMesh(
                vertexBuffer: vtxBuffer,
                vertexCount: mesh.vertices.count,
                descriptor: descriptor,
                submeshes: [MDLSubmesh(
                    indexBuffer: idxBuffer,
                    indexCount: mesh.indices.count,
                    indexType: .uInt32,
                    geometryType: .triangles,
                    material: nil
                )]
            )
            asset.add(mdlMesh)
            meshCount += 1
        }
        return meshCount > 0 ? asset : nil
    }
}
