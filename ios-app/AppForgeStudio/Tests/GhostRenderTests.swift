import XCTest
import MetalKit
import simd
@testable import AppForgeStudio

/// Ola LiveInteraction · Carril L1 — sustrato de render del fantasma `__livePreview`.
///
/// Contrato verificado aquí:
///  (a) mutar la malla/transform del fantasma NO dispara `rebuildSceneFrom`
///      (fast-path in-place, espejo del refresh del sculpt) — `rebuildCount` estable.
///  (b) el export de una escena con `__livePreview`/`__faceHighlight` presentes NO
///      los incluye (ExportService filtra el prefijo `__`).
///  (c) el fantasma queda fuera del picking (convención `__` en ScenePicker).
///
/// Patrón espejo de RendererRegressionTests (mismo `rebuildCount`, mismo setUp Metal).
@MainActor
final class GhostRenderTests: XCTestCase {

    var device: MTLDevice!
    var renderer: SatinRenderer!

    override func setUp() {
        super.setUp()
        guard let dev = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal device required for ghost render tests")
            return
        }
        device = dev
        let mtkView = MTKView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), device: device)
        renderer = SatinRenderer(mtkView: mtkView)
    }

    override func tearDown() {
        renderer = nil
        device = nil
        super.tearDown()
    }

    // MARK: - (a) update in-place del fantasma no rebuildea

    /// Mutar la GEOMETRÍA del fantasma (nueva malla + geometryVersion++) no debe
    /// disparar `rebuildSceneFrom`: se refresca en sitio. Añadirlo la primera vez
    /// SÍ es un rebuild (cambia el conjunto de modelos, 1 vez por gesto).
    func testGhostMeshUpdateDoesNotRebuild() {
        let body = TestCube.build(name: "Body")
        let ghost = ghostModel()

        var scene = Scene3D()
        scene.addModel(body)
        scene.addModel(ghost)

        // Alta del fantasma: rebuild (conjunto de modelos cambió).
        renderer.updateScene(scene)
        let afterAdd = renderer.rebuildCount
        XCTAssertGreaterThanOrEqual(afterAdd, 1, "el alta del fantasma sí reconstruye una vez")

        // Frame de preview: el motor regenera la malla del fantasma y sube su versión.
        ghost.meshes = [Self.triangle(scale: 2.0)]
        ghost.geometryVersion += 1
        renderer.updateScene(scene)
        XCTAssertEqual(renderer.rebuildCount, afterAdd,
            "mutar la malla del fantasma se refresca in-place — sin rebuild")

        // Otro frame más: sigue sin rebuild.
        ghost.meshes = [Self.triangle(scale: 3.0)]
        ghost.geometryVersion += 1
        renderer.updateScene(scene)
        XCTAssertEqual(renderer.rebuildCount, afterAdd,
            "varios updates del fantasma no acumulan rebuilds")
    }

    /// Cambiar SOLO el transform del fantasma (posición) + versión no rebuildea.
    func testGhostTransformUpdateDoesNotRebuild() {
        let body = TestCube.build(name: "Body")
        let ghost = ghostModel()

        var scene = Scene3D()
        scene.addModel(body)
        scene.addModel(ghost)

        renderer.updateScene(scene)
        let baseline = renderer.rebuildCount

        ghost.position = SIMD3<Float>(0.5, 0, 0)
        ghost.geometryVersion += 1   // el código de inyección sube la versión al re-sincronizar
        renderer.updateScene(scene)
        XCTAssertEqual(renderer.rebuildCount, baseline,
            "mover el fantasma se refresca in-place — sin rebuild")
    }

    /// Control negativo: mutar un CUERPO real (no el fantasma) sí debe rebuildear —
    /// el fast-path es exclusivo del `__livePreview`, no relaja el resto.
    func testRealBodyGeometryChangeStillRebuilds() {
        let body = TestCube.build(name: "Body")
        let ghost = ghostModel()

        var scene = Scene3D()
        scene.addModel(body)
        scene.addModel(ghost)

        renderer.updateScene(scene)
        let baseline = renderer.rebuildCount

        body.meshes = [Self.triangle(scale: 5.0)]
        body.geometryVersion += 1
        renderer.updateScene(scene)
        XCTAssertEqual(renderer.rebuildCount, baseline + 1,
            "cambiar la geometría de un cuerpo real reconstruye (no es el fantasma)")
    }

    // MARK: - (b) el export filtra los overlays `__`

    /// El export de un modelo overlay (`__livePreview`/`__faceHighlight`) se rechaza:
    /// nunca deben acabar en un OBJ/STL/… entregado al usuario.
    func testExportRejectsGhostAndHighlightOverlays() {
        let exportService = ExportService(device: device)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Overlays con MALLA VÁLIDA (para probar que se filtran por NOMBRE, no por
        // estar vacíos): si el guard `__` no existiera, escribirían un archivo.
        let ghost = TestCube.build(name: "__livePreview")
        let highlight = TestCube.build(name: "__faceHighlight")

        for overlay in [ghost, highlight] {
            let url = tempDir.appendingPathComponent("\(overlay.name).obj")
            let result = exportService.export(model: overlay, format: .obj, to: url)
            if case .success = result {
                XCTFail("\(overlay.name) NO debe exportarse (overlay de escena)")
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                "no debe escribirse archivo para \(overlay.name)")
        }

        // Contraprueba: un cuerpo real del usuario sí exporta.
        let body = TestCube.build(name: "Body")
        let bodyURL = tempDir.appendingPathComponent("Body.obj")
        let bodyResult = exportService.export(model: body, format: .obj, to: bodyURL)
        guard case .success = bodyResult else {
            return XCTFail("un cuerpo real debe exportar correctamente")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: bodyURL.path))
    }

    // MARK: - (c) el fantasma queda fuera del picking

    /// La convención `__` de ScenePicker excluye el fantasma del hit-test: un rayo
    /// que atraviesa el fantasma NO lo golpea (no es geometría tocable).
    func testGhostExcludedFromPicking() {
        // Cubo unitario `__livePreview` centrado en el origen, en el camino del rayo.
        let ghost = TestCube.build(name: "__livePreview")

        // Rayo desde -Z hacia +Z, directo al centro: atraviesa el cubo si fuese tocable.
        let ray = CameraRay(origin: SIMD3<Float>(0, 0, -5),
                            direction: SIMD3<Float>(0, 0, 1))

        let hitGhostOnly = ScenePicker.hitTest(models: [ghost], ray: ray)
        XCTAssertNil(hitGhostOnly, "el fantasma `__livePreview` NO es tocable (prefijo `__`)")

        // Contraprueba: el mismo cubo con nombre normal SÍ se golpea.
        let solid = TestCube.build(name: "Body")
        let hitSolid = ScenePicker.hitTest(models: [solid], ray: ray)
        XCTAssertNotNil(hitSolid, "un cuerpo real en el camino del rayo sí es tocable")
    }

    // MARK: - Helpers

    /// Modelo fantasma no-PBR con malla válida (como lo inyecta el código de escena):
    /// nombre `__livePreview`, un triángulo con normales/uvs reales.
    private func ghostModel() -> Model {
        let m = Model(name: SatinRenderer.livePreviewName)
        m.meshes = [Self.triangle(scale: 1.0)]
        return m
    }

    /// Triángulo mínimo con normal y uv válidas (buildObject exige >0 vértices).
    private static func triangle(scale: Float) -> Mesh {
        let v: [Vertex] = [
            Vertex(position: SIMD3<Float>(0, 0, 0), normal: SIMD3<Float>(0, 0, 1), uv: SIMD2<Float>(0, 0)),
            Vertex(position: SIMD3<Float>(scale, 0, 0), normal: SIMD3<Float>(0, 0, 1), uv: SIMD2<Float>(1, 0)),
            Vertex(position: SIMD3<Float>(0, scale, 0), normal: SIMD3<Float>(0, 0, 1), uv: SIMD2<Float>(0, 1)),
        ]
        return Mesh(vertices: v, indices: [0, 1, 2])
    }
}
