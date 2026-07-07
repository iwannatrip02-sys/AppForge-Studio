import XCTest
import simd
@testable import AppForgeStudio

/// Tests contra la API REAL de GeometryConstraintManager:
/// gestión de constraints + solver 2D vía resolveConstraints(with:) -> SolverMetrics.
/// (La versión anterior probaba una API inexistente: evaluateConstraint/solve(positions:).)
final class GeometryConstraintManagerTests: XCTestCase {
    var manager: GeometryConstraintManager!

    override func setUp() {
        super.setUp()
        manager = GeometryConstraintManager()
    }

    // MARK: - Modelo de constraint (determinista, sin solver)

    func testRequiredEntityCounts() {
        XCTAssertEqual(GeometryConstraint(type: .horizontal, entityIDs: [UUID()]).requiredEntityCount, 1)
        XCTAssertEqual(GeometryConstraint(type: .distance, entityIDs: []).requiredEntityCount, 2)
        XCTAssertEqual(GeometryConstraint(type: .midpoint, entityIDs: []).requiredEntityCount, 3)
        XCTAssertEqual(GeometryConstraint(type: .perpendicular, entityIDs: []).requiredEntityCount, 4)
    }

    func testDistanceConstraintWithoutValueIsInvalid() {
        let c = GeometryConstraint(type: .distance, entityIDs: [UUID(), UUID()])
        XCTAssertFalse(c.isValid, "distance sin value debe ser inválido")
        let cWithValue = GeometryConstraint(type: .distance, entityIDs: [UUID(), UUID()], value: 5)
        XCTAssertTrue(cWithValue.isValid)
    }

    func testDefaultLabelFallsBackToTypeName() {
        let c = GeometryConstraint(type: .horizontal, entityIDs: [UUID()])
        XCTAssertFalse(c.label.isEmpty, "label vacío debe caer al rawValue del tipo")
    }

    // MARK: - Gestión de constraints

    func testAddRemoveUpdateConstraint() {
        let c1 = GeometryConstraint(type: .horizontal, entityIDs: [UUID()])
        let c2 = GeometryConstraint(type: .vertical, entityIDs: [UUID()])
        manager.addConstraint(c1)
        manager.addConstraint(c2)
        XCTAssertEqual(manager.constraintCount, 2)
        manager.removeConstraint(at: c1.id)
        XCTAssertEqual(manager.constraintCount, 1)
        var updated = c2
        updated.label = "Test"
        manager.updateConstraint(updated)
        XCTAssertEqual(manager.constraints.first?.label, "Test")
    }

    func testToggleConstraint() {
        let c = GeometryConstraint(type: .horizontal, entityIDs: [UUID()])
        manager.addConstraint(c)
        XCTAssertTrue(c.isActive)
        manager.toggleConstraint(c.id)
        XCTAssertFalse(manager.constraints.first?.isActive ?? true)
        XCTAssertEqual(manager.activeConstraintCount, 0)
        XCTAssertTrue(manager.getActiveConstraints().isEmpty)
    }

    func testClearAll() {
        manager.addConstraint(GeometryConstraint(type: .horizontal, entityIDs: [UUID()]))
        manager.addConstraint(GeometryConstraint(type: .vertical, entityIDs: [UUID()]))
        manager.clearAll()
        XCTAssertEqual(manager.constraintCount, 0)
    }

    // MARK: - Solver 2D (resolveConstraints(with:))

    func testSolveWithNoConstraintsConvergesImmediately() {
        var points = [
            SketchPoint(position: SIMD2<Float>(0, 0)),
            SketchPoint(position: SIMD2<Float>(1, 0)),
        ]
        let metrics = manager.resolveConstraints(with: &points)
        XCTAssertTrue(metrics.converged)
        XCTAssertEqual(metrics.iterationCount, 0)
    }

    func testSolveAlreadySatisfiedDistanceConstraint() {
        // Los 2 primeros puntos quedan fijos en el solver; el tercero lleva la constraint.
        let p0 = SketchPoint(position: SIMD2<Float>(0, 0))
        let p1 = SketchPoint(position: SIMD2<Float>(1, 0))
        let p2 = SketchPoint(position: SIMD2<Float>(3, 4))
        var points = [p0, p1, p2]

        // distancia p0→p2 = 5, ya satisfecha exactamente
        manager.addConstraint(GeometryConstraint(type: .distance,
                                                 entityIDs: [p0.id, p2.id],
                                                 value: 5))
        let metrics = manager.resolveConstraints(with: &points)
        XCTAssertTrue(metrics.converged, "configuración ya satisfecha debe converger")

        let solved = points[2].position
        let dist = simd_distance(SIMD2<Float>(0, 0), solved)
        XCTAssertEqual(dist, 5.0, accuracy: 0.05, "la distancia debe mantenerse en 5")
    }

    func testSolveUpdatesLastSolveMetrics() {
        let p0 = SketchPoint(position: SIMD2<Float>(0, 0))
        let p1 = SketchPoint(position: SIMD2<Float>(1, 0))
        let p2 = SketchPoint(position: SIMD2<Float>(2, 3))
        var points = [p0, p1, p2]

        manager.addConstraint(GeometryConstraint(type: .distance,
                                                 entityIDs: [p0.id, p2.id],
                                                 value: 4))
        let metrics = manager.resolveConstraints(with: &points)
        XCTAssertEqual(manager.lastSolve.iterationCount, metrics.iterationCount,
                       "lastSolve debe reflejar la última resolución")
        XCTAssertEqual(manager.lastSolve.converged, metrics.converged)
    }

    func testInactiveConstraintIsIgnoredBySolver() {
        let p0 = SketchPoint(position: SIMD2<Float>(0, 0))
        let p1 = SketchPoint(position: SIMD2<Float>(1, 0))
        let p2 = SketchPoint(position: SIMD2<Float>(7, 9))
        var points = [p0, p1, p2]

        var c = GeometryConstraint(type: .distance, entityIDs: [p0.id, p2.id], value: 1)
        c.isActive = false
        manager.addConstraint(c)

        _ = manager.resolveConstraints(with: &points)
        XCTAssertEqual(points[2].position.x, 7, accuracy: 0.001,
                       "constraint inactiva no debe mover puntos")
        XCTAssertEqual(points[2].position.y, 9, accuracy: 0.001)
    }
}
