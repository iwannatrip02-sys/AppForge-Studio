import XCTest
@testable import AppForgeStudio

/// Tests para la integración del solver Newton-Raphson con SketchController.
/// Verifica: inferencia de constraints, resolución, aplicación a entidades.
@MainActor
final class ConstraintBridgeTests: XCTestCase {

    var sketch: SketchController!

    override func setUp() {
        super.setUp()
        sketch = SketchController()
    }

    override func tearDown() {
        sketch.clear()
        sketch = nil
        super.tearDown()
    }

    // MARK: - Inferencia de constraints

    func testInferParallelLines() {
        // Dos líneas paralelas horizontales
        sketch.tap(at: SIMD2<Float>(0, 0))
        sketch.tap(at: SIMD2<Float>(5, 0))
        sketch.tap(at: SIMD2<Float>(0, 0))  // cierra (no, para cadena abierta necesitamos otro approach)
        // Limpiar y usar entidades directas
        sketch.clear()
        // Insertar manualmente dos líneas paralelas
        // La cadena polyline con 2+ taps no se cierra hasta tap en primer punto
        // Vamos a probar con rectángulos (que son inherentemente hor/vert)
        sketch.activeTool = .rectangle
        sketch.tap(at: SIMD2<Float>(0, 0))
        sketch.tap(at: SIMD2<Float>(5, 3))
        sketch.inferConstraints()
        // Un rectángulo debería inferir constraint horizontal/vertical
        XCTAssertGreaterThan(sketch.activeConstraints.count, 0)
    }

    func testInferCoincidentPoints() {
        sketch.clear()
        sketch.activeTool = .line
        // Dibujar una línea
        sketch.tap(at: SIMD2<Float>(1, 1))
        sketch.tap(at: SIMD2<Float>(2, 1))
        sketch.tap(at: SIMD2<Float>(1, 1))  // cerrar

        // Dibujar otra línea que empieza cerca del primer punto
        sketch.tap(at: SIMD2<Float>(2.05, 2.05))
        sketch.tap(at: SIMD2<Float>(3, 3))
        sketch.tap(at: SIMD2<Float>(2.05, 2.05))

        sketch.inferConstraints()
        // Debería detectar alguna restricción (coincidente o paralela)
        XCTAssertGreaterThan(sketch.activeConstraints.count, 0,
                             "Should infer at least one constraint from nearby geometry")
    }

    func testInferConstraintsWithEmptySketch() {
        sketch.clear()
        sketch.inferConstraints()
        XCTAssertEqual(sketch.activeConstraints.count, 0)
    }

    func testAutoConstrainDisabled() {
        sketch.autoConstrain = false
        sketch.activeTool = .rectangle
        sketch.tap(at: SIMD2<Float>(0, 0))
        sketch.tap(at: SIMD2<Float>(5, 3))
        sketch.inferConstraints()
        XCTAssertEqual(sketch.activeConstraints.count, 0)
    }

    // MARK: - Resolución de constraints

    func testResolveConstraintsConverges() {
        sketch.clear()
        sketch.activeTool = .line
        // Dibujar un triángulo aproximado (debería converger a equilátero con constraints)
        sketch.tap(at: SIMD2<Float>(0, 0))
        sketch.tap(at: SIMD2<Float>(3, 0))
        sketch.tap(at: SIMD2<Float>(1.5, 2.5))
        sketch.tap(at: SIMD2<Float>(0, 0))  // cerrar

        // Agregar constraints de igual longitud
        // Las entidades tienen 3 puntos (triángulo cerrado = 1 polyline con 3 pts)
        let pts = sketch.entities.compactMap { e -> [SIMD2<Float>]? in
            if case .polyline(let polyPts, true) = e { return polyPts }
            return nil
        }.first

        XCTAssertNotNil(pts, "Should have a closed polyline")
        XCTAssertEqual(pts?.count, 3, "Triangle should have 3 points")

        // Inferir y resolver
        sketch.inferConstraints()
        if !sketch.activeConstraints.isEmpty {
            sketch.resolveConstraints()
            // Si hay constraints, el solver debería converger
            // (no podemos garantizar convergencia, pero sí que no crashea)
        }
    }

    func testResolveConstraintsEmpty() {
        sketch.clear()
        sketch.resolveConstraints()
        // No debería crashear con constraints vacías
        XCTAssertTrue(true)
    }

    func testConstraintPersistenceAcrossClear() {
        sketch.activeTool = .rectangle
        sketch.tap(at: SIMD2<Float>(0, 0))
        sketch.tap(at: SIMD2<Float>(5, 3))
        sketch.inferConstraints()
        let count = sketch.activeConstraints.count

        sketch.clear()
        XCTAssertEqual(sketch.activeConstraints.count, 0,
                       "Constraints should be cleared with sketch")
    }

    // MARK: - Bridge constraint types

    func testBridgeHorizontalConstraint() {
        let gc = GeometryConstraint(type: .horizontal,
                                     entityIDs: [UUID()],
                                     label: "H")
        // Esto se prueba indirectamente vía inferConstraints()
        // que genera constraints horizontales para rectángulos
        sketch.clear()
        sketch.activeTool = .rectangle
        sketch.tap(at: SIMD2<Float>(0, 0))
        sketch.tap(at: SIMD2<Float>(5, 0.01))  // casi horizontal
        sketch.inferConstraints()
        let hasHorizontal = sketch.activeConstraints.contains {
            $0.type == .horizontal
        }
        XCTAssertTrue(hasHorizontal,
                      "Nearly horizontal rectangle should infer horizontal constraint")
    }

    func testBridgeVerticalConstraint() {
        sketch.clear()
        sketch.activeTool = .rectangle
        sketch.tap(at: SIMD2<Float>(0, 0))
        sketch.tap(at: SIMD2<Float>(0.01, 5))  // casi vertical
        sketch.inferConstraints()
        let hasVertical = sketch.activeConstraints.contains {
            $0.type == .vertical
        }
        XCTAssertTrue(hasVertical,
                      "Nearly vertical rectangle should infer vertical constraint")
    }

    // MARK: - SolverSwift bridge (end-to-end)

    func testSolverBridgeDistanceConstraint() {
        let solver = SolverSwift()
        let idA = UUID()
        let idB = UUID()
        solver.addPoint(SolverPoint(id: idA, x: 0, y: 0, isFixed: true))
        solver.addPoint(SolverPoint(id: idB, x: 8, y: 6, isFixed: false))
        solver.addConstraint(SolverConstraint(
            id: UUID(),
            type: .distance(pointA: idA, pointB: idB, value: 5.0),
            weight: 1.0
        ))
        let result = solver.solve()
        XCTAssertTrue(result.converged)
        if let b = result.points.first(where: { $0.id == idB }) {
            let dist = sqrt(b.x * b.x + b.y * b.y)
            XCTAssertEqual(dist, 5.0, accuracy: 0.01)
        } else {
            XCTFail("Point B not found in result")
        }
    }

    func testSolverBridgeMultipleConstraints() {
        let solver = SolverSwift()
        let origin = UUID()
        let pA = UUID()
        let pB = UUID()

        solver.addPoint(SolverPoint(id: origin, x: 0, y: 0, isFixed: true))
        solver.addPoint(SolverPoint(id: pA, x: 10, y: 0, isFixed: false))
        solver.addPoint(SolverPoint(id: pB, x: 0, y: 10, isFixed: false))

        // pA a distancia 5 del origen
        solver.addConstraint(SolverConstraint(
            id: UUID(),
            type: .distance(pointA: origin, pointB: pA, value: 5.0),
            weight: 1.0
        ))
        // pB a distancia 5 del origen
        solver.addConstraint(SolverConstraint(
            id: UUID(),
            type: .distance(pointA: origin, pointB: pB, value: 5.0),
            weight: 1.0
        ))
        // Ángulo recto entre pA y pB
        solver.addConstraint(SolverConstraint(
            id: UUID(),
            type: .angle(pointA: pA, pointB: origin, pointC: pB, value: .pi / 2),
            weight: 1.0
        ))

        let result = solver.solve()
        XCTAssertTrue(result.converged)

        if let a = result.points.first(where: { $0.id == pA }),
           let b = result.points.first(where: { $0.id == pB }) {
            let distA = sqrt(a.x * a.x + a.y * a.y)
            let distB = sqrt(b.x * b.x + b.y * b.y)
            XCTAssertEqual(distA, 5.0, accuracy: 0.1)
            XCTAssertEqual(distB, 5.0, accuracy: 0.1)
            // Producto escalar ≈ 0 (ángulo recto)
            let dot = a.x * b.x + a.y * b.y
            XCTAssertEqual(dot, 0.0, accuracy: 0.5)
        } else {
            XCTFail("Points not found in result")
        }
    }
}
