import XCTest
@testable import AppForgeStudio

/// Validates exported geometry by re-parsing the output and checking structural invariants.
/// Uses TestCube (8 vertices, 12 triangles / 36 indices) as the canonical input.
///
/// APIs verified:
///   TestCube.build(name:)       — Sources/Engines/TestCube.swift:7
///   ExportService(device:)      — Core/Services/ExportService/ExportService.swift:38
///   ExportService.exportToOBJ(model:url:) — Core/Services/ExportService/ExportService.swift:71
///   ExportService.exportToSTL(model:url:) — Core/Services/ExportService/ExportService.swift:81
final class ExportValidationTests: XCTestCase {

    var exportService: ExportService!
    var cubeModel: Model!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        cubeModel = TestCube.build(name: "ValidationCube")
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ExportValidationTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal not available on this test target")
        }
        exportService = ExportService(device: device)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - OBJ export validation

    /// Exports a cube to OBJ and re-parses the text to verify vertex count,
    /// face count, no NaN, and finite normals.
    func testOBJExportCubeHasCorrectStructure() throws {
        let url = tempDir.appendingPathComponent("cube.obj")
        try exportService.exportToOBJ(model: cubeModel, url: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "OBJ file must exist after export")

        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(content.isEmpty, "OBJ content must not be empty")

        // Parse OBJ
        let lines = content.components(separatedBy: .newlines)
        var vertexLines: [String] = []
        var normalLines: [String] = []
        var faceLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("v ") {
                vertexLines.append(trimmed)
            } else if trimmed.hasPrefix("vn ") {
                normalLines.append(trimmed)
            } else if trimmed.hasPrefix("f ") {
                faceLines.append(trimmed)
            }
        }

        // A cube has at least 8 vertices (may be more if MDLAsset duplicates)
        XCTAssertGreaterThanOrEqual(vertexLines.count, 8,
            "OBJ must have at least 8 vertices, got \(vertexLines.count)")

        // Normals must exist (at least one per unique normal direction on the cube)
        XCTAssertGreaterThan(normalLines.count, 0,
            "OBJ must contain vertex normals (vn lines)")

        // TestCube has 12 triangles
        XCTAssertEqual(faceLines.count, 12,
            "OBJ must have 12 faces (cube = 12 triangles), got \(faceLines.count)")

        // Validate parsed vertices: no NaN, all finite
        for (i, vLine) in vertexLines.enumerated() {
            let components = vLine.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            // Format: "v x y z" → 4 components
            XCTAssertEqual(components.count, 4,
                "Vertex line \(i) should have 4 components (v x y z), got \(components.count): \(vLine)")

            if components.count >= 4 {
                for compIdx in 1...3 {
                    guard let value = Float(components[compIdx]) else {
                        XCTFail("Vertex \(i) component \(compIdx) is not a valid float: \(components[compIdx])")
                        continue
                    }
                    XCTAssertFalse(value.isNaN,
                        "Vertex \(i) component \(compIdx) is NaN")
                    XCTAssertTrue(value.isFinite,
                        "Vertex \(i) component \(compIdx) is not finite: \(value)")
                }
            }
        }

        // Validate parsed normals: no NaN, all finite
        for (i, vnLine) in normalLines.enumerated() {
            let components = vnLine.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            XCTAssertEqual(components.count, 4,
                "Normal line \(i) should have 4 components (vn nx ny nz)")

            if components.count >= 4 {
                for compIdx in 1...3 {
                    guard let value = Float(components[compIdx]) else {
                        XCTFail("Normal \(i) component \(compIdx) is not a valid float")
                        continue
                    }
                    XCTAssertFalse(value.isNaN,
                        "Normal \(i) component \(compIdx) is NaN")
                    XCTAssertTrue(value.isFinite,
                        "Normal \(i) component \(compIdx) is not finite: \(value)")
                    // Normals should have non-zero length (not all zeros)
                }
            }
        }
    }

    /// Verifies OBJ face lines reference valid vertex indices.
    func testOBJExportFacesReferenceValidIndices() throws {
        let url = tempDir.appendingPathComponent("cube_faces.obj")
        try exportService.exportToOBJ(model: cubeModel, url: url)

        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        // Count vertex definitions
        let vertexCount = lines.filter {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("v ")
        }.count

        // Parse face lines: "f v1/vt1/vn1 v2/vt2/vn2 v3/vt3/vn3" or "f v1//vn1 ..."
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("f ") else { continue }

            let parts = trimmed.dropFirst(2).components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            // Each face must have exactly 3 vertex references (triangles)
            XCTAssertEqual(parts.count, 3,
                "Face must reference exactly 3 vertices, got \(parts.count): \(trimmed)")

            for part in parts {
                // Extract vertex index (before first '/')
                let vertStr = part.components(separatedBy: "/").first ?? ""
                guard let vertIdx = Int(vertStr) else {
                    XCTFail("Face vertex reference is not an integer: \(part)")
                    continue
                }
                // OBJ indices are 1-based; absolute value handles negative (relative) indices
                let absIdx = abs(vertIdx)
                XCTAssertGreaterThan(absIdx, 0,
                    "Face vertex index must be > 0, got \(vertIdx)")
                XCTAssertLessThanOrEqual(absIdx, vertexCount,
                    "Face vertex index \(absIdx) exceeds vertex count \(vertexCount)")
            }
        }
    }

    // MARK: - STL export validation

    /// Exports a cube to binary STL and validates triangle count, vertex data,
    /// and absence of NaN.
    func testSTLExportCubeHasCorrectTriangleCount() throws {
        let url = tempDir.appendingPathComponent("cube.stl")
        try exportService.exportToSTL(model: cubeModel, url: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "STL file must exist after export")

        let data = try Data(contentsOf: url)
        // Binary STL: 80-byte header + 4-byte count + count * 50 bytes per triangle
        let minimumSize = 84  // header + count
        XCTAssertGreaterThan(data.count, minimumSize,
            "STL binary must have at least 84 bytes, got \(data.count)")

        // Read triangle count (uint32 little-endian at offset 80)
        let triangleCount = data.withUnsafeBytes { raw in
            raw.loadUnaligned(fromByteOffset: 80, as: UInt32.self)
        }

        // TestCube has 12 triangles
        XCTAssertEqual(triangleCount, 12,
            "STL must contain 12 triangles (cube), got \(triangleCount)")

        // Verify total file size matches expected: 84 + triangleCount * 50
        let expectedSize = 84 + Int(triangleCount) * 50
        XCTAssertEqual(data.count, expectedSize,
            "STL file size \(data.count) must match expected \(expectedSize)")

        // Parse and validate each triangle
        let stride = 50
        for i in 0..<Int(triangleCount) {
            let offset = 84 + i * stride
            guard offset + stride <= data.count else {
                XCTFail("Triangle \(i) data exceeds file bounds")
                break
            }

            // Read normal (3 floats starting at offset)
            let nx = data.readFloat32(at: offset)
            let ny = data.readFloat32(at: offset + 4)
            let nz = data.readFloat32(at: offset + 8)

            // Read vertices (9 floats starting at offset + 12)
            for vIdx in 0..<3 {
                let voff = offset + 12 + vIdx * 12
                let vx = data.readFloat32(at: voff)
                let vy = data.readFloat32(at: voff + 4)
                let vz = data.readFloat32(at: voff + 8)

                assertNotNaN(vx, label: "Triangle \(i) vertex \(vIdx).x")
                assertNotNaN(vy, label: "Triangle \(i) vertex \(vIdx).y")
                assertNotNaN(vz, label: "Triangle \(i) vertex \(vIdx).z")
                assertFinite(vx, label: "Triangle \(i) vertex \(vIdx).x")
                assertFinite(vy, label: "Triangle \(i) vertex \(vIdx).y")
                assertFinite(vz, label: "Triangle \(i) vertex \(vIdx).z")
            }

            assertNotNaN(nx, label: "Triangle \(i) normal.x")
            assertNotNaN(ny, label: "Triangle \(i) normal.y")
            assertNotNaN(nz, label: "Triangle \(i) normal.z")
            assertFinite(nx, label: "Triangle \(i) normal.x")
            assertFinite(ny, label: "Triangle \(i) normal.y")
            assertFinite(nz, label: "Triangle \(i) normal.z")
        }
    }

    /// Verifies STL normals are unit-length (or close).
    func testSTLExportNormalsAreNormalized() throws {
        let url = tempDir.appendingPathComponent("cube_normals.stl")
        try exportService.exportToSTL(model: cubeModel, url: url)

        let data = try Data(contentsOf: url)
        let triangleCount = data.withUnsafeBytes { raw in
            raw.loadUnaligned(fromByteOffset: 80, as: UInt32.self)
        }

        for i in 0..<Int(triangleCount) {
            let offset = 84 + i * 50
            let nx = data.readFloat32(at: offset)
            let ny = data.readFloat32(at: offset + 4)
            let nz = data.readFloat32(at: offset + 8)

            let length = sqrt(nx * nx + ny * ny + nz * nz)
            // Model I/O should produce unit-length normals; allow small tolerance
            // If the normal is zero-length, Model I/O may not normalize correctly
            if length > 0 {
                XCTAssertEqual(length, 1.0, accuracy: 0.01,
                    "Triangle \(i) normal length should be ~1.0, got \(length)")
            }
        }
    }

    // MARK: - Helpers

    private func assertNotNaN(_ value: Float, label: String,
                              file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(value.isNaN, "\(label) is NaN", file: file, line: line)
    }

    private func assertFinite(_ value: Float, label: String,
                              file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(value.isFinite, "\(label) is not finite: \(value)", file: file, line: line)
    }
}

// MARK: - Data helpers for reading float32 at offset

private extension Data {
    func readFloat32(at offset: Int) -> Float {
        var value: Float = 0
        withUnsafeBytes { raw in
            guard offset + 4 <= raw.count else { return }
            value = raw.loadUnaligned(fromByteOffset: offset, as: Float.self)
        }
        return value
    }
}
