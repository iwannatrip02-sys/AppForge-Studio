import XCTest
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
    
    func testExportToSTEP() throws {
        let url = tempDir.appendingPathComponent("test.step")
        try exportService.exportToSTEP(model: testModel, url: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("ISO-10303-21"))
        XCTAssertTrue(content.contains("CARTESIAN_POINT"))
        XCTAssertTrue(content.contains("POLYLOOP"))
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
}
