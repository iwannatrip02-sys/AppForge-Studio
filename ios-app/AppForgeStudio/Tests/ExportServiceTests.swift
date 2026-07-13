import XCTest
import OCCTSwift
@testable import AppForgeStudio

final class ExportServiceTests: XCTestCase {
    var exportService: ExportService!
    var testModel: Model!
    var tempDir: URL!
    
    override func setUp() {
        super.setUp()
        testModel = TestCube.build(name: "TestCube")
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let mockDevice = MTLCreateSystemDefaultDevice()!
        exportService = ExportService(device: mockDevice)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }
    
    func testExportToOBJ() throws {
        let url = tempDir.appendingPathComponent("test.obj")
        try exportService.exportToOBJ(model: testModel, url: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0)
    }
    
    func testExportToSTL() throws {
        let url = tempDir.appendingPathComponent("test.stl")
        try exportService.exportToSTL(model: testModel, url: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0)
    }
    
    func testExportToUSDZ() throws {
        let url = tempDir.appendingPathComponent("test.usdz")
        try exportService.exportToUSDZ(model: testModel, url: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0)
    }
    
    func testExportToSTEPWithoutBRepThrowsHonestError() {
        // Contrato nuevo (2026-07-13): sin B-rep NO hay STEP falso. El generador
        // anterior escribía un pseudo-STEP (POLYLOOP a mano) que ningún CAD
        // abría como sólido — placebo retirado.
        let url = tempDir.appendingPathComponent("test.step")
        XCTAssertThrowsError(try exportService.exportToSTEP(model: testModel, url: url),
                             "malla sin B-rep debe fallar honesto, no escribir basura")
    }

    func testExportToSTEPWithBRepWritesRealAP214() throws {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))
        let brepModel = Model(name: "BrepCube")
        brepModel.cadShape = shape
        brepModel.meshes = [mesh]

        let url = tempDir.appendingPathComponent("real.step")
        try exportService.exportToSTEP(model: brepModel, url: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("ISO-10303-21"), "cabecera STEP estándar")
        XCTAssertFalse(content.contains("POLYLOOP"),
                       "sin rastro del pseudo-STEP triangulado")
        XCTAssertGreaterThan(content.count, 1000,
                             "un AP214 real de un sólido tiene entidades B-rep")
    }
    
    func testExportToGLTF() throws {
        let url = tempDir.appendingPathComponent("test.gltf")
        try exportService.exportToGLTF(model: testModel, url: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("2.0"))
        XCTAssertTrue(content.contains("AppForgeStudio"))
    }
    
    func testExportEmptyModelThrows() {
        let emptyModel = Model(name: "Empty")
        let url = tempDir.appendingPathComponent("empty.obj")
        XCTAssertThrowsError(try exportService.exportToOBJ(model: emptyModel, url: url))
    }

    // MARK: - GLTF buffer + JSON coherence (oráculo de contenido)

    /// Exporta un box (TestCube = cubo unitario) a GLTF y valida tres invariantes:
    ///   1. El JSON parsa correctamente vía JSONSerialization.
    ///   2. El archivo binario .bin referenciado existe en disco.
    ///   3. byteLength declarado en el JSON coincide con el archivo .bin
    ///      y es ≥ vertices × 12 bytes (sólo posiciones float3 bastan como piso mínimo).
    ///
    /// Esto detecta la regresión descrita en TODO.md ("escribe JSON pero nunca escribe el
    /// buffer .bin") y evita que vuelva a aparecer silenciosamente.
    func testGLTFExportJsonParsesAndBufferIsCoherent() throws {
        let gltfURL = tempDir.appendingPathComponent("box.gltf")
        try exportService.exportToGLTF(model: testModel, url: gltfURL)

        // 1 — El archivo GLTF existe
        XCTAssertTrue(FileManager.default.fileExists(atPath: gltfURL.path),
                      "Archivo GLTF debe existir tras la exportación")

        // 2 — El JSON parsa como diccionario raíz válido
        let jsonData = try Data(contentsOf: gltfURL)
        let parsed = try JSONSerialization.jsonObject(with: jsonData, options: [])
        guard let root = parsed as? [String: Any] else {
            XCTFail("El JSON GLTF no es un objeto raíz válido ([String: Any])")
            return
        }

        // 2a — Versión del asset = "2.0"
        let asset = root["asset"] as? [String: Any]
        XCTAssertEqual(asset?["version"] as? String, "2.0",
                       "GLTF debe declarar version '2.0' en el campo asset")

        // 3 — buffers[0] tiene byteLength > 0 y referencia un .bin
        guard let buffers = root["buffers"] as? [[String: Any]],
              let firstBuffer = buffers.first,
              let byteLength = firstBuffer["byteLength"] as? Int else {
            XCTFail("GLTF debe tener al menos un buffer con byteLength declarado")
            return
        }
        XCTAssertGreaterThan(byteLength, 0, "byteLength del buffer debe ser > 0")

        guard let binURI = firstBuffer["uri"] as? String else {
            XCTFail("El buffer GLTF debe tener campo 'uri' con nombre del archivo .bin")
            return
        }

        // 4 — El archivo .bin debe existir en disco
        let binURL = gltfURL.deletingLastPathComponent().appendingPathComponent(binURI)
        XCTAssertTrue(FileManager.default.fileExists(atPath: binURL.path),
                      "Archivo .bin debe existir en \(binURL.path) — la malla nunca fue escrita")

        // 5 — Tamaño real del .bin coincide con byteLength declarado en el JSON
        let binData = try Data(contentsOf: binURL)
        XCTAssertEqual(binData.count, byteLength,
                       "Tamaño real del .bin (\(binData.count)) debe coincidir con byteLength " +
                       "declarado en el JSON (\(byteLength))")

        // 6 — Coherencia con la malla: el buffer debe contener al menos
        //     vertices × 12 bytes (posiciones float3, el campo más pequeño)
        guard let mesh = testModel.meshes.first else {
            XCTFail("testModel debe tener al menos una malla")
            return
        }
        let minPositionBytes = mesh.vertices.count * MemoryLayout<Float>.size * 3 // float3 = 12 B
        XCTAssertGreaterThanOrEqual(binData.count, minPositionBytes,
            "Buffer de \(binData.count) bytes debe ser ≥ \(minPositionBytes) bytes " +
            "(\(mesh.vertices.count) vértices × 12 bytes de posición)")
    }
}
