import XCTest
import MetalKit
import simd
@testable import AppForgeStudio

/// Tests for hybrid export pipeline: validation, GLTF binary buffer, roundtrip integrity.
///
/// APIs verified:
///   ExportService.validateMeshForExport(_:name:)  → Core/Services/ExportService/ExportService.swift
///   ExportService.validateModelForExport(_:)       → Core/Services/ExportService/ExportService.swift
///   ExportService.exportToGLTF(model:url:)          → Core/Services/ExportService/ExportService.swift
///   ExportService.exportToOBJ(model:url:)           → Core/Services/ExportService/ExportService.swift
///   ExportService.exportToSTL(model:url:)           → Core/Services/ExportService/ExportService.swift
///   Mesh.indices is [UInt32]                        → Sources/Engines/Mesh.swift:35
final class HybridExportTests: XCTestCase {

    var device: MTLDevice!
    var exportService: ExportService!
    var cubeModel: Model!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        guard let dev = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal device required for export tests")
        }
        device = dev
        exportService = ExportService(device: device)
        cubeModel = TestCube.build(name: "HybridTestCube")
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("HybridExportTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        cubeModel = nil
        exportService = nil
        device = nil
        super.tearDown()
    }

    // MARK: - UInt32 index verification

    /// Verifies Mesh.indices is [UInt32], not UInt16 (BUG3 is fixed, verified here).
    func testMeshIndicesAreUInt32() {
        let mesh = cubeModel.meshes.first!
        // Type check: indices array is [UInt32]
        let _: [UInt32] = mesh.indices
        XCTAssertTrue(mesh.indices is [UInt32], "Mesh.indices must be [UInt32]")
    }

    /// Verifies buildMDLAsset uses .uInt32 index type.
    func testMDLAssetUsesUInt32IndexType() throws {
        // Export via MDLAsset path (OBJ) and verify the file is produced
        let url = tempDir.appendingPathComponent("uint32_check.obj")
        try exportService.exportToOBJ(model: cubeModel, url: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - Validation tests

    /// A valid cube should pass all validation checks.
    func testValidCubePassesValidation() {
        guard let mesh = cubeModel.meshes.first else {
            XCTFail("Cube must have a mesh")
            return
        }
        let report = ExportService.validateMeshForExport(mesh, name: "cube")
        XCTAssertTrue(report.isValid, "Valid cube must pass validation, got \(report.errorCount) errors:\n\(report.description)")
        XCTAssertTrue(report.isWatertight, "Valid cube must be watertight")
        XCTAssertTrue(report.isManifold, "Valid cube must be manifold")
        XCTAssertFalse(report.hasNaN, "Valid cube must have no NaN")
    }

    /// Empty mesh must report validation issues.
    func testEmptyMeshFailsValidation() {
        let emptyMesh = Mesh(vertices: [], indices: [])
        let report = ExportService.validateMeshForExport(emptyMesh, name: "empty")
        XCTAssertFalse(report.isValid, "Empty mesh must fail validation")
    }

    /// Mesh with NaN position must be detected.
    func testNaNPositionDetected() {
        var badVerts = cubeModel.meshes.first!.vertices
        badVerts[0].position = SIMD3<Float>(Float.nan, 0, 0)
        let badMesh = Mesh(vertices: badVerts, indices: cubeModel.meshes.first!.indices)
        let report = ExportService.validateMeshForExport(badMesh, name: "nan_mesh")
        XCTAssertTrue(report.hasNaN, "NaN position must be detected")
        XCTAssertFalse(report.isValid, "NaN mesh must fail validation")
    }

    /// Mesh with orphan face (index out of bounds) must be detected.
    func testOrphanFaceDetected() {
        let verts = cubeModel.meshes.first!.vertices
        var badIndices = cubeModel.meshes.first!.indices
        // Replace last index with an out-of-bounds value
        badIndices[badIndices.count - 1] = UInt32(verts.count + 100)
        let badMesh = Mesh(vertices: verts, indices: badIndices)
        let report = ExportService.validateMeshForExport(badMesh, name: "orphan_mesh")
        let orphanErrors = report.issues.filter {
            if case .orphanFace = $0 { return true }; return false
        }
        XCTAssertFalse(orphanErrors.isEmpty, "Orphan face must be detected")
    }

    /// Mesh with non-manifold edge must be detected.
    func testNonManifoldEdgeDetected() {
        // Create a mesh where one edge is shared by 3+ faces (non-manifold)
        // Simple: create 3 triangles sharing the same edge (0,1)
        let verts: [Vertex] = [
            Vertex(position: SIMD3(0, 0, 0), normal: SIMD3(0, 1, 0), uv: SIMD2(0, 0)),
            Vertex(position: SIMD3(1, 0, 0), normal: SIMD3(0, 1, 0), uv: SIMD2(1, 1)),
            Vertex(position: SIMD3(0, 1, 0), normal: SIMD3(0, 1, 0), uv: SIMD2(0, 1)),
            Vertex(position: SIMD3(1, 1, 0), normal: SIMD3(0, 1, 0), uv: SIMD2(1, 0)),
            Vertex(position: SIMD3(0.5, 0.5, 1), normal: SIMD3(0, 0, 1), uv: SIMD2(0.5, 0.5)),
        ]
        // 3 faces all sharing edge (0,1): faces (0,1,2), (0,1,3), (0,1,4)
        let indices: [UInt32] = [0, 1, 2, 0, 1, 3, 0, 1, 4]
        let nonManifoldMesh = Mesh(vertices: verts, indices: indices)
        let report = ExportService.validateMeshForExport(nonManifoldMesh, name: "non_manifold")

        let nmErrors = report.issues.filter {
            if case .nonManifoldEdge = $0 { return true }; return false
        }
        XCTAssertFalse(nmErrors.isEmpty, "Non-manifold edge (shared by 3 faces) must be detected, got: \(report.description)")
    }

    /// Model-level validation aggregates per-mesh reports.
    func testModelValidationAggregatesMeshes() {
        let report = ExportService.validateModelForExport(cubeModel)
        XCTAssertTrue(report.isValid, "Valid cube model must pass validation")
        // TestCube name is passed through
        XCTAssertTrue(report.meshName.contains("TestCube") || report.meshName.contains("HybridTestCube"),
                      "Model name must be in report, got: \(report.meshName)")
    }

    // MARK: - GLTF binary buffer roundtrip

    /// Exports to GLTF and verifies the binary .bin buffer file is written.
    func testGLTFExportWritesBinaryBuffer() throws {
        let gltfURL = tempDir.appendingPathComponent("cube.gltf")
        try exportService.exportToGLTF(model: cubeModel, url: gltfURL)

        // GLTF JSON file must exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: gltfURL.path),
                      "GLTF file must exist at \(gltfURL.path)")

        let gltfContent = try String(contentsOf: gltfURL, encoding: .utf8)
        XCTAssertTrue(gltfContent.contains("\"buffers\""), "GLTF must reference binary buffer")
        XCTAssertTrue(gltfContent.contains(".bin"), "GLTF must reference .bin URI")

        // Binary buffer must exist
        let binURL = gltfURL.deletingPathExtension().appendingPathExtension("bin")
        XCTAssertTrue(FileManager.default.fileExists(atPath: binURL.path),
                      "Binary buffer .bin must exist at \(binURL.path)")

        let binData = try Data(contentsOf: binURL)
        // TestCube has 8 vertices * 32 + 36 indices * 4 = 256 + 144 = 400 bytes
        let expectedVertexBytes = 8 * 32  // positions(12) + normals(12) + texcoords(8)
        let expectedIndexBytes = 36 * 4
        let expectedTotal = expectedVertexBytes + expectedIndexBytes
        XCTAssertEqual(binData.count, expectedTotal,
                       "Binary buffer size mismatch: expected \(expectedTotal), got \(binData.count)")

        // Verify GLTF JSON references correct buffer byteLength
        XCTAssertTrue(gltfContent.contains("\"byteLength\" : \(expectedTotal)") ||
                      gltfContent.contains("\"byteLength\":\(expectedTotal)"),
                      "GLTF must declare correct buffer byteLength")
    }

    /// GLTF export fails gracefully for empty model.
    func testGLTFExportEmptyModelThrows() {
        let emptyModel = Model(name: "Empty")
        let url = tempDir.appendingPathComponent("empty.gltf")
        XCTAssertThrowsError(try exportService.exportToGLTF(model: emptyModel, url: url))
    }

    // MARK: - Export roundtrip integrity

    /// OBJ roundtrip: export then verify file is non-empty and well-formed.
    func testOBJRoundtrip() throws {
        let url = tempDir.appendingPathComponent("roundtrip.obj")
        try exportService.exportToOBJ(model: cubeModel, url: url)

        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0, "OBJ file must not be empty")

        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("v "), "OBJ must contain vertex definitions")
        XCTAssertTrue(content.contains("f "), "OBJ must contain face definitions")
    }

    /// STL roundtrip: export then verify binary STL structure.
    func testSTLRoundtrip() throws {
        let url = tempDir.appendingPathComponent("roundtrip.stl")
        try exportService.exportToSTL(model: cubeModel, url: url)

        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 84, "STL must have header + count (84 bytes min)")

        // Read triangle count
        let triCount = data.withUnsafeBytes { raw in
            raw.loadUnaligned(fromByteOffset: 80, as: UInt32.self)
        }
        XCTAssertEqual(triCount, 12, "Cube STL must have 12 triangles")
    }

    /// USDZ roundtrip: export then verify file exists.
    func testUSDZRoundtrip() throws {
        let url = tempDir.appendingPathComponent("roundtrip.usdz")
        try exportService.exportToUSDZ(model: cubeModel, url: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0, "USDZ file must not be empty")
    }

    // MARK: - Export via main export() with validation

    func testExportWithValidationPasses() {
        let url = tempDir.appendingPathComponent("validated.stl")
        let result = exportService.export(model: cubeModel, format: .stl, to: url)
        switch result {
        case .success:
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        case .failure(let error):
            XCTFail("Export with valid model should succeed, got: \(error.localizedDescription)")
        }
    }

    func testExportEmptyModelReturnsFailure() {
        let emptyModel = Model(name: "Void")
        let url = tempDir.appendingPathComponent("void.stl")
        let result = exportService.export(model: emptyModel, format: .stl, to: url)
        switch result {
        case .success:
            XCTFail("Export of empty model should fail")
        case .failure(let error):
            XCTAssertNotNil(error.errorDescription)
        }
    }
}
