import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Contrato de MEDIR: los números salen del B-rep y son exactos, o no salen.
///
/// Por qué existe (auditoría 2026-07-25): la barra de Medir mostraba
/// `Area: 0.00 mm²` y `Volumen: 0.000 mm³` FIJOS. Se calculaban en la rama
/// `.measure` de `ToolViewModel.executeTool`, que ya era inalcanzable — un
/// número falso en pantalla, que es peor que no mostrar nada.
@MainActor
final class MeasureServiceTests: XCTestCase {

    private func boxModel(_ w: Double, _ h: Double, _ d: Double) throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: w, height: h, depth: d))
        let model = Model(name: "Caja")
        model.cadShape = shape
        model.meshes = [try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))]
        return model
    }

    // MARK: - Cuerpo

    func testBodyMeasuresExactVolumeAndSurface() throws {
        let model = try boxModel(2, 3, 4)
        let m = try XCTUnwrap(MeasureService.measure(target: .body(modelIndex: 0),
                                                     in: [model]))
        XCTAssertEqual(try XCTUnwrap(m.volume), 24, accuracy: 1e-6,
                       "caja 2×3×4 → volumen 24 exacto")
        // Superficie = 2(2·3 + 2·4 + 3·4) = 2(6+8+12) = 52
        XCTAssertEqual(try XCTUnwrap(m.area), 52, accuracy: 1e-6,
                       "superficie total de la caja = 52")
        XCTAssertNil(m.length, "un cuerpo no reporta 'longitud'")
    }

    // MARK: - Cara

    func testFaceMeasuresItsOwnAreaNotTheWholeBody() throws {
        let model = try boxModel(2, 2, 2)
        let shape = try XCTUnwrap(model.cadShape)
        let areas = shape.measure().faceAreas
        // Todas las caras de un cubo 2×2×2 miden 4.
        XCTAssertEqual(areas.count, 6)

        let m = try XCTUnwrap(MeasureService.measure(target: .face(modelIndex: 0, faceIndex: 0),
                                                     in: [model]))
        XCTAssertEqual(try XCTUnwrap(m.area), 4, accuracy: 1e-6,
                       "una cara del cubo 2×2×2 mide 4, no los 24 de todo el cuerpo")
        XCTAssertNil(m.volume, "una cara no tiene volumen")
        // Perímetro de la cara: 4 lados de 2 = 8.
        XCTAssertEqual(try XCTUnwrap(m.length), 8, accuracy: 1e-6)
    }

    // MARK: - Arista

    func testEdgeMeasuresItsLength() throws {
        let model = try boxModel(2, 2, 2)
        let m = try XCTUnwrap(MeasureService.measure(target: .edge(modelIndex: 0, edgeIndex: 0),
                                                     in: [model]))
        XCTAssertEqual(try XCTUnwrap(m.length), 2, accuracy: 1e-6,
                       "toda arista del cubo 2×2×2 mide 2")
        XCTAssertNil(m.area, "una arista no tiene área")
        XCTAssertNil(m.volume, "una arista no tiene volumen")
    }

    // MARK: - Degradación honesta

    func testNilWhenModelHasNoBRep() {
        let mesh = Model(name: "Malla suelta")   // sin cadShape
        XCTAssertNil(MeasureService.measure(target: .body(modelIndex: 0), in: [mesh]),
                     "sin B-rep no hay medición de ingeniería: nil, no ceros")
    }

    func testNilWhenIndexOutOfRange() throws {
        let model = try boxModel(1, 1, 1)
        XCTAssertNil(MeasureService.measure(target: .face(modelIndex: 0, faceIndex: 99),
                                            in: [model]))
        XCTAssertNil(MeasureService.measure(target: .edge(modelIndex: 0, edgeIndex: 99),
                                            in: [model]))
        XCTAssertNil(MeasureService.measure(target: .body(modelIndex: 7), in: [model]))
    }

    // MARK: - Formato

    /// El readout NO inventa ceros: solo lista lo que aplica al objetivo.
    func testReadoutOnlyListsApplicableMagnitudes() throws {
        let model = try boxModel(2, 2, 2)
        let edge = try XCTUnwrap(MeasureService.measure(target: .edge(modelIndex: 0, edgeIndex: 0),
                                                        in: [model]))
        let lines = MeasureService.readout(edge)
        XCTAssertEqual(lines.count, 1, "una arista solo reporta longitud")
        XCTAssertTrue(lines[0].hasPrefix("Longitud:"))

        let body = try XCTUnwrap(MeasureService.measure(target: .body(modelIndex: 0),
                                                        in: [model]))
        let bodyLines = MeasureService.readout(body)
        XCTAssertEqual(bodyLines.count, 2, "un cuerpo reporta área y volumen, sin longitud")
    }
}
