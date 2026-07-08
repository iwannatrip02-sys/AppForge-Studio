import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Tests de `FeatureReportController`: verifica el flujo completo de análisis AAG
/// (agujeros y cajeras) usando B-reps reales de OCCTSwift.
/// Imita el patrón de `PushPullControllerTests` y `FeatureRecognitionTests`.
@MainActor
final class FeatureReportControllerTests: XCTestCase {

    // MARK: - Helpers

    private func makePlainBox() throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 10, height: 10, depth: 10),
                                  "caja 10×10×10 debe crearse")
        let model = Model(name: "PlainBox")
        model.cadShape = shape
        return model
    }

    /// Cajera clásica: caja grande menos caja interior (no pasante = pocket cerrada).
    private func makePocketedBox() throws -> Model {
        let box = try XCTUnwrap(OCCTSwift.Shape.box(width: 20, height: 20, depth: 20))
        let cutter = try XCTUnwrap(
            OCCTSwift.Shape.box(origin: SIMD3(5, 5, 10), width: 10, height: 10, depth: 15))
        let pocketed = try XCTUnwrap(box.subtracting(cutter),
                                     "la resta booleana debe producir un sólido válido")
        let model = Model(name: "PocketBox")
        model.cadShape = pocketed
        return model
    }

    // MARK: - Estado inicial

    func testInitialStatusIsDescriptive() {
        let controller = FeatureReportController()
        XCTAssertNil(controller.report, "sin análisis el reporte debe ser nil")
        XCTAssertFalse(controller.statusMessage.isEmpty,
                       "el mensaje inicial no debe estar vacío")
        XCTAssertFalse(controller.isBusy)
    }

    // MARK: - Caja sin features

    func testPlainBoxHasNoHoles() throws {
        let controller = FeatureReportController()
        let model = try makePlainBox()

        controller.analyze(model: model)

        let report = try XCTUnwrap(controller.report,
                                   "el análisis de una caja debe producir un reporte")
        XCTAssertTrue(report.holes.isEmpty,
                      "una caja sin agujeros cilíndricos no debe reportar holes")
        XCTAssertFalse(controller.isBusy, "isBusy debe ser false al terminar")
    }

    // MARK: - Cajera

    func testPocketedBoxDetectsPocket() throws {
        let controller = FeatureReportController()
        let model = try makePocketedBox()

        controller.analyze(model: model)

        let report = try XCTUnwrap(controller.report)
        XCTAssertGreaterThanOrEqual(report.pockets.count, 1,
                                    "debe detectar al menos una cajera")
        XCTAssertTrue(controller.statusMessage.contains("cajera"),
                      "el mensaje debe mencionar la cajera detectada")
        XCTAssertFalse(controller.isBusy)
    }

    func testPocketedBoxPocketHasPositiveDepth() throws {
        let controller = FeatureReportController()
        let model = try makePocketedBox()
        controller.analyze(model: model)

        let report = try XCTUnwrap(controller.report)
        let pocket = try XCTUnwrap(report.pockets.first)
        XCTAssertGreaterThan(pocket.depth, 0, "la cajera debe tener profundidad positiva")
    }

    // MARK: - Sin B-rep

    func testAnalyzeWithoutBRepSetsMessageAndNilReport() {
        let controller = FeatureReportController()
        let model = Model(name: "SoloMalla")  // sin cadShape

        controller.analyze(model: model)

        XCTAssertNil(controller.report, "sin B-rep el reporte debe ser nil")
        XCTAssertTrue(controller.statusMessage.contains("B-rep"),
                      "el mensaje debe explicar la ausencia de B-rep")
        XCTAssertFalse(controller.isBusy)
    }

    // MARK: - Reset

    func testResetClearsReport() throws {
        let controller = FeatureReportController()
        let model = try makePlainBox()
        controller.analyze(model: model)
        XCTAssertNotNil(controller.report)

        controller.reset()

        XCTAssertNil(controller.report, "reset() debe limpiar el reporte")
        XCTAssertFalse(controller.isBusy, "reset() debe dejar isBusy en false")
    }

    func testResetRestoresDefaultMessage() throws {
        let controller = FeatureReportController()
        let model = try makePocketedBox()
        controller.analyze(model: model)

        controller.reset()

        XCTAssertFalse(controller.statusMessage.contains("cajera"),
                       "reset() debe borrar el resumen del análisis anterior")
    }

    // MARK: - Consistencia de datos

    func testDetectedFeaturesAreGeometricallyConsistent() throws {
        let controller = FeatureReportController()
        let model = try makePocketedBox()
        controller.analyze(model: model)

        let report = try XCTUnwrap(controller.report)
        for hole in report.holes {
            XCTAssertGreaterThan(hole.radius, 0)
            XCTAssertEqual(hole.diameter, hole.radius * 2, accuracy: 1e-12)
        }
        for pocket in report.pockets {
            XCTAssertGreaterThan(pocket.depth, 0)
            XCTAssertGreaterThanOrEqual(pocket.floorFaceIndex, 0)
        }
    }

    // MARK: - Summary

    func testSummaryMatchesReportContent() throws {
        let controller = FeatureReportController()
        let model = try makePocketedBox()
        controller.analyze(model: model)

        let report = try XCTUnwrap(controller.report)
        // El summary del reporte y el statusMessage del controller deben coincidir
        XCTAssertEqual(controller.statusMessage, report.summary,
                       "statusMessage debe reflejar el summary del reporte")
    }
}
