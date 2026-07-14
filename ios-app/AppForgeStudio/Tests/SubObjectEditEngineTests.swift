import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Tests del motor de edición de SUB-OBJETOS (SubObjectEditEngine) — la queja #1
/// del usuario ("selecciono la base y la hago más ancha"). Patrón `BRepModelingTests`:
/// oráculos de VOLUMEN EXACTO que sólo un kernel B-rep puede garantizar. Los `nil`
/// honestos (moveEdge/moveVertex) también se verifican como contrato: OCCTSwift
/// v1.8.8 no expone la cirugía de sub-objeto que re-fitea caras vecinas.
final class SubObjectEditEngineTests: XCTestCase {

    private func makeBox(_ w: Double, _ h: Double, _ d: Double) throws -> CADShape {
        try XCTUnwrap(OCCTSwift.Shape.box(width: w, height: h, depth: d))
    }

    private func volume(of shape: CADShape) throws -> Double {
        try XCTUnwrap(shape.volume)
    }

    /// Índice de la primera cara con normal (con tolerancia) en `direction`.
    private func faceIndex(of shape: CADShape, normal direction: SIMD3<Double>) -> Int? {
        let target = simd_normalize(direction)
        return shape.faces().firstIndex { face in
            guard let n = face.normal else { return false }
            return simd_length(simd_normalize(n) - target) < 1e-4
        }
    }

    // MARK: - scaleFaceWire: la funcionalidad REAL (base más ancha)

    /// Escalar la cara superior de una caja 2×2×2 por 1.5 la convierte en un frustum
    /// (tapa 3×3, base 2×2, altura 2). Oráculo por la fórmula EXACTA del prismatoide:
    /// V = h/6·(A_base + 4·A_medio + A_tapa) = 2/6·(4 + 4·6.25 + 9) = 38/3 ≈ 12.667.
    /// Una malla de juguete no puede fingir este volumen.
    func testScaleTopFaceWidensSolidToFrustumExactVolume() throws {
        let box = try makeBox(2, 2, 2)
        XCTAssertEqual(try volume(of: box), 8.0, accuracy: 0.01, "caja de partida = 8")

        let topIdx = try XCTUnwrap(faceIndex(of: box, normal: SIMD3<Double>(0, 0, 1)),
                                   "la caja debe tener cara superior +Z")
        let widened = try XCTUnwrap(
            SubObjectEditEngine.scaleFaceWire(box, faceIndex: topIdx, factor: 1.5),
            "escalar la tapa de un prisma debe reconstruir un sólido válido")

        XCTAssertEqual(try volume(of: widened), 38.0 / 3.0, accuracy: 0.05,
                       "frustum tapa 3×3 / base 2×2 / h=2 → 38/3 por la fórmula del prismatoide")
        XCTAssertTrue(widened.isValidSolid, "el resultado es un sólido cerrado válido, no una cáscara rota")
    }

    /// Escalar > 1 AÑADE material (la tapa se ensancha); el volumen crece.
    func testScaleFaceFactorGreaterThanOneIncreasesVolume() throws {
        let box = try makeBox(2, 2, 2)
        let before = try volume(of: box)
        let topIdx = try XCTUnwrap(faceIndex(of: box, normal: SIMD3<Double>(0, 0, 1)))
        let result = try XCTUnwrap(SubObjectEditEngine.scaleFaceWire(box, faceIndex: topIdx, factor: 1.5))
        XCTAssertGreaterThan(try volume(of: result), before, "ensanchar la tapa añade material")
    }

    /// Escalar < 1 ESTRECHA la tapa (pirámide truncada hacia dentro); el volumen baja
    /// pero sigue siendo un sólido válido positivo.
    func testScaleFaceFactorLessThanOneShrinksVolume() throws {
        let box = try makeBox(2, 2, 2)
        let before = try volume(of: box)
        let topIdx = try XCTUnwrap(faceIndex(of: box, normal: SIMD3<Double>(0, 0, 1)))
        let result = try XCTUnwrap(SubObjectEditEngine.scaleFaceWire(box, faceIndex: topIdx, factor: 0.5))
        let after = try volume(of: result)
        XCTAssertLessThan(after, before, "estrechar la tapa quita material")
        XCTAssertGreaterThan(after, 0, "pero queda un sólido positivo")
        XCTAssertTrue(result.isValidSolid)
    }

    /// factor == 1 (no-op) → nil (nada que hacer, no se ofrece la acción).
    func testScaleFaceIdentityFactorReturnsNil() throws {
        let box = try makeBox(2, 2, 2)
        let topIdx = try XCTUnwrap(faceIndex(of: box, normal: SIMD3<Double>(0, 0, 1)))
        XCTAssertNil(SubObjectEditEngine.scaleFaceWire(box, faceIndex: topIdx, factor: 1.0),
                     "factor 1 es no-op → nil honesto, sin reconstrucción")
    }

    /// Índice de cara inválido → nil (sin crash).
    func testScaleFaceInvalidIndexReturnsNil() throws {
        let box = try makeBox(1, 1, 1)
        XCTAssertNil(SubObjectEditEngine.scaleFaceWire(box, faceIndex: 999, factor: 1.5))
        XCTAssertNil(SubObjectEditEngine.scaleFaceWire(box, faceIndex: -1, factor: 1.5))
    }

    /// factor no positivo (escala degenerada) → nil.
    func testScaleFaceNonPositiveFactorReturnsNil() throws {
        let box = try makeBox(1, 1, 1)
        let topIdx = try XCTUnwrap(faceIndex(of: box, normal: SIMD3<Double>(0, 0, 1)))
        XCTAssertNil(SubObjectEditEngine.scaleFaceWire(box, faceIndex: topIdx, factor: 0))
        XCTAssertNil(SubObjectEditEngine.scaleFaceWire(box, faceIndex: topIdx, factor: -1))
    }

    // MARK: - moveEdge / moveVertex: nil HONESTO documentado (contrato)

    /// `moveEdge` es hoy `nil` honesto: OCCTSwift v1.8.8 no expone una cirugía que
    /// re-fitee las caras vecinas al mover una arista (sólo BRepTools_ReShape, que
    /// intercambia handles sin re-fitear). El contrato existe y compila para G1.
    func testMoveEdgeIsHonestNilInV188() throws {
        let box = try makeBox(2, 2, 2)
        XCTAssertNil(SubObjectEditEngine.moveEdge(box, edgeIndex: 0,
                                                  delta: SIMD3<Double>(0.5, 0, 0)),
                     "sin modifier de sub-objeto en v1.8.8, moveEdge devuelve nil honesto")
    }

    /// `moveVertex` idem: nil honesto hasta que OCCTSwift exponga un modificador de
    /// vértice (o hasta editar el perfil paramétrico en Tanda B).
    func testMoveVertexIsHonestNilInV188() throws {
        let box = try makeBox(2, 2, 2)
        XCTAssertNil(SubObjectEditEngine.moveVertex(box, vertexIndex: 0,
                                                    delta: SIMD3<Double>(0, 0, 0.5)),
                     "sin modifier de vértice en v1.8.8, moveVertex devuelve nil honesto")
    }
}
