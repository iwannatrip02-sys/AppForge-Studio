import XCTest
import OCCTSwift
@testable import AppForgeStudio

/// Tests de `DrawingExportController`: separa la lógica del controlador de la vista.
/// Crea un modelo con B-rep real (OCCT) para verificar que el archivo se genera
/// correctamente y que el estado observable queda consistente en cada rama.
@MainActor
final class DrawingExportControllerTests: XCTestCase {

    // MARK: - Helpers

    private func makeBoxModel() throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2),
                                  "box centrado 2×2×2 debe crearse")
        let model = Model(name: "CtrlBox")
        model.cadShape = shape
        return model
    }

    // MARK: - DXF

    func testExportDXFSucceedsForBRepModel() throws {
        let controller = DrawingExportController()
        let model = try makeBoxModel()
        controller.selectedView = .front

        let ok = controller.exportDXF(model: model)

        XCTAssertTrue(ok, "exportDXF debe tener éxito con un modelo con B-rep")
        XCTAssertNotNil(controller.exportURL, "exportURL no debe ser nil tras exportación exitosa")
        XCTAssertTrue(controller.statusMessage.contains("DXF"),
                      "el mensaje de éxito debe mencionar DXF")
        XCTAssertFalse(controller.isBusy, "isBusy debe ser false al terminar")

        // Limpiar archivo temporal
        if let url = controller.exportURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func testExportDXFWritesActualFile() throws {
        let controller = DrawingExportController()
        let model = try makeBoxModel()
        controller.selectedView = .top

        _ = controller.exportDXF(model: model)

        let url = try XCTUnwrap(controller.exportURL, "debe haber una URL de export")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "el archivo DXF debe existir en disco")
        defer { try? FileManager.default.removeItem(at: url) }

        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("SECTION"), "el DXF exportado tiene estructura DXF válida")
    }

    // MARK: - PDF

    func testExportPDFSucceedsForBRepModel() throws {
        let controller = DrawingExportController()
        let model = try makeBoxModel()
        controller.selectedView = .top

        let ok = controller.exportPDF(model: model)

        XCTAssertTrue(ok, "exportPDF debe tener éxito con un modelo con B-rep")
        XCTAssertNotNil(controller.exportURL, "exportURL no debe ser nil tras exportación PDF exitosa")
        XCTAssertTrue(controller.statusMessage.contains("PDF"),
                      "el mensaje de éxito debe mencionar PDF")

        if let url = controller.exportURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func testExportPDFWritesValidPDFBytes() throws {
        let controller = DrawingExportController()
        let model = try makeBoxModel()
        controller.selectedView = .front

        _ = controller.exportPDF(model: model)

        let url = try XCTUnwrap(controller.exportURL)
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 100, "el PDF generado no debe estar vacío")
        let magic = data.prefix(4)
        XCTAssertEqual(magic, Data("%PDF".utf8), "magic bytes correctos de PDF")
    }

    // MARK: - Sin B-rep

    func testExportFailsWithoutBRep() {
        let controller = DrawingExportController()
        let model = Model(name: "SoloMalla")  // sin cadShape

        let ok = controller.exportDXF(model: model)

        XCTAssertFalse(ok, "un modelo sin B-rep no puede exportar plano")
        XCTAssertNil(controller.exportURL, "exportURL debe ser nil cuando falla la exportación")
        XCTAssertTrue(controller.statusMessage.contains("B-rep"),
                      "el mensaje debe mencionar la ausencia de B-rep")
        XCTAssertFalse(controller.isBusy, "isBusy debe ser false aunque haya fallado")
    }

    func testExportPDFFailsWithoutBRep() {
        let controller = DrawingExportController()
        let model = Model(name: "SoloMalla")

        let ok = controller.exportPDF(model: model)

        XCTAssertFalse(ok)
        XCTAssertNil(controller.exportURL)
        XCTAssertTrue(controller.statusMessage.contains("B-rep"))
    }

    // MARK: - Vista seleccionada en el nombre del archivo

    func testViewSelectionReflectedInOutputFilename() throws {
        let controller = DrawingExportController()
        let model = try makeBoxModel()
        controller.selectedView = .side

        _ = controller.exportDXF(model: model)

        let url = try XCTUnwrap(controller.exportURL)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(url.lastPathComponent.contains("side"),
                      "el nombre del archivo debe reflejar la vista seleccionada")
    }

    // MARK: - Reset

    func testResetClearsAllState() throws {
        let controller = DrawingExportController()
        let model = try makeBoxModel()
        _ = controller.exportDXF(model: model)
        if let url = controller.exportURL { try? FileManager.default.removeItem(at: url) }

        controller.reset()

        XCTAssertNil(controller.exportURL, "reset() debe limpiar exportURL")
        XCTAssertFalse(controller.isBusy, "reset() debe dejar isBusy en false")
        XCTAssertFalse(controller.statusMessage.contains("listo"),
                       "reset() debe borrar el mensaje de éxito anterior")
    }

    // MARK: - Múltiples vistas

    func testAllStandardViewsExportSuccessfully() throws {
        let controller = DrawingExportController()
        let model = try makeBoxModel()

        for view in DrawingExportService.StandardView.allCases {
            controller.selectedView = view
            let ok = controller.exportDXF(model: model)
            XCTAssertTrue(ok, "la vista \(view.rawValue) debe exportar correctamente")
            if let url = controller.exportURL { try? FileManager.default.removeItem(at: url) }
        }
    }
}
