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

    /// El flag y la clave de onboarding sellada son las cadenas exactas que el
    /// workflow / el gate de entrada esperan (contrato con el mundo externo).
    func testContractConstants() {
        XCTAssertEqual(UIProbeMode.launchFlag, "-UIProbeMode")
        XCTAssertEqual(UIProbeMode.onboardingDefaultsKey, "onboardingComplete")
    }
}
