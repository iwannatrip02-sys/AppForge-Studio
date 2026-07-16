import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Contrato de CALIDAD DE MALLA y de LÍNEAS (feedback en device, jul-2026):
///   (1) "un cilindro se ve como pedacitos planos" → curvas facetadas.
///       Causa: la deflección ANGULAR por defecto de OCCT (0.5 rad ≈ 28.6°)
///       gobierna cuántos segmentos tiene una curva; `toMesh` no la pasaba, así
///       que un cilindro salía con ~13 gajos. Fix: deflección angular por calidad
///       (medium 0.20 rad ≈ 11.5° → ~32 segmentos/círculo → curva continua).
///   (2) "las líneas casi ni se notan; la selección de arista casi no se nota".
///       Causa: ancho base 2.2 px y brasa 3.0 px (apenas +0.8 → imperceptible),
///       y tolerancias de picking demasiado apretadas (0.03). Fix: anchos y
///       tolerancias subidos; la brasa de selección claramente más ancha que la base.
final class MeshQualityContractTests: XCTestCase {

    // MARK: - (1) Curvas: salto de fidelidad del cilindro

    /// Un cilindro en calidad MEDIA debe teselarse con muchos triángulos alrededor
    /// de la circunferencia (superficie curva continua, no gajos). Con la deflección
    /// angular vieja (0.5 rad) salían ~13 segmentos → ~pocas decenas de triángulos;
    /// con 0.20 rad son ~32 segmentos → cientos de triángulos. Fijamos un piso
    /// holgado que la deflección vieja NO alcanzaba, documentando el salto.
    func testCylinderMediumHasContinuousCurveTessellation() throws {
        let cyl = try XCTUnwrap(OCCTSwift.Shape.cylinder(radius: 1, height: 2),
                                "cilindro base para el test de facetado")
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(cyl, quality: .medium))

        let triangleCount = mesh.indices.count / 3
        // ~32 segmentos de pared × 2 triángulos + 2 tapas ≈ ≥64 triángulos de pared.
        // Piso holgado: 120. Con la deflección angular vieja (0.5 rad) el conteo
        // caía muy por debajo → este piso documenta y protege el salto de fidelidad.
        XCTAssertGreaterThanOrEqual(triangleCount, 120,
            "cilindro medium debe teselarse fino en la curva (era facetado con 0.5 rad)")
    }

    /// Subir la calidad debe subir (monótonamente, ⩾) el conteo de triángulos:
    /// low ⩽ medium ⩽ high. Blindaje de que las deflecciones por calidad ordenan bien.
    func testCylinderTriangleCountGrowsWithQuality() throws {
        func tris(_ q: MeshQuality) throws -> Int {
            let cyl = try XCTUnwrap(OCCTSwift.Shape.cylinder(radius: 1, height: 2))
            let mesh = try XCTUnwrap(OCCTBridge.toMesh(cyl, quality: q))
            return mesh.indices.count / 3
        }
        let low = try tris(.low)
        let medium = try tris(.medium)
        let high = try tris(.high)
        XCTAssertLessThanOrEqual(low, medium, "medium teselá al menos tan fino como low")
        XCTAssertLessThan(medium, high, "high debe teselar más fino que medium")
        XCTAssertGreaterThan(medium, low,
            "medium debe ser estrictamente más fino que low (la curva ya no es facetada)")
    }

    /// Las normales del cilindro en la PARED lateral deben variar suavemente
    /// (superficie curva) — no todas iguales (que sería sombreado plano/gajos).
    func testCylinderWallNormalsVarySmoothly() throws {
        let cyl = try XCTUnwrap(OCCTSwift.Shape.cylinder(radius: 1, height: 2))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(cyl, quality: .medium))

        // Normales de la pared lateral: radiales (componente Z ≈ 0). Contamos
        // direcciones distintas — una curva continua tiene muchas.
        var distinctWallNormals: [SIMD3<Float>] = []
        for v in mesh.vertices where abs(v.normal.z) < 0.3 {
            if !distinctWallNormals.contains(where: { simd_distance($0, v.normal) < 0.1 }) {
                distinctWallNormals.append(v.normal)
            }
        }
        XCTAssertGreaterThanOrEqual(distinctWallNormals.count, 12,
            "la pared curva debe tener muchas direcciones de normal (no gajos planos)")
    }

    // MARK: - (2a) Anchos de línea (contrato de SatinRenderer)

    /// Los anchos de línea son legibles y la BRASA de selección es claramente más
    /// ancha que la base (el usuario debe VER qué seleccionó).
    func testLineWidthContract() {
        // Base legible: mucho más gruesa que la 2.2 vieja ("casi invisible").
        XCTAssertGreaterThanOrEqual(SatinRenderer.edgeHalfWidthPx, 3.0,
            "arista base debe ser legible (era 2.2, casi invisible)")
        // La brasa (arista seleccionada) claramente más ancha que la base: ≥1.5×.
        XCTAssertGreaterThanOrEqual(SatinRenderer.emberEdgeHalfWidthPx,
                                    SatinRenderer.edgeHalfWidthPx * 1.5,
            "la arista seleccionada (brasa) debe ser ≥1.5× la base (antes 3.0 vs 2.2 = imperceptible)")
        // Puntos: reposo < seleccionado, y ambos ⩾ su arista correspondiente.
        XCTAssertGreaterThan(SatinRenderer.emberDotHalfWidthPx, SatinRenderer.dotHalfWidthPx,
            "el punto seleccionado debe ser más ancho que el punto en reposo")
        XCTAssertGreaterThanOrEqual(SatinRenderer.dotHalfWidthPx, SatinRenderer.edgeHalfWidthPx,
            "los puntos se leen ⩾ que las aristas")
    }

    // MARK: - (2b) Tolerancias de picking (defaults de ScenePicking)

    /// Un toque a ~0.05 de una arista (más lejos que la tolerancia vieja de 0.03)
    /// ahora SÍ la selecciona — "tocar cerca" acierta. Caja 2×2×2: arista superior
    /// en x=1,z=1; tocamos ligeramente adentro y arriba, a ~0.05 de la arista.
    func testEdgePickerToleranceCatchesNearTouch() throws {
        let box = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        // Punto a distancia ~0.05 de la arista (1, y, 1): desplazado en x y z.
        let near = SIMD3<Float>(1.0 - 0.035, 0.0, 1.0 - 0.035)  // dist ≈ 0.0495
        let idx = BRepEdgePicker.edgeIndex(of: box, nearest: near)  // default 0.08
        XCTAssertNotNil(idx,
            "un toque a ~0.05 de la arista debe seleccionarla (la tol. vieja 0.03 fallaba)")
    }

    /// El centro de una cara (a 1.0 de toda arista) sigue SIN ser arista: subir la
    /// tolerancia a 0.08 no rompe la separación arista↔cara.
    func testEdgePickerStillRejectsFaceCenter() throws {
        let box = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        XCTAssertNil(BRepEdgePicker.edgeIndex(of: box, nearest: SIMD3<Float>(0, 0, 1)),
            "el centro de la cara (dist 1.0) no es arista ni con tol. 0.08")
    }

    /// Un toque a ~0.05 de una esquina ahora resuelve al vértice (la tol. vieja 0.03
    /// lo perdía). Esquina (1,1,1) de la caja 2×2×2.
    func testVertexPickerToleranceCatchesNearTouch() throws {
        let box = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let near = SIMD3<Float>(1.0 - 0.03, 1.0 - 0.03, 1.0 - 0.03)  // dist ≈ 0.052
        let idx = BRepVertexPicker.vertexIndex(of: box, nearest: near)  // default 0.06
        let vi = try XCTUnwrap(idx,
            "un toque a ~0.05 de la esquina debe resolver el vértice (tol. vieja 0.03 fallaba)")
        let pos = try XCTUnwrap(BRepVertexPicker.position(of: box, vertexIndex: vi))
        XCTAssertEqual(pos.x, 1, accuracy: 0.01)
        XCTAssertEqual(pos.y, 1, accuracy: 0.01)
        XCTAssertEqual(pos.z, 1, accuracy: 0.01)
    }

    /// El centro del sólido (lejos de toda esquina) sigue sin resolver vértice.
    func testVertexPickerStillRejectsCenter() throws {
        let box = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        XCTAssertNil(BRepVertexPicker.vertexIndex(of: box, nearest: SIMD3<Float>(0, 0, 0)),
            "el centro del sólido (dist ≈1.73) no está cerca de ningún vértice ni con tol. 0.06")
    }

    // MARK: - (2c) La geometría de la cinta de línea NO cambió (blindaje del contrato)

    /// El ancho de línea vive en el shader (px), NO en la geometría: la cinta sigue
    /// siendo 4 vértices/segmento y las aristas de la caja siguen en el contorno.
    /// Blindaje de que subir los anchos NO tocó `edgesMesh`/`LineRibbonBuilder`.
    func testEdgeRibbonGeometryUnchanged() throws {
        let box = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let edges = try XCTUnwrap(OCCTBridge.edgesMesh(box))
        // 12 aristas × 1 segmento × 4 vértices = 48 (mismo contrato que GizmoAndMetricsTests).
        XCTAssertEqual(edges.vertices.count % 4, 0, "cintas de 4 vértices/segmento")
        XCTAssertGreaterThanOrEqual(edges.vertices.count, 48)
        XCTAssertEqual(edges.indices.count % 3, 0, "triángulos completos")
    }
}
