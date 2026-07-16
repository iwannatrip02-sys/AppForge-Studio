import XCTest
import MetalKit
@testable import AppForgeStudio

/// EL test que faltó durante meses: crea los pipelines de render DE VERDAD.
/// CAUSA RAÍZ del visor negro histórico: los shaders declaraban atributos
/// (color en basic; tangent/bitangent en PBR) que el vertex descriptor no
/// definía → makeRenderPipelineState fallaba → pipelines nil → CERO draws.
/// El error solo se logueaba a nivel .info y ningún test lo creaba.
@MainActor
final class RendererPipelineTests: XCTestCase {

    func testAllScenePipelinesBuild() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Sin dispositivo Metal en este entorno")
        }
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 64, height: 64), device: device)
        let renderer = SatinRenderer(mtkView: view)
        let d = renderer.diagnostics()

        XCTAssertTrue(d.libraryOK, "el metallib del bundle debe cargar")
        XCTAssertTrue(d.basicPipelineOK,
                      "pipeline básico nil = visor NEGRO (todos los modelos default son no-PBR)")
        XCTAssertTrue(d.pbrPipelineOK, "pipeline PBR nil = modelos PBR invisibles")
        XCTAssertTrue(d.sanityPipelineOK, "el pipeline de sanidad compila desde fuente")
    }

    func testSceneProducesRenderables() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Sin dispositivo Metal en este entorno")
        }
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 64, height: 64), device: device)
        let renderer = SatinRenderer(mtkView: view)

        // La escena inicial real de la app (cubo B-rep) debe producir geometría dibujable
        let vm = CanvasViewModel()
        renderer.updateScene(vm.scene)
        let d = renderer.diagnostics()
        XCTAssertGreaterThan(d.basicCount + d.pbrCount, 0,
                             "la escena inicial debe generar al menos 1 renderable")
        XCTAssertGreaterThan(d.totalIndices, 0, "con índices reales que dibujar")
    }
}
