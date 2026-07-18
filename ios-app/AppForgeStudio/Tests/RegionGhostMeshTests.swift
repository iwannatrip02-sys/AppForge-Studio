import XCTest
import simd
@testable import AppForgeStudio

/// La malla FANTASMA de extrusión (preview vivo bajo el dedo, sin OCCT) debe
/// ser un prisma CERRADO con el conteo esperado de vértices/triángulos y el
/// volumen correcto — así el preview coincide con el sólido B-rep final.
final class RegionGhostMeshTests: XCTestCase {

    /// Plano SUELO por defecto (idéntico a SketchController.WorkPlane.floor):
    /// origin=0, u=+X, v=+Z, normal=+Y. Un punto 2D (x,y) → mundo (x, h, y).
    private let origin = SIMD3<Float>(0, 0, 0)
    private let u = SIMD3<Float>(1, 0, 0)
    private let v = SIMD3<Float>(0, 0, 1)
    private let normal = SIMD3<Float>(0, 1, 0)

    /// Cuadrado 2×2 centrado en el origen del plano.
    private let square: [SIMD2<Float>] = [
        SIMD2(-1, -1), SIMD2(1, -1), SIMD2(1, 1), SIMD2(-1, 1),
    ]

    func testSquareGhostHasExpectedTriangleAndVertexCount() throws {
        let mesh = try XCTUnwrap(RegionGhostMesh.build(
            polygon: square, origin: origin, u: u, v: v, normal: normal, height: 1))

        // Por segmento (4): 1 tri tapa arriba + 1 tri tapa abajo + 2 tri pared = 4.
        // Total triángulos = 4 lados × 4 = 16 → 48 índices.
        XCTAssertEqual(mesh.indices.count, 48, "16 triángulos → 48 índices")
        XCTAssertEqual(mesh.indices.count % 3, 0)

        // Vértices: 2 centros (tapas) + por segmento 6 (2 top + 2 bot + ... en
        // realidad add() crea vértices frescos por triángulo). Verificamos que
        // el número es determinista y coincide con la construcción.
        // 2 centros + 4 lados × (2 top + 2 bot + 4 pared) = 2 + 4×8 = 34.
        XCTAssertEqual(mesh.vertices.count, 34)
    }

    func testSquareGhostVolumeMatchesPrism() throws {
        // Cuadrado 2×2 (área 4) × altura 1 = volumen 4.
        let mesh = try XCTUnwrap(RegionGhostMesh.build(
            polygon: square, origin: origin, u: u, v: v, normal: normal, height: 1))
        XCTAssertEqual(RegionGhostMesh.enclosedVolume(mesh), 4.0, accuracy: 1e-4,
                       "prisma cuadrado 2×2 alto 1 → volumen 4 por malla cerrada")

        // Escala la altura → volumen escala lineal.
        let mesh3 = try XCTUnwrap(RegionGhostMesh.build(
            polygon: square, origin: origin, u: u, v: v, normal: normal, height: 3))
        XCTAssertEqual(RegionGhostMesh.enclosedVolume(mesh3), 12.0, accuracy: 1e-4,
                       "misma base, alto 3 → volumen 12")
    }

    func testGhostBoundingBoxSpansHeightAlongNormal() throws {
        let mesh = try XCTUnwrap(RegionGhostMesh.build(
            polygon: square, origin: origin, u: u, v: v, normal: normal, height: 2.5))
        var minY = Float.greatestFiniteMagnitude, maxY = -Float.greatestFiniteMagnitude
        for vert in mesh.vertices {
            minY = min(minY, vert.position.y)
            maxY = max(maxY, vert.position.y)
        }
        XCTAssertEqual(minY, 0, accuracy: 1e-5, "la tapa inferior está en el plano (y=0)")
        XCTAssertEqual(maxY, 2.5, accuracy: 1e-5, "la tapa superior está a la altura (y=2.5)")
    }

    func testDegenerateInputsReturnNil() {
        XCTAssertNil(RegionGhostMesh.build(
            polygon: [SIMD2(0, 0), SIMD2(1, 1)],  // <3 vértices
            origin: origin, u: u, v: v, normal: normal, height: 1))
        XCTAssertNil(RegionGhostMesh.build(
            polygon: square, origin: origin, u: u, v: v, normal: normal, height: 0),
            "altura 0 no genera fantasma")
    }
}
