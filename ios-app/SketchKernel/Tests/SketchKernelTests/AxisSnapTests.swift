import XCTest
@testable import SketchKernel

/// Commit H/V definitivo (<10°) — la regla de Dune3D que endereza las líneas
/// "casi" rectas reportadas en device.
final class AxisSnapTests: XCTestCase {

    /// (0,0)→(3, 0.4) ≈ 7.6° de la horizontal → se endereza a horizontal exacta.
    func testNearHorizontalSnaps() {
        let end = AxisSnap.commit(endpoint: Vec2(3, 0.4), reference: Vec2(0, 0))
        XCTAssertEqual(end.y, 0, accuracy: 1e-12, "y forzada a la horizontal")
        XCTAssertEqual(end.x, 3, accuracy: 1e-12, "x preservada")
    }

    /// (0,0)→(3, 0.8) ≈ 15° → fuera del umbral, NO se ajusta.
    func testBeyondThresholdUnchanged() {
        let end = AxisSnap.commit(endpoint: Vec2(3, 0.8), reference: Vec2(0, 0))
        XCTAssertEqual(end.x, 3, accuracy: 1e-12)
        XCTAssertEqual(end.y, 0.8, accuracy: 1e-12, "queda como está: 15° no se endereza")
    }

    /// Casi vertical: (0,0)→(0.3, 4) ≈ 4.3° de la vertical → x forzada.
    func testNearVerticalSnaps() {
        let end = AxisSnap.commit(endpoint: Vec2(0.3, 4), reference: Vec2(0, 0))
        XCTAssertEqual(end.x, 0, accuracy: 1e-12, "x forzada a la vertical")
        XCTAssertEqual(end.y, 4, accuracy: 1e-12)
    }

    /// Referencia distinta del origen: el eje pasa por la referencia, no por (0,0).
    func testAxisPassesThroughReference() {
        let end = AxisSnap.commit(endpoint: Vec2(8, 5.3), reference: Vec2(5, 5))
        XCTAssertEqual(end.y, 5, accuracy: 1e-12, "horizontal a la altura de la referencia")
        XCTAssertEqual(end.x, 8, accuracy: 1e-12)
    }

    /// Diagonal a 45°: equidistante de ambos ejes, no se ajusta.
    func testDiagonalUnchanged() {
        let end = AxisSnap.commit(endpoint: Vec2(3, 3), reference: Vec2(0, 0))
        XCTAssertEqual(end.x, 3, accuracy: 1e-12)
        XCTAssertEqual(end.y, 3, accuracy: 1e-12)
    }

    /// allowAdjust=false (hubo snap duro): la posición intencional se respeta.
    func testHardSnapNotAdjusted() {
        let end = AxisSnap.commit(endpoint: Vec2(3, 0.4), reference: Vec2(0, 0),
                                  allowAdjust: false)
        XCTAssertEqual(end.y, 0.4, accuracy: 1e-12, "snap duro no se endereza")
    }
}
