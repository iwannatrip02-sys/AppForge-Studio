import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Reconocimiento de features desde el B-rep. El oráculo central (detección de
/// cajera) replica el test probado de OCCTSwift (box − box interior → >=1 pocket).
/// El resto verifica ausencia de falsos positivos y consistencia de los datos.
final class FeatureRecognitionTests: XCTestCase {

    private func makeModel(_ shape: OCCTSwift.Shape, name: String = "Feat") -> Model {
        let model = Model(name: name)
        model.cadShape = shape
        return model
    }

    // MARK: - Cajeras (oráculo probado)

    func testPocketedBoxDetectsPocket() throws {
        let box = try XCTUnwrap(OCCTSwift.Shape.box(width: 20, height: 20, depth: 20))
        let cutter = try XCTUnwrap(OCCTSwift.Shape.box(origin: SIMD3(5, 5, 10),
                                                       width: 10, height: 10, depth: 15))
        let pocketed = try XCTUnwrap(box.subtracting(cutter), "la resta booleana debe producir un sólido")

        let report = FeatureRecognitionService.analyze(pocketed)
        XCTAssertGreaterThanOrEqual(report.pockets.count, 1, "debe reconocer al menos una cajera")
        let pocket = try XCTUnwrap(report.pockets.first)
        XCTAssertGreaterThan(pocket.depth, 0, "la cajera tiene profundidad positiva")
        XCTAssertFalse(pocket.wallFaceIndices.isEmpty, "una cajera tiene paredes")
        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.summary.contains("cajera"), "el resumen menciona la cajera")
    }

    // MARK: - Ausencia de falsos positivos

    func testPlainBoxHasNoHoles() throws {
        // Una caja solo tiene caras planas: no hay agujeros cilíndricos que reconocer.
        let box = try XCTUnwrap(OCCTSwift.Shape.box(width: 10, height: 10, depth: 10))
        let report = FeatureRecognitionService.analyze(box)
        XCTAssertTrue(report.holes.isEmpty, "una caja no tiene agujeros cilíndricos")
    }

    // MARK: - Consistencia de datos

    func testDetectedFeaturesAreInternallyConsistent() throws {
        let box = try XCTUnwrap(OCCTSwift.Shape.box(width: 20, height: 20, depth: 20))
        let cutter = try XCTUnwrap(OCCTSwift.Shape.box(origin: SIMD3(5, 5, 10),
                                                       width: 10, height: 10, depth: 15))
        let report = FeatureRecognitionService.analyze(try XCTUnwrap(box.subtracting(cutter)))
        // Sea cual sea el conteo, los valores geométricos deben ser sanos.
        for hole in report.holes {
            XCTAssertGreaterThan(hole.radius, 0)
            XCTAssertEqual(hole.diameter, hole.radius * 2, accuracy: 1e-12)
        }
        for pocket in report.pockets {
            XCTAssertGreaterThan(pocket.depth, 0)
            XCTAssertGreaterThanOrEqual(pocket.floorFaceIndex, 0)
        }
    }

    // MARK: - Sin B-rep

    func testModelWithoutBRepReturnsNil() {
        let model = Model(name: "SoloMalla")   // sin cadShape
        XCTAssertNil(FeatureRecognitionService.analyze(model),
                     "un modelo solo-malla no tiene features que reconocer")
    }
}
