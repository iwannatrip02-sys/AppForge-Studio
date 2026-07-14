import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Tests del CONTRATO puro (Agente 2 → Agente 1): `activeRegionProfile()` y
/// `extrudedShapeForActiveRegion(distance:)` sobre `SketchController`.
///
/// Oráculos de VOLUMEN/ÁREA exactos (patrón de `BRepModelingTests`): solo un
/// kernel B-rep real puede satisfacerlos — una malla vacía (el no-op que
/// colapsamos) los reprueba de inmediato.
///
/// Plano por defecto = piso: u=(1,0,0), v=(0,0,1), normal=(0,1,0), ortonormal
/// → un rect 2D W×H mapea a un rect 3D W×H y se extruye W·H·D a lo largo de +Y.
@MainActor
final class SketchRegionExtrudeTests: XCTestCase {

    /// Dibuja un rectángulo cerrado W×H (dos taps) en un SketchController limpio.
    private func makeRectSketch(width w: Float, height h: Float) -> SketchController {
        let s = SketchController()
        s.activeTool = .rectangle
        s.tap(at: SIMD2<Float>(0, 0))
        s.tap(at: SIMD2<Float>(w, h))
        return s
    }

    // MARK: - extrudedShapeForActiveRegion → prisma con volumen exacto

    func testExtrudeActiveRegionRectangleExactVolume() throws {
        // Rect 4×3 seleccionado por tap interior, extruido D=10 → V = 4·3·10 = 120.
        let s = makeRectSketch(width: 4, height: 3)
        XCTAssertTrue(s.selectRegion(at: SIMD2<Float>(2, 1.5)),
                      "tocar dentro del rect debe seleccionar su región cerrada")

        let prism = try XCTUnwrap(s.extrudedShapeForActiveRegion(distance: 10),
                                  "una región cerrada seleccionada debe dar un prisma B-rep")
        let vol = try XCTUnwrap(prism.volume, "el prisma B-rep debe tener volumen medible")
        XCTAssertEqual(vol, 4 * 3 * 10, accuracy: 0.05,
                       "prisma de la región 4×3 × distancia 10 = 120 EXACTO")
        XCTAssertFalse(prism.faces().isEmpty, "el prisma es un sólido con caras B-rep")
    }

    func testExtrudeActiveRegionFallsBackToLargestRegionWithoutSelection() throws {
        // Sin `selectRegion` explícito: el contrato usa la mayor región detectada.
        let s = makeRectSketch(width: 2, height: 2)
        let prism = try XCTUnwrap(s.extrudedShapeForActiveRegion(distance: 5),
                                  "sin selección explícita cae a la región de mayor área")
        XCTAssertEqual(try XCTUnwrap(prism.volume), 2 * 2 * 5, accuracy: 0.05,
                       "región 2×2 × distancia 5 = 20")
    }

    func testExtrudeActiveRegionNilWithoutClosedRegion() {
        // Sketch abierto (una sola línea): no hay región cerrada → nil, sin geometría falsa.
        let s = SketchController()
        s.activeTool = .line
        s.tap(at: SIMD2<Float>(0, 0))
        s.tap(at: SIMD2<Float>(3, 0))
        XCTAssertFalse(s.hasClosedProfile)
        XCTAssertNil(s.extrudedShapeForActiveRegion(distance: 10),
                     "sin región cerrada, el prisma debe ser nil (no un sólido vacío)")
    }

    func testExtrudeActiveRegionNilForNonPositiveDistance() {
        let s = makeRectSketch(width: 2, height: 2)
        XCTAssertNil(s.extrudedShapeForActiveRegion(distance: 0),
                     "distancia no positiva no produce prisma")
    }

    // MARK: - activeRegionProfile → cara planar no vacía

    func testActiveRegionProfileIsNonEmptyPlanarFace() throws {
        // Rect 4×3 → perfil planar; oráculo de ÁREA: la cara mide 4·3 = 12.
        let s = makeRectSketch(width: 4, height: 3)
        XCTAssertTrue(s.selectRegion(at: SIMD2<Float>(2, 1.5)))

        let profile = try XCTUnwrap(s.activeRegionProfile(),
                                    "una región válida debe dar una cara B-rep")
        let faces = profile.faces()
        XCTAssertFalse(faces.isEmpty, "el perfil no debe ser una cara vacía")
        let face = try XCTUnwrap(faces.first)
        XCTAssertTrue(face.isPlanar, "el perfil de una región de sketch es planar")
        XCTAssertEqual(face.area(), 4 * 3, accuracy: 0.05,
                       "el área de la cara = área de la región 4×3 = 12")
    }

    func testActiveRegionProfileNilForOpenSketch() {
        // Sketch abierto → sin perfil planar (nil honesto, no cara degenerada).
        let s = SketchController()
        s.activeTool = .line
        s.tap(at: SIMD2<Float>(0, 0))
        s.tap(at: SIMD2<Float>(3, 0))
        XCTAssertNil(s.activeRegionProfile(),
                     "un sketch abierto no tiene región cerrada → perfil nil")
    }

    // MARK: - El no-op murió: ya no hay extrude que devuelva geometría vacía

    /// El antiguo `CADSketchEngine.extrudeSketch` devolvía `Mesh()` vacío (no-op
    /// que compilaba). Fue eliminado; el único camino de extrude (el contrato)
    /// produce SÓLIDOS con volumen real. Este test es el guardián de esa muerte:
    /// si alguien reintroduce un extrude que devuelve vacío, el oráculo lo caza.
    func testExtrudePathProducesRealSolidNotEmptyMesh() throws {
        let s = makeRectSketch(width: 2, height: 2)
        let prism = try XCTUnwrap(s.extrudedShapeForActiveRegion(distance: 3),
                                  "el ÚNICO camino de extrude debe dar un sólido, nunca vacío")
        // Un no-op (Mesh() vacío) tendría volumen 0/nil y cero caras. Aquí exigimos lo contrario.
        XCTAssertGreaterThan(try XCTUnwrap(prism.volume), 1e-3,
                             "el sólido tiene volumen > 0 (el no-op daba 0)")
        XCTAssertFalse(prism.faces().isEmpty, "el sólido tiene caras B-rep (el no-op no)")
    }
}
