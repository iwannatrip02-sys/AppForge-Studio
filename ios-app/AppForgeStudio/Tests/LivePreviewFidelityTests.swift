import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Contrato de FIDELIDAD DEL PREVIEW: el fantasma es la MISMA operación que se
/// confirma al soltar.
///
/// Ninguno de los cuatro casos lo cumplía, y el estado ya traía los datos:
///   · extrusión → `extruded(by:)` barría el sólido ENTERO como prisma, cuando
///     el commit hace push/pull sobre UNA cara.
///   · fillet y chaflán → variantes GLOBALES (todas las aristas) teniendo el
///     `edgeIndex` a mano.
///   · vaciado → ligaba `openFaceIndex` y no lo usaba.
///
/// Un preview que miente es peor que no tener preview: arrastras confiando en
/// lo que ves y sueltas sobre otra cosa.
@MainActor
final class LivePreviewFidelityTests: XCTestCase {

    private func box() throws -> CADShape {
        try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
    }

    /// El fantasma de push/pull tiene el MISMO volumen que la operación real.
    /// Con `extruded(by:)` el volumen era el del prisma del cuerpo entero.
    func testExtrudeGhostMatchesRealPushPull() throws {
        let shape = try box()                       // volumen 8
        let engine = LivePreviewEngine()
        let faceIndex = try XCTUnwrap(
            BRepModeling.faceIndex(of: shape, withNormal: SIMD3<Double>(0, 0, 1)),
            "la caja tiene una cara con normal +Z")

        engine.beginExtrude(shape: shape, faceIndex: faceIndex,
                            direction: SIMD3<Float>(0, 0, 1), initialDistance: 0.5)
        let ghost = try XCTUnwrap(engine.previewMesh, "debe haber fantasma")

        let real = try XCTUnwrap(BRepModeling.pushPullFace(shape, faceIndex: faceIndex,
                                                           distance: 0.5))
        let realVolume = try XCTUnwrap(real.volume)
        XCTAssertEqual(realVolume, 8 + 2 * 2 * 0.5, accuracy: 1e-6,
                       "boss de 0.5 sobre una cara 2×2 añade 2.0")
        XCTAssertFalse(ghost.vertices.isEmpty)

        // El fantasma se genera del MISMO shape que la operación real.
        let ghostFromReal = try XCTUnwrap(OCCTBridge.toMesh(real, quality: .low))
        XCTAssertEqual(ghost.vertices.count, ghostFromReal.vertices.count,
                       "el fantasma es la malla de la operación real, no otra cosa")
    }

    /// El fillet fantasma afecta a UNA arista, no a las doce. Con la variante
    /// global el sólido quedaba redondeado por completo.
    func testFilletGhostIsPerEdgeNotGlobal() throws {
        let shape = try box()
        let engine = LivePreviewEngine()
        engine.beginFillet(shape: shape, edgeIndex: 0, initialRadius: 0.2)
        let ghost = try XCTUnwrap(engine.previewMesh)

        let perEdge = try XCTUnwrap(shape.filleted(edges: [shape.edges()[0]], radius: 0.2))
        let global = try XCTUnwrap(shape.filleted(radius: 0.2))

        let perEdgeFaces = perEdge.faces().count
        let globalFaces = global.faces().count
        XCTAssertNotEqual(perEdgeFaces, globalFaces,
                          "redondear una arista y redondearlas todas dan sólidos distintos")

        let ghostOfPerEdge = try XCTUnwrap(OCCTBridge.toMesh(perEdge, quality: .low))
        XCTAssertEqual(ghost.vertices.count, ghostOfPerEdge.vertices.count,
                       "el fantasma corresponde al fillet de UNA arista")
    }

    /// El vaciado fantasma respeta la cara ABIERTA elegida.
    func testShellGhostRespectsOpenFace() throws {
        let shape = try box()
        let engine = LivePreviewEngine()
        engine.beginShell(shape: shape, openFaceIndex: 0, initialThickness: 0.2)
        let ghost = try XCTUnwrap(engine.previewMesh)

        let withOpenFace = try XCTUnwrap(
            shape.shelled(thickness: 0.2, openFaces: [shape.faces()[0]]))
        let ghostOfOpen = try XCTUnwrap(OCCTBridge.toMesh(withOpenFace, quality: .low))
        XCTAssertEqual(ghost.vertices.count, ghostOfOpen.vertices.count,
                       "el fantasma es la cáscara con la cara abierta, no la cerrada")
    }

    /// Si el parámetro no es aplicable, el fantasma DESAPARECE en vez de
    /// congelarse en el último válido — la señal honesta de "esto no se puede".
    func testGhostDisappearsWhenOperationIsInvalid() throws {
        let shape = try box()                       // caja 2×2×2
        let engine = LivePreviewEngine()
        engine.beginFillet(shape: shape, edgeIndex: 0, initialRadius: 0.2)
        XCTAssertNotNil(engine.previewMesh, "0.2 es un radio válido")

        // Radio imposible para una caja de lado 2.
        engine.update(parameter: 50)
        XCTAssertNil(engine.previewMesh,
                     "con un radio inaplicable no debe quedar fantasma congelado")
        XCTAssertNil(engine.previewEdges)
    }

    /// Índices fuera de rango no producen geometría inventada.
    func testOutOfRangeIndicesProduceNoGhost() throws {
        let shape = try box()
        let engine = LivePreviewEngine()
        engine.beginFillet(shape: shape, edgeIndex: 999, initialRadius: 0.1)
        XCTAssertNil(engine.previewMesh)

        engine.beginExtrude(shape: shape, faceIndex: 999,
                            direction: SIMD3<Float>(0, 0, 1), initialDistance: 0.3)
        XCTAssertNil(engine.previewMesh)
    }
}
