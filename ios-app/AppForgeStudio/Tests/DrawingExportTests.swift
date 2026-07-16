import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Export de planos 2D (DXF) desde el B-rep: la proyección de un sólido debe
/// producir un DXF R12 válido con las aristas visibles en su capa. Oráculos
/// estructurales (markers DXF reales del writer de OCCTSwift) + geométricos.
final class DrawingExportTests: XCTestCase {

    private func makeBoxModel() throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let model = Model(name: "DrawBox")
        model.cadShape = shape
        return model
    }

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("dxf_\(UUID().uuidString)")
            .appendingPathExtension("dxf")
    }

    func testFrontViewDXFIsValidWithVisibleEdges() throws {
        let model = try makeBoxModel()
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(DrawingExportService.exportDXF(model, view: .front, to: url),
                      "el export DXF de la vista frontal debe tener éxito")

        let dxf = try String(contentsOf: url, encoding: .utf8)
        // Estructura DXF R12 (markers reales que emite DXFWriter de OCCTSwift)
        XCTAssertTrue(dxf.contains("SECTION"), "DXF válido tiene secciones")
        XCTAssertTrue(dxf.contains("ENTITIES"), "DXF tiene la sección ENTITIES")
        XCTAssertTrue(dxf.contains("EOF"), "DXF termina con EOF")
        // La vista de una caja = un rectángulo → aristas en la capa VISIBLE
        XCTAssertTrue(dxf.contains("VISIBLE"),
                      "las aristas proyectadas visibles van en la capa VISIBLE")
        XCTAssertTrue(dxf.contains("LINE"),
                      "el contorno rectangular produce entidades LINE/LWPOLYLINE")
        XCTAssertGreaterThan(dxf.count, 100, "un DXF con geometría no es trivialmente pequeño")
    }

    func testFrontViewPDFIsValidPrintablePlano() throws {
        let model = try makeBoxModel()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf_\(UUID().uuidString)").appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(DrawingExportService.exportPDF(model, view: .front, page: .a4Landscape, to: url),
                      "el export PDF de la vista frontal debe tener éxito")
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 100, "un PDF con geometría no es trivialmente pequeño")
        // Magic bytes de PDF: "%PDF"
        let magic = data.prefix(4)
        XCTAssertEqual(magic, Data("%PDF".utf8), "el archivo debe ser un PDF válido")
    }

    func testAllStandardViewsProjectTheBox() throws {
        let model = try makeBoxModel()
        let shape = try XCTUnwrap(model.cadShape)
        for view in DrawingExportService.StandardView.allCases {
            XCTAssertNotNil(DrawingExportService.drawing(of: shape, view: view),
                            "la vista \(view.rawValue) debe proyectar la caja")
        }
    }

    func testModelWithoutBRepFailsGracefully() throws {
        let model = Model(name: "NoBRep")   // sin cadShape
        let url = tempURL()
        XCTAssertFalse(DrawingExportService.exportDXF(model, view: .top, to: url),
                       "un modelo sin B-rep no puede exportar DXF")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                       "no debe crearse archivo cuando la operación falla")
    }
}
