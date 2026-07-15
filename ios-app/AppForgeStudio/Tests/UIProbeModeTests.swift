import XCTest
@testable import AppForgeStudio

/// Blindaje del arnés UI-Probe: garantiza que NO se active en producción y que
/// su secuencia declarada existe. El arnés solo debe cobrar vida bajo el
/// launch-argument `-UIProbeMode` (el que pasa el workflow ui-probe.yml); en
/// cualquier corrida normal — incluida esta suite de tests — debe estar inerte.
@MainActor
final class UIProbeModeTests: XCTestCase {

    /// Con el flag AUSENTE (caso normal en CI/producción), el arnés está inactivo.
    /// Esta es la garantía de seguridad: sin el launch-argument, cero efecto.
    func testProbeInactiveWithoutLaunchFlag() {
        XCTAssertFalse(ProcessInfo.processInfo.arguments.contains(UIProbeMode.launchFlag),
                       "La suite de tests NO debe correr con -UIProbeMode")
        XCTAssertFalse(UIProbeMode.isActive,
                       "UIProbeMode debe estar INACTIVO sin el launch-argument (protege producción)")
    }

    /// La secuencia declarada de pasos no está vacía (el arnés tiene algo que hacer).
    func testDeclaredStepsAreNotEmpty() {
        XCTAssertFalse(UIProbeMode.declaredSteps.isEmpty,
                       "La secuencia de pasos del arnés no puede estar vacía")
        XCTAssertGreaterThanOrEqual(UIProbeMode.declaredSteps.count, 5,
                                    "Se esperan al menos los pasos núcleo (caja→cilindro→cara→push/pull→boolean)")
    }

    /// La ola LiveInteraction añadió 2 pasos: ghost en vivo SIN commit + commit del
    /// ghost. El arnés debe declararlos para que las capturas del agente Sonnet
    /// atrapen el fantasma translúcido y luego el sólido cambiado (tarea 7).
    func testLiveInteractionGhostStepsDeclared() {
        let joined = UIProbeMode.declaredSteps.joined(separator: " | ").lowercased()
        XCTAssertTrue(joined.contains("ghost") && joined.contains("sin commit"),
                      "debe existir el paso del ghost en vivo sin commit")
        XCTAssertTrue(joined.contains("commit del ghost"),
                      "debe existir el paso del commit del ghost")
        XCTAssertGreaterThanOrEqual(UIProbeMode.declaredSteps.count, 9,
                                    "9 pasos tras añadir los 2 de LiveInteraction")
    }

    /// El flag y la clave de onboarding sellada son las cadenas exactas que el
    /// workflow / el gate de entrada esperan (contrato con el mundo externo).
    func testContractConstants() {
        XCTAssertEqual(UIProbeMode.launchFlag, "-UIProbeMode")
        XCTAssertEqual(UIProbeMode.onboardingDefaultsKey, "onboardingComplete")
    }

    // MARK: - Blindaje Ola GestureProbe

    /// Sin `-UIProbeForcePencil` en args, `forcePencil` debe ser false.
    /// Garantiza que en producción el seam del pencil no fuerza nada.
    func testForcePencilFalseWithoutFlag() {
        XCTAssertFalse(ProcessInfo.processInfo.arguments.contains(UIProbeMode.forcePencilFlag),
                       "La suite de tests NO debe correr con -UIProbeForcePencil")
        XCTAssertFalse(UIProbeMode.forcePencil,
                       "forcePencil debe ser false sin el launch-argument (producción intacta)")
    }

    /// Sin `-UIProbeTouchViz` en args, el visualizador de toques no debe instalarse.
    func testTouchVizInactiveWithoutFlag() {
        XCTAssertFalse(ProcessInfo.processInfo.arguments.contains(UIProbeMode.touchVizFlag),
                       "La suite de tests NO debe correr con -UIProbeTouchViz")
        XCTAssertFalse(UIProbeMode.touchVizActive,
                       "touchVizActive debe ser false sin el launch-argument")
    }

    /// Sin `-UIProbeSkipOnboarding`, el flag extra no está presente.
    func testSkipOnboardingFlagAbsentInNormalRun() {
        XCTAssertFalse(ProcessInfo.processInfo.arguments.contains(UIProbeMode.skipOnboardingFlag),
                       "La suite de tests NO debe correr con -UIProbeSkipOnboarding")
    }

    /// Los strings de los flags del contrato son los exactos que usa G-A (XCUITest).
    func testGestureProbeContractFlags() {
        XCTAssertEqual(UIProbeMode.forcePencilFlag, "-UIProbeForcePencil")
        XCTAssertEqual(UIProbeMode.touchVizFlag, "-UIProbeTouchViz")
        XCTAssertEqual(UIProbeMode.skipOnboardingFlag, "-UIProbeSkipOnboarding")
    }
}
