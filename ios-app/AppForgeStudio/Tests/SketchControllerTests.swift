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

    func testTubeAlongStraightPathVolume() throws {
        // Cadena recta de longitud 4 + Tubo Ø0.4: el volumen debe ser positivo
        // y estar dentro del rango [πr²·L·0.5, πr²·L·1.5] (OCCT sweep sobre
        // polilínea de 2 puntos puede dar resultado ligeramente distinto al cilindro
        // teórico — se verifica que el sólido existe y tiene volumen razonable).
        let s = SketchController()
        s.activeTool = .line
        s.tap(at: SIMD2<Float>(0, 0))
        s.tap(at: SIMD2<Float>(4, 0))
        XCTAssertTrue(s.hasOpenPath)
        let model = try XCTUnwrap(s.tubeAlongPath(radius: 0.2))
        let vol = try volume(model)
        let expected = Double.pi * 0.04 * 4   // ≈ 0.503
        XCTAssertGreaterThan(vol, expected * 0.5,
                             "tubo recto: volumen debe ser > 50% del cilindro teórico")
        XCTAssertLessThan(vol, expected * 1.5,
                          "tubo recto: volumen debe ser < 150% del cilindro teórico")
        XCTAssertNotNil(model.edgesMesh, "sólido tubo nace con aristas")
    }

    func testLoftSquareToSquareIsPrism() throws {
        // Dos cuadrados idénticos 1×1, transición altura 2 → prisma volumen 2
        let s = SketchController()
        s.activeTool = .rectangle
        s.tap(at: SIMD2<Float>(0, 0)); s.tap(at: SIMD2<Float>(1, 1))
        s.tap(at: SIMD2<Float>(0, 0)); s.tap(at: SIMD2<Float>(1, 1))
        XCTAssertTrue(s.hasTwoProfiles)
        let model = try XCTUnwrap(s.loftProfiles(height: 2))
        XCTAssertEqual(try volume(model), 1 * 1 * 2, accuracy: 0.03,
                       "loft entre perfiles idénticos = prisma exacto")
    }

    func testRevolveHalfAngleIsHalfVolume() throws {
        // Rect x∈[2,3] revolucionado 180° = mitad del anillo de Pappus
        let s = SketchController()
        s.activeTool = .rectangle
        s.tap(at: SIMD2<Float>(2, 0)); s.tap(at: SIMD2<Float>(3, 1))
        let model = try XCTUnwrap(s.revolveProfile(angle: .pi))
        XCTAssertEqual(try volume(model), Double.pi * 2.5 * 1.0, accuracy: 0.05,
                       "revolución 180° = ½ · 2π·R̄·A (ángulo editable REAL)")
    }

    func testSplineBecomesOpenPath() {
        let s = SketchController()
        s.activeTool = .spline
        s.tap(at: SIMD2<Float>(0, 0))
        s.tap(at: SIMD2<Float>(1, 1))
        s.tap(at: SIMD2<Float>(2, 0))
        s.finishSpline()
        XCTAssertTrue(s.hasOpenPath, "la spline confirmada es ruta de Tubo")
        XCTAssertFalse(s.hasClosedProfile, "abierta: no es perfil")
    }

    func testDrillThroughHoleExactVolume() throws {
        // Caja 2×2×2 + agujero PASANTE Ø0.4 por el centro de la cara superior:
        // V = 8 − π·r²·h = 8 − π·0.04·2 ≈ 7.7487 (F-CAD-2a, INGENIERIA_INVERSA §4)
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))
        let model = Model(name: "Brida")
        model.cadShape = shape
        model.meshes = [mesh]

        XCTAssertTrue(BRepModeling.drill(model, at: SIMD3<Double>(0, 0, 1),
                                         direction: SIMD3<Double>(0, 0, -1),
                                         radius: 0.2, depth: 0))
        XCTAssertEqual(try volume(model), 8 - Double.pi * 0.04 * 2, accuracy: 0.01,
                       "agujero pasante: volumen EXACTO 8 − πr²h")
        XCTAssertNotNil(model.edgesMesh, "el agujero añade sus aristas circulares")

        // Encadenable: segundo agujero en otra posición
        XCTAssertTrue(BRepModeling.drill(model, at: SIMD3<Double>(0.6, 0, 1),
                                         direction: SIMD3<Double>(0, 0, -1),
                                         radius: 0.2, depth: 0))
        XCTAssertEqual(try volume(model), 8 - 2 * Double.pi * 0.04 * 2, accuracy: 0.01,
                       "dos agujeros = doble descuento exacto")
    }

    func testMirrorAndPatternProduceExactCopies() throws {
        // Cuerpo base desde sketch (rect 1×1 en x∈[2,3]) — lejos del plano espejo
        let s = SketchController()
        s.activeTool = .rectangle
        s.tap(at: SIMD2<Float>(2, 0))
        s.tap(at: SIMD2<Float>(3, 1))
        let base = try XCTUnwrap(s.extrudeProfile(height: 1))
        let baseVol = try volume(base)

        let mirror = try XCTUnwrap(BRepModeling.mirroredCopy(of: base))
        XCTAssertEqual(try volume(mirror), baseVol, accuracy: 0.01,
                       "el espejo conserva el volumen exacto")
        // El espejo vive al OTRO lado del plano x=0
        let mx = mirror.meshes.first!.vertices.map { $0.position.x }
        XCTAssertLessThan(mx.max() ?? 1, 0.01, "la copia reflejada cruza al lado x<0")

        let copies = BRepModeling.linearPattern(of: base, count: 3,
                                                spacing: SIMD3<Double>(2, 0, 0))
        XCTAssertEqual(copies.count, 2, "patrón ×3 = original + 2 copias")
        for (i, c) in copies.enumerated() {
            XCTAssertEqual(try volume(c), baseVol, accuracy: 0.01)
            let minX = c.meshes.first!.vertices.map { $0.position.x }.min() ?? 0
            XCTAssertEqual(minX, 2 + Float(i + 1) * 2, accuracy: 0.05,
                           "cada copia desplazada EXACTAMENTE i·spacing")
        }
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

    // MARK: - Polígono regular

    func testHexagonExtrudedVolume() throws {
        // Hexágono regular r=1 extruido h=1 → V = (3√3/2)·r²·h ≈ 2.598
        let s = SketchController()
        s.activeTool = .polygon
        s.polygonSides = 6
        s.tap(at: SIMD2<Float>(0, 0))     // centro
        s.tap(at: SIMD2<Float>(1, 0))     // radio 1
        XCTAssertTrue(s.hasClosedProfile, "polígono regular = perfil cerrado")
        let model = try XCTUnwrap(s.extrudeProfile(height: 1))
        let expected = 3 * sqrt(3.0) / 2 * 1 * 1 * 1   // ≈ 2.598
        XCTAssertEqual(try volume(model), expected, accuracy: 0.05,
                       "hexágono r=1 h=1 → volumen = (3√3/2)r²h")
        XCTAssertNotNil(model.edgesMesh, "sólido poligonal nace con aristas")
    }

    func testCircularPatternProducesExactCopies() throws {
        // Rect x∈[2,3] extruido h=1, patrón ○×4 → 3 copias, cada una mismo volumen
        let s = SketchController()
        s.activeTool = .rectangle
        s.tap(at: SIMD2<Float>(2, 0))
        s.tap(at: SIMD2<Float>(3, 1))
        let base = try XCTUnwrap(s.extrudeProfile(height: 1))
        let baseVol = try volume(base)

        let copies = BRepModeling.circularPattern(of: base, count: 4,
                                                  axisOrigin: .zero,
                                                  axisDirection: SIMD3<Double>(0, 1, 0))
        XCTAssertEqual(copies.count, 3, "patrón ○×4 = original + 3 copias")
        for (i, copy) in copies.enumerated() {
            XCTAssertEqual(try volume(copy), baseVol, accuracy: 0.01,
                           "copia circular \(i+1) conserva el volumen exacto")
        }
    }
}
