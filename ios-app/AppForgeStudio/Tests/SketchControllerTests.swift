import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Tests de LA GRAN OLA: sketch en viewport → sólidos B-rep reales.
/// Oráculos de volumen exactos: el dibujo produce ingeniería, no dibujos.
@MainActor
final class SketchControllerTests: XCTestCase {

    private func volume(_ model: Model) throws -> Double {
        try XCTUnwrap(try XCTUnwrap(model.cadShape).volume)
    }

    func testRectangleByTwoTapsExtrudesExactVolume() throws {
        let s = SketchController()
        s.activeTool = .rectangle
        s.tap(at: SIMD2<Float>(0, 0))
        s.tap(at: SIMD2<Float>(2, 3))
        XCTAssertTrue(s.hasClosedProfile, "rectángulo = perfil cerrado")

        let model = try XCTUnwrap(s.extrudeProfile(height: 1.5))
        XCTAssertEqual(try volume(model), 2 * 3 * 1.5, accuracy: 0.01,
                       "extrusión del rect 2×3 alto 1.5 → volumen EXACTO 9.0")
        XCTAssertNotNil(model.edgesMesh, "el sólido nace con aristas visibles")
        XCTAssertFalse(model.meshes.first?.vertices.isEmpty ?? true)
    }

    func testCircleExtrudesToCylinderVolume() throws {
        let s = SketchController()
        s.activeTool = .circle
        s.tap(at: SIMD2<Float>(5, 0))       // centro
        s.tap(at: SIMD2<Float>(6, 0))       // radio 1
        let model = try XCTUnwrap(s.extrudeProfile(height: 2))
        XCTAssertEqual(try volume(model), Double.pi * 1 * 1 * 2, accuracy: 0.01,
                       "círculo r=1 extruido 2 → cilindro πr²h EXACTO")
    }

    func testLineChainClosesBySnapAndExtrudes() throws {
        let s = SketchController()
        s.activeTool = .line
        // Triángulo rectángulo 2×2: (0,0) (2,0) (0,2), cerrar tocando CERCA del primero
        s.tap(at: SIMD2<Float>(0, 0))
        s.tap(at: SIMD2<Float>(2, 0))
        s.tap(at: SIMD2<Float>(0, 2))
        s.tap(at: SIMD2<Float>(0.05, 0.05))   // dentro del snapRadius → CIERRA
        XCTAssertTrue(s.hasClosedProfile, "el tap sobre el primer punto cierra la cadena")

        let model = try XCTUnwrap(s.extrudeProfile(height: 1))
        XCTAssertEqual(try volume(model), 2.0, accuracy: 0.02,
                       "triángulo 2×2/2 = área 2, alto 1 → volumen 2")
    }

    func testRevolveRectangleMakesRing() throws {
        let s = SketchController()
        s.activeTool = .rectangle
        // Rect lejos del eje Z (x∈[2,3], z∈[0,1]) girado 360° alrededor de Z:
        // anillo (toro cuadrado): V = 2π·R̄·A = 2π·2.5·(1·1) ≈ 15.708 (Pappus)
        s.tap(at: SIMD2<Float>(2, 0))
        s.tap(at: SIMD2<Float>(3, 1))
        let model = try XCTUnwrap(s.revolveProfile())
        XCTAssertEqual(try volume(model), 2 * Double.pi * 2.5 * 1.0, accuracy: 0.05,
                       "teorema de Pappus: V = 2π·R̄·A")
    }

    func testUndoAndClear() {
        let s = SketchController()
        s.activeTool = .line
        s.tap(at: SIMD2<Float>(0, 0))
        s.tap(at: SIMD2<Float>(1, 0))
        s.undoLast()
        XCTAssertEqual(s.chain.count, 1)
        s.clear()
        XCTAssertTrue(s.chain.isEmpty)
        XCTAssertFalse(s.hasClosedProfile)
    }

    func testPencilDragDrawsRectangle() throws {
        let s = SketchController()
        s.activeTool = .rectangle
        s.pencilDragBegan(at: SIMD2<Float>(0, 0))
        s.pencilDragChanged(to: SIMD2<Float>(1, 1))
        s.pencilDragEnded(at: SIMD2<Float>(4, 5))
        XCTAssertTrue(s.hasClosedProfile, "el trazo de pencil produce el rectángulo")
        let model = try XCTUnwrap(s.extrudeProfile(height: 1))
        XCTAssertEqual(try volume(model), 4 * 5 * 1, accuracy: 0.02)
    }
}
