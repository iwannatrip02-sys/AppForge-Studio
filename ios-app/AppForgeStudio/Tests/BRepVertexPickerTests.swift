import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Base "vértices/puntos reales": los puntos donde confluyen las aristas son
/// entidades reales, derivadas de los endpoints de las aristas (OCCTSwift @v1.8.8
/// no expone Shape.vertices()). Desbloquea selección de puntos, snap de medición
/// y mover sub-elementos.
final class BRepVertexPickerTests: XCTestCase {

    private func makeBox() throws -> CADShape {
        try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
    }

    func testBoxHasEightVertices() throws {
        let verts = BRepVertexPicker.vertices(of: try makeBox())
        XCTAssertEqual(verts.count, 8, "una caja B-rep tiene exactamente 8 vértices reales")
    }

    func testNearestVertexToCornerReturnsThatCorner() throws {
        let box = try makeBox()
        // Caja centrada en el origen ocupa [-1,1]³; esquina en (1,1,1).
        let idx = try XCTUnwrap(
            BRepVertexPicker.vertexIndex(of: box, nearest: SIMD3<Float>(0.97, 0.97, 0.97),
                                         maxDistance: 0.1),
            "un toque junto a la esquina debe resolver al vértice de esa esquina")
        let pos = try XCTUnwrap(BRepVertexPicker.position(of: box, vertexIndex: idx))
        XCTAssertEqual(pos.x, 1, accuracy: 0.01)
        XCTAssertEqual(pos.y, 1, accuracy: 0.01)
        XCTAssertEqual(pos.z, 1, accuracy: 0.01)
    }

    func testCenterTapMatchesNoVertex() throws {
        let box = try makeBox()
        XCTAssertNil(
            BRepVertexPicker.vertexIndex(of: box, nearest: SIMD3<Float>(0, 0, 0),
                                         maxDistance: 0.03),
            "el centro del sólido no está cerca de ningún vértice → sin selección de punto")
    }

    func testHighlightDotIsRenderableTriangleMesh() {
        let dot = BRepVertexPicker.highlightDot(at: SIMD3<Float>(1, 1, 1))
        XCTAssertEqual(dot.vertices.count, 6, "octaedro = 6 vértices")
        XCTAssertEqual(dot.indices.count, 24, "octaedro = 8 triángulos")
        XCTAssertEqual(dot.indices.count % 3, 0, "triángulos completos")
        // Centrado en el vértice: el promedio de posiciones ≈ (1,1,1).
        let sum = dot.vertices.reduce(SIMD3<Float>(0, 0, 0)) { $0 + $1.position }
        let avg = sum / Float(dot.vertices.count)
        XCTAssertEqual(avg.x, 1, accuracy: 1e-5)
        XCTAssertEqual(avg.y, 1, accuracy: 1e-5)
        XCTAssertEqual(avg.z, 1, accuracy: 1e-5)
    }
}
