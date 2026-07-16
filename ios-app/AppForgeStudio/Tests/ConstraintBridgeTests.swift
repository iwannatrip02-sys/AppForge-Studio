import XCTest
import simd
import SketchKernel
@testable import AppForgeStudio

/// Fase 1: el puente al solver Newton-Raphson fue reemplazado por el motor de
/// snap e inferencia del kernel (la precisión nace al DIBUJAR, no corrigiendo
/// después). Estos tests fijan el feedback visual de snap del controlador.
@MainActor
final class SnapFeedbackTests: XCTestCase {

    func testSnapMarkerAppearsOnEndpoint() {
        let s = SketchController()
        s.beginTool(.line)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(2, 0))
        // Empezar nueva cadena tocando CERCA del extremo existente: el snap
        // engancha y publica el marcador
        s.beginTool(.line)
        s.tap(at: SIMD2(2.05, 0.05))
        XCTAssertEqual(s.snapMarker?.kind, .endpoint)
        // El punto quedó EXACTAMENTE en el extremo → topología compartida
        XCTAssertEqual(s.model.positions.count, 2,
                       "la nueva cadena arranca del punto existente, no de uno nuevo")
    }

    func testGuidesPublishedDuringDrag() {
        let s = SketchController()
        s.beginTool(.line)
        // Drag horizontal: la guía H del punto de anclaje debe publicarse
        s.pencilDragBegan(at: SIMD2(0, 0))
        s.pencilDragChanged(to: SIMD2(3, 0.05))
        XCTAssertFalse(s.guideSegments.isEmpty, "guía punteada H visible")
        XCTAssertEqual(s.preview?.y ?? 1, 0, accuracy: 1e-5,
                       "el cursor quedó encajado a la horizontal")
        s.pencilDragEnded(at: SIMD2(3, 0.05))
        // El segmento confirmado quedó perfectamente horizontal
        guard case .line(let a, let b) = s.entities.last?.kind,
              let pa = s.model.position(of: a), let pb = s.model.position(of: b) else {
            return XCTFail("esperaba línea")
        }
        XCTAssertEqual(pa.y, pb.y, accuracy: 1e-9, "línea H exacta gracias a la guía")
    }

    func testFeedbackClearsWhenCommitting() {
        let s = SketchController()
        s.beginTool(.circle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(1, 0))
        XCTAssertTrue(s.guideSegments.isEmpty, "sin guías tras confirmar")
        XCTAssertTrue(s.previewPolyline.isEmpty, "sin preview tras confirmar")
    }
}
