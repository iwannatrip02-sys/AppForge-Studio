import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Persistencia .appforge (Inicio/galería): guardar → cargar debe devolver el
/// MISMO documento. Caza el bug real de 2026-07-13: los nombres de archivo
/// usaban el índice de escena y los overlays "__" dejaban huecos (model_0,
/// model_3, …) → la carga secuencial devolvía proyectos vacíos.
@MainActor
final class ProjectRoundtripTests: XCTestCase {

    private func makeBoxModel(name: String, color: SIMD4<Float>) throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))
        let model = Model(name: name)
        model.cadShape = shape
        model.meshes = [mesh]
        model.color = color
        return model
    }

    func testRoundtripPreservesModelsSkippingOverlaysWithoutGaps() throws {
        var scene = Scene3D()
        let base = try makeBoxModel(name: "Base", color: SIMD4<Float>(0.9, 0.2, 0.1, 1))
        let overlay = Model(name: "__gizmoX")   // overlay de UI: NO se persiste
        let tapa = try makeBoxModel(name: "Tapa", color: SIMD4<Float>(0.1, 0.5, 0.9, 1))
        scene.models = [base, overlay, tapa]

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rt_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = try ProjectPersistenceService.shared.saveProject(
            name: "RT", scene: scene, to: dir)
        let loaded = try ProjectPersistenceService.shared.loadProject(from: url)

        XCTAssertEqual(loaded.models.count, 2,
                       "el overlay se salta SIN dejar hueco en los archivos")
        XCTAssertEqual(loaded.models.map { $0.name }, ["Base", "Tapa"],
                       "los nombres sobreviven el roundtrip (antes se perdían)")
        XCTAssertEqual(loaded.models[0].color.x, 0.9, accuracy: 1e-3,
                       "el color sobrevive el roundtrip")
        let volOriginal = try XCTUnwrap(base.cadShape?.volume)
        let volLoaded = try XCTUnwrap(loaded.models[0].cadShape?.volume)
        XCTAssertEqual(volLoaded, volOriginal, accuracy: 1e-6,
                       "el B-rep es sin pérdida (volumen idéntico)")
        XCTAssertNotNil(loaded.models[0].edgesMesh, "los sólidos cargan con aristas")
        XCTAssertEqual(loaded.sourceURL, url)
    }

    func testListDuplicateAndDeleteProjects() throws {
        let svc = ProjectPersistenceService.shared
        var scene = Scene3D()
        scene.models = [try makeBoxModel(name: "Solo", color: SIMD4<Float>(1, 1, 1, 1))]

        let name = "TestGaleria_\(UUID().uuidString.prefix(6))"
        let url = try svc.saveProject(name: name, scene: scene, to: svc.projectsDirectory)
        defer { try? svc.deleteProject(at: url) }

        XCTAssertTrue(svc.listProjects().contains { $0.metadata.name == name },
                      "el proyecto guardado aparece en la galería")

        let copy = try svc.duplicateProject(at: url)
        defer { try? svc.deleteProject(at: copy) }
        // Comparar por PATH estandarizado: contentsOfDirectory devuelve URLs de
        // directorio con slash final y URL == las considera distintas.
        let copyPath = copy.standardizedFileURL.path
        let copyMeta = svc.listProjects()
            .first { $0.url.standardizedFileURL.path == copyPath }?.metadata
        XCTAssertNotNil(copyMeta, "el duplicado aparece en la galería")
        XCTAssertNotEqual(copyMeta?.name, name, "el duplicado tiene nombre propio")

        try svc.deleteProject(at: copy)
        XCTAssertFalse(svc.listProjects().contains {
            $0.url.standardizedFileURL.path == copyPath
        }, "eliminar lo quita de la galería y del disco")
    }
}
