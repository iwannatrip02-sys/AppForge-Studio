import XCTest
import simd
@testable import AppForgeStudio

/// Oráculo matemático de las matrices de cámara del renderer.
/// BUG histórico que este test blinda: el render usaba una cámara Satin creada en
/// init y jamás actualizada — scene3D.camera (la que mutan orbit/pan/zoom) nunca
/// llegaba a la GPU → viewport negro en device desde el origen del repo.
final class CameraMatrixTests: XCTestCase {

    private func defaultCam() -> Scene3D.Camera { .default }  // (0,0,3) → origen, fov 45

    /// Proyecta un punto de mundo a clip space con las matrices del renderer.
    private func clip(_ p: SIMD3<Float>, cam: Scene3D.Camera, aspect: Float = 1.5) -> SIMD4<Float> {
        let v = SatinRenderer.viewMatrix(for: cam)
        let pr = SatinRenderer.projectionMatrix(for: cam, aspect: aspect)
        return pr * v * SIMD4<Float>(p.x, p.y, p.z, 1)
    }

    func testOriginIsVisibleFromDefaultCamera() {
        // El objeto inicial vive en el origen; la cámara default está en (0,0,3).
        // Si esto falla, la app abre con viewport negro.
        let c = clip(.zero, cam: defaultCam())
        XCTAssertGreaterThan(c.w, 0, "w>0 = el punto está DELANTE de la cámara")
        let ndcZ = c.z / c.w
        XCTAssertGreaterThan(ndcZ, 0, "dentro del near plane")
        XCTAssertLessThan(ndcZ, 1, "dentro del far plane (NDC z∈[0,1], convención Metal)")
        XCTAssertEqual(c.x / c.w, 0, accuracy: 1e-5, "centrado en X")
        XCTAssertEqual(c.y / c.w, 0, accuracy: 1e-5, "centrado en Y")
    }

    func testPointBehindCameraIsRejected() {
        let c = clip(SIMD3<Float>(0, 0, 5), cam: defaultCam())  // detrás de (0,0,3)
        XCTAssertLessThan(c.w, 0, "w<0 = detrás de la cámara (clipping lo descarta)")
    }

    func testNearAndFarPlanesMapToNDCBounds() {
        let cam = defaultCam()  // near 0.1, far 100, mirando -Z desde (0,0,3)
        let nearPoint = clip(SIMD3<Float>(0, 0, 3 - cam.nearPlane), cam: cam)
        XCTAssertEqual(nearPoint.z / nearPoint.w, 0, accuracy: 1e-4, "near plane → NDC z=0")
        let farPoint = clip(SIMD3<Float>(0, 0, 3 - cam.farPlane), cam: cam)
        XCTAssertEqual(farPoint.z / farPoint.w, 1, accuracy: 1e-3, "far plane → NDC z=1")
    }

    func testOrbitingCameraChangesView() {
        // Mover la cámara DEBE cambiar la matriz de vista (el bug era una cámara
        // congelada: orbitar no tenía ningún efecto visual).
        var cam = defaultCam()
        let before = SatinRenderer.viewMatrix(for: cam)
        cam.position = SIMD3<Float>(3, 1, 0)
        let after = SatinRenderer.viewMatrix(for: cam)
        XCTAssertNotEqual(before, after, "orbitar debe mover la vista")
        // Y el origen sigue siendo visible desde la nueva posición
        let c = clip(.zero, cam: cam)
        XCTAssertGreaterThan(c.w, 0)
    }

    func testAspectRatioAffectsProjection() {
        let cam = defaultCam()
        let square = SatinRenderer.projectionMatrix(for: cam, aspect: 1.0)
        let wide = SatinRenderer.projectionMatrix(for: cam, aspect: 4.0 / 3.0)
        XCTAssertNotEqual(square.columns.0.x, wide.columns.0.x,
                          "el aspect ratio debe escalar X (el bug usaba aspect 1 fijo)")
    }
}
