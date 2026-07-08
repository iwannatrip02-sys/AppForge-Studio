import XCTest
@testable import AppForgeStudio

/// Blindaje del cableado app → engines. El bug histórico: renderer.setSculptEngine
/// nunca se llamaba, así que el pipeline táctil de escultura (MetalView →
/// pendingStrokes → applySculpt) estuvo muerto desde el origen del repo.
@MainActor
final class AppStateWiringTests: XCTestCase {

    func testSculptEngineIsWiredIntoRenderer() {
        let state = AppState()
        XCTAssertNotNil(state.satinRenderer.sculptEngine,
                        "El SculptEngine debe estar inyectado en el renderer o esculpir con el dedo no hace nada")
        XCTAssertTrue(state.satinRenderer.sculptEngine === state.sculptEngine,
                      "El engine del renderer debe ser LA MISMA instancia que la del AppState (los controles de la UI mutan esa instancia)")
    }

    func testEveryAppModeHasAView() {
        // WorkspaceView.modeContent hace switch exhaustivo sobre AppMode; si se
        // añade un modo sin vista, esto no compila. El test documenta el contrato.
        XCTAssertEqual(AppState.AppMode.allCases.count, 6)
    }

    func testDeformerLabelsAreComplete() {
        for d in DeformerType.allCases {
            XCTAssertFalse(d.displayNameES.isEmpty, "Deformer \(d.rawValue) sin etiqueta de UI")
        }
    }
}
