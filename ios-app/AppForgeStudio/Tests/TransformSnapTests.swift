import XCTest
import simd
@testable import AppForgeStudio

/// Oráculos PUROS de la manipulación directa (Ola LiveInteraction · L2 · tarea 8):
/// cuantización de snap, transformación de ejes local/global y formateo de la
/// lectura viva. `TransformSnap` no depende de UIKit/SwiftUI ni de estado de vista,
/// así que se ejercita en aislamiento — una sola fuente de verdad para la aritmética
/// que `CADModeView` delega.
final class TransformSnapTests: XCTestCase {

    // MARK: - Cuantización de snap (tarea 2)

    func testSnapDisabledIsIdentity() {
        // Con el snap apagado el valor pasa TAL CUAL (no hay placebo).
        let v = 1.2345
        for kind in [TransformSnapKind.length, .angle, .factor] {
            XCTAssertEqual(
                TransformSnap.quantize(v, kind: kind, enabled: false,
                                       gridStep: 0.5, angleStepDegrees: 15),
                v, accuracy: 1e-12,
                "snap apagado → identidad para \(kind)")
        }
    }

    func testLengthSnapsToGridStep() {
        // 1.2 con paso 0.5 → 1.0 (detente más cercano).
        XCTAssertEqual(
            TransformSnap.quantize(1.2, kind: .length, enabled: true,
                                   gridStep: 0.5, angleStepDegrees: 15),
            1.0, accuracy: 1e-9)
        // 1.3 con paso 0.5 → 1.5 (redondea hacia arriba).
        XCTAssertEqual(
            TransformSnap.quantize(1.3, kind: .length, enabled: true,
                                   gridStep: 0.5, angleStepDegrees: 15),
            1.5, accuracy: 1e-9)
    }

    func testLengthGridStepHasFloor() {
        // gridStep degenerado (0) se satura a 0.01 → no divide por cero.
        let r = TransformSnap.quantize(0.037, kind: .length, enabled: true,
                                       gridStep: 0, angleStepDegrees: 15)
        XCTAssertEqual(r, 0.04, accuracy: 1e-9, "paso mínimo 0.01 aplicado")
    }

    func testAngleSnapsToDegreeIncrement() {
        // 20° (en rad) con incremento 15° → 15° (rad). El motor trabaja en radianes.
        let twentyDeg = 20.0 * .pi / 180
        let snapped = TransformSnap.quantize(twentyDeg, kind: .angle, enabled: true,
                                             gridStep: 0.5, angleStepDegrees: 15)
        XCTAssertEqual(snapped, 15.0 * .pi / 180, accuracy: 1e-9)
    }

    func testAngleFallsBackTo15DegreesWhenNonPositive() {
        // angleStepDegrees ≤ 0 → 15° por defecto (contrato del snap).
        let fortyDeg = 40.0 * .pi / 180
        let snapped = TransformSnap.quantize(fortyDeg, kind: .angle, enabled: true,
                                             gridStep: 0.5, angleStepDegrees: 0)
        XCTAssertEqual(snapped, 45.0 * .pi / 180, accuracy: 1e-9,
                       "40° con incremento default 15° → 45°")
    }

    func testFactorSnapsToQuarterStepsWithFloor() {
        XCTAssertEqual(
            TransformSnap.quantize(1.30, kind: .factor, enabled: true,
                                   gridStep: 0.5, angleStepDegrees: 15),
            1.25, accuracy: 1e-9, "factor → múltiplo de 0.25")
        // Factor colapsante: 0.01 se satura al mínimo 0.05 (no encoge a 0).
        XCTAssertEqual(
            TransformSnap.quantize(0.01, kind: .factor, enabled: true,
                                   gridStep: 0.5, angleStepDegrees: 15),
            TransformSnap.minScaleFactor, accuracy: 1e-9)
    }

    // MARK: - Cruce de detente para el haptic

    func testCrossedDetentIgnoresFirstFrame() {
        // Sin detente previo (primer frame del gesto) NO cuenta como cruce → sin zumbido.
        XCTAssertFalse(TransformSnap.crossedDetent(1.0, last: nil))
    }

    func testCrossedDetentDetectsChangeAndIgnoresRepeat() {
        XCTAssertTrue(TransformSnap.crossedDetent(1.5, last: 1.0), "nuevo detente → cruce")
        XCTAssertFalse(TransformSnap.crossedDetent(1.0, last: 1.0), "mismo detente → sin cruce")
    }

    // MARK: - Transformación de ejes local/global (tarea 3)

    func testGlobalAxisIsIdentity() {
        // En global, el eje del gizmo pasa tal cual, sin importar la rotación.
        let axis = SIMD3<Float>(1, 0, 0)
        let rot = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 0, 1))
        let r = TransformSnap.resolveAxis(axis, local: false, rotation: rot)
        XCTAssertEqual(r!.x, 1, accuracy: 1e-6)
        XCTAssertEqual(r!.y, 0, accuracy: 1e-6)
        XCTAssertEqual(r!.z, 0, accuracy: 1e-6)
    }

    func testLocalAxisRotatesWithBody() {
        // En local, el eje X del gizmo rotado 90° alrededor de Z → eje Y de mundo.
        let axis = SIMD3<Float>(1, 0, 0)
        let rot = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 0, 1))
        let r = TransformSnap.resolveAxis(axis, local: true, rotation: rot)
        XCTAssertEqual(r!.x, 0, accuracy: 1e-5)
        XCTAssertEqual(r!.y, 1, accuracy: 1e-5)
        XCTAssertEqual(r!.z, 0, accuracy: 1e-5)
    }

    func testLocalAxisIsNormalized() {
        let axis = SIMD3<Float>(2, 0, 0)   // sin normalizar
        let r = TransformSnap.resolveAxis(axis, local: true,
                                          rotation: simd_quatf(real: 1, imag: .zero))
        XCTAssertEqual(simd_length(r!), 1, accuracy: 1e-6, "el eje local se normaliza")
    }

    func testNilAxisPropagates() {
        // Drag libre (sin eje) se mantiene nil en ambos espacios.
        XCTAssertNil(TransformSnap.resolveAxis(nil, local: false,
                                               rotation: simd_quatf(real: 1, imag: .zero)))
        XCTAssertNil(TransformSnap.resolveAxis(nil, local: true,
                                               rotation: simd_quatf(real: 1, imag: .zero)))
    }

    // MARK: - Formateo de la lectura viva (tareas 1 / 4)

    func testReadoutLength() {
        XCTAssertEqual(TransformSnap.readout(1.5, kind: .length), "+1.50")
        XCTAssertEqual(TransformSnap.readout(-0.25, kind: .length), "-0.25")
    }

    func testReadoutAngleConvertsRadiansToDegrees() {
        XCTAssertEqual(TransformSnap.readout(.pi / 2, kind: .angle), "+90.0°")
        XCTAssertEqual(TransformSnap.readout(-.pi, kind: .angle), "-180.0°")
    }

    func testReadoutFactor() {
        XCTAssertEqual(TransformSnap.readout(1.25, kind: .factor), "×1.25")
        XCTAssertEqual(TransformSnap.readout(2.0, kind: .factor), "×2.00")
    }
}
