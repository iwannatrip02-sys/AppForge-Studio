import XCTest
@testable import SketchKernel

/// Contrato del OFFSET 2D: contorno paralelo EXACTO, con esquinas en inglete.
///
/// No es una aproximación: cada recta desplazada es una recta paralela y las
/// esquinas salen de intersectar las desplazadas consecutivas. Por eso la
/// distancia real se mantiene en TODOS los tramos — que es lo que se necesita
/// para paredes, holguras y contornos de mecanizado.
final class OffsetTests: XCTestCase {

    /// Cadena abierta en "L": (0,0) → (10,0) → (10,10).
    private func lShape() -> (model: SketchModel, ids: [CurveID]) {
        var m = SketchModel(mergeTolerance: 1e-9)
        let a = m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        let b = m.addLine(from: Vec2(10, 0), to: Vec2(10, 10))
        return (m, [a, b])
    }

    // MARK: - Exactitud

    /// La esquina del offset es la INTERSECCIÓN de las dos paralelas, no el
    /// desplazamiento del vértice original. Con d=2 hacia dentro de la "L",
    /// la esquina cae exactamente en (8,2).
    func testOpenChainCornerIsTheMiter() throws {
        var (m, ids) = lShape()
        // Recorrido (0,0)→(10,0)→(10,10): la izquierda apunta hacia +Y / −X.
        let made = try XCTUnwrap(m.offsetLineChain(ids, distance: 2))
        XCTAssertEqual(made.count, 2, "dos tramos entran, dos salen")

        // Vértices del contorno nuevo, en orden.
        guard case .line(let s0, let e0)? = m.curves[made[0]]?.kind,
              case .line(_, let e1)? = m.curves[made[1]]?.kind else {
            return XCTFail("el offset produce líneas")
        }
        let p0 = try XCTUnwrap(m.position(of: s0))
        let corner = try XCTUnwrap(m.position(of: e0))
        let p2 = try XCTUnwrap(m.position(of: e1))

        XCTAssertEqual(p0.x, 0, accuracy: 1e-9)
        XCTAssertEqual(p0.y, 2, accuracy: 1e-9)
        XCTAssertEqual(corner.x, 8, accuracy: 1e-9, "la esquina es el inglete, no (10,2)")
        XCTAssertEqual(corner.y, 2, accuracy: 1e-9)
        XCTAssertEqual(p2.x, 8, accuracy: 1e-9)
        XCTAssertEqual(p2.y, 10, accuracy: 1e-9)
    }

    /// Signo negativo = el otro lado.
    func testNegativeDistanceOffsetsToTheOtherSide() throws {
        var (m, ids) = lShape()
        let made = try XCTUnwrap(m.offsetLineChain(ids, distance: -2))
        guard case .line(let s0, _)? = m.curves[made[0]]?.kind else {
            return XCTFail("el offset produce líneas")
        }
        let p0 = try XCTUnwrap(m.position(of: s0))
        XCTAssertEqual(p0.y, -2, accuracy: 1e-9, "distancia negativa = lado opuesto")
    }

    // MARK: - Bucle cerrado

    /// Un cuadrado 10×10 desplazado 2 hacia dentro debe dar un cuadrado 6×6
    /// (área 36) — TODOS sus vértices resueltos por inglete, incluido el que
    /// cierra el bucle.
    func testClosedSquareShrinksExactly() throws {
        var m = SketchModel(mergeTolerance: 1e-9)
        // Recorrido CCW: la izquierda apunta hacia DENTRO.
        let ids = [
            m.addLine(from: Vec2(0, 0), to: Vec2(10, 0)),
            m.addLine(from: Vec2(10, 0), to: Vec2(10, 10)),
            m.addLine(from: Vec2(10, 10), to: Vec2(0, 10)),
            m.addLine(from: Vec2(0, 10), to: Vec2(0, 0)),
        ]
        let made = try XCTUnwrap(m.offsetLineChain(ids, distance: 2))
        XCTAssertEqual(made.count, 4, "cuatro lados entran, cuatro salen")

        // El contorno nuevo encierra su propia región de 6×6.
        let areas = RegionFinder.regions(in: m).map { $0.area }.sorted()
        XCTAssertTrue(areas.contains { abs($0 - 36) < 1e-6 },
                      "el contorno desplazado encierra 6×6 = 36; áreas: \(areas)")
    }

    // MARK: - Rechazos honestos

    func testRejectsChainWithArcs() throws {
        var m = SketchModel(mergeTolerance: 1e-9)
        let line = m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        let arc = m.addArc(center: Vec2(10, 5), start: Vec2(10, 0),
                           end: Vec2(10, 10), ccw: true)
        XCTAssertNil(m.offsetLineChain([line, arc], distance: 1),
                     "v1 no aproxima arcos: los rechaza y lo dice")
    }

    func testRejectsDisconnectedCurves() {
        var m = SketchModel(mergeTolerance: 1e-9)
        let a = m.addLine(from: Vec2(0, 0), to: Vec2(1, 0))
        let b = m.addLine(from: Vec2(5, 5), to: Vec2(6, 5))   // suelta
        XCTAssertNil(m.offsetLineChain([a, b], distance: 1),
                     "dos trozos sueltos no son UNA cadena")
    }

    func testRejectsBranchingChain() {
        var m = SketchModel(mergeTolerance: 1e-9)
        // Tres líneas saliendo del mismo punto: grado 3, no es cadena simple.
        let a = m.addLine(from: Vec2(0, 0), to: Vec2(1, 0))
        let b = m.addLine(from: Vec2(0, 0), to: Vec2(0, 1))
        let c = m.addLine(from: Vec2(0, 0), to: Vec2(-1, 0))
        XCTAssertNil(m.offsetLineChain([a, b, c], distance: 0.2),
                     "una bifurcación no tiene contorno paralelo único")
    }

    func testRejectsZeroDistanceAndEmptyInput() {
        var (m, ids) = lShape()
        XCTAssertNil(m.offsetLineChain(ids, distance: 0),
                     "un offset de 0 no crea geometría")
        XCTAssertNil(m.offsetLineChain([], distance: 1))
    }

    /// Dos tramos colineales no forman esquina: sus paralelas nunca se cortan.
    func testRejectsCollinearChain() {
        var m = SketchModel(mergeTolerance: 1e-9)
        let a = m.addLine(from: Vec2(0, 0), to: Vec2(5, 0))
        let b = m.addLine(from: Vec2(5, 0), to: Vec2(10, 0))
        XCTAssertNil(m.offsetLineChain([a, b], distance: 1),
                     "paralelas que no se cortan no dan inglete")
    }
}
