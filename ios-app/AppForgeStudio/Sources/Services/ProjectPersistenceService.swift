import Foundation
import simd
import OCCTSwift
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "ProjectPersistence")

// MARK: - Metadata de proyecto

/// Metadatos JSON que acompañan al B-rep en el paquete .appforge
struct ProjectMetadata: Codable {
    var name: String
    var version: String = "2.0"
    var createdAt: Date
    var modifiedAt: Date
    var displayUnit: String  // "mm", "cm", "m", "inch"
    var gridStep: Double
    var cameraPosition: [Double]
    var cameraTarget: [Double]
    var modelCount: Int
    var operationCount: Int
    var appVersion: String
    var buildNumber: String
    /// Nombres y colores RGBA por modelo (v2.1) — opcionales para poder abrir
    /// proyectos guardados antes de este campo.
    var modelNames: [String]? = nil
    var modelColors: [[Double]]? = nil

    init(name: String,
         config: ProjectConfig,
         camera: Scene3D.Camera,
         modelCount: Int,
         operationCount: Int) {
        self.name = name
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.displayUnit = config.displayUnit.rawValue
        self.gridStep = config.gridStep
        self.cameraPosition = [Double(camera.position.x), Double(camera.position.y), Double(camera.position.z)]
        self.cameraTarget = [Double(camera.target.x), Double(camera.target.y), Double(camera.target.z)]
        self.modelCount = modelCount
        self.operationCount = operationCount
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Resultado de carga

struct LoadedProject {
    let metadata: ProjectMetadata
    let models: [Model]
    let config: ProjectConfig
    let camera: Scene3D.Camera
    var sourceURL: URL? = nil
}

// MARK: - Servicio de persistencia

/// Guarda y carga proyectos completos como paquetes .appforge.
/// Formato:
///   MiProyecto.appforge/
///     project.json        ← metadatos
///     config.json         ← unidades, grid, snapping
///     model_0.brep        ← geometría B-rep (OCCT nativo, sin pérdida)
///     model_0_edges.brep  ← aristas del modelo 0 (opcional)
///     model_1.brep
///     ...
///     history.json        ← árbol de features paramétrico
///
/// El formato .brep es el nativo de Open CASCADE — preserva NURBS,
/// tolerancias, y topología exacta. Cero pérdida vs STL/OBJ/STEP.
@MainActor
final class ProjectPersistenceService {
    static let shared = ProjectPersistenceService()

    private let fileManager = FileManager.default

    /// Extensión de paquete de proyecto
    static let packageExtension = "appforge"

    // MARK: - Save

    /// Guarda la escena completa como paquete .appforge
    func saveProject(
        name: String,
        scene: Scene3D,
        config: ProjectConfig = .default,
        to directory: URL
    ) throws -> URL {
        let projectURL = directory
            .appendingPathComponent(name)
            .appendingPathExtension(Self.packageExtension)

        // Crear directorio del paquete
        try? fileManager.removeItem(at: projectURL)
        try fileManager.createDirectory(at: projectURL,
                                        withIntermediateDirectories: true)

        // Guardar cada modelo como .brep. El nombre de archivo usa un contador
        // PROPIO (no el índice de escena): con overlays "__" en medio, el índice
        // de escena dejaba huecos (model_0, model_3, ...) y la carga secuencial
        // devolvía proyectos VACÍOS.
        var modelCount = 0
        var names: [String] = []
        var colors: [[Double]] = []
        for model in scene.models {
            guard !model.name.hasPrefix("__") else { continue }  // skip overlays
            guard let shape = model.cadShape else { continue }

            let brepURL = projectURL.appendingPathComponent("model_\(modelCount).brep")
            let brepData = try shape.brepData()
            try brepData.write(to: brepURL)
            names.append(model.name)
            colors.append([Double(model.color.x), Double(model.color.y),
                           Double(model.color.z), Double(model.color.w)])
            modelCount += 1

            logger.debug("Saved model \(modelCount - 1) (\(model.name)): \(brepData.count) bytes BREP")
        }

        // Guardar metadatos
        var meta = ProjectMetadata(
            name: name,
            config: config,
            camera: scene.camera,
            modelCount: modelCount,
            operationCount: scene.cadHistory.operationCount
        )
        meta.modelNames = names
        meta.modelColors = colors
        let metaURL = projectURL.appendingPathComponent("project.json")
        let metaData = try JSONEncoder.pretty.encode(meta)
        try metaData.write(to: metaURL)

        // Guardar configuración
        let configURL = projectURL.appendingPathComponent("config.json")
        let configData = try JSONEncoder.pretty.encode(config)
        try configData.write(to: configURL)

        logger.info("Project '\(name)' saved: \(modelCount) models, \(scene.cadHistory.operationCount) operations → \(projectURL.path)")

        return projectURL
    }

    // MARK: - Load

    /// Carga un proyecto desde un paquete .appforge.
    /// `nonisolated`: el trabajo pesado (BREP + teselado OCCT) DEBE poder correr
    /// fuera del main actor — con el servicio @MainActor, llamarlo desde un
    /// Task.detached rebotaba al main thread y el watchdog mataba la app
    /// (crash device 2026-07-16). No toca estado aislado: solo fileManager
    /// (let), decoders, OCCT y Models recién creados.
    nonisolated func loadProject(from projectURL: URL) throws -> LoadedProject {
        guard fileManager.fileExists(atPath: projectURL.path) else {
            throw ProjectError.fileNotFound(projectURL.path)
        }

        // Cargar metadatos
        let metaURL = projectURL.appendingPathComponent("project.json")
        let metaData = try Data(contentsOf: metaURL)
        let metadata = try JSONDecoder().decode(ProjectMetadata.self, from: metaData)

        // Cargar configuración
        let configURL = projectURL.appendingPathComponent("config.json")
        var config = ProjectConfig.default
        if fileManager.fileExists(atPath: configURL.path) {
            let configData = try Data(contentsOf: configURL)
            config = try JSONDecoder().decode(ProjectConfig.self, from: configData)
        }

        // Cargar modelos B-rep
        var models: [Model] = []
        for i in 0..<metadata.modelCount {
            let brepURL = projectURL.appendingPathComponent("model_\(i).brep")
            guard fileManager.fileExists(atPath: brepURL.path) else {
                logger.warning("model_\(i).brep not found, skipping")
                continue
            }
            guard let shape = try? CADShape.loadBREP(from: brepURL),
                  let mesh = OCCTBridge.toMesh(shape, quality: .medium) else {
                logger.warning("Failed to load BREP for model \(i)")
                continue
            }

            // Nombre y color originales (v2.1); fallback para proyectos viejos.
            let name = metadata.modelNames?[safe: i] ?? "Model_\(i)"
            let model = Model(name: name)
            model.cadShape = shape
            model.meshes = [mesh]
            model.edgesMesh = OCCTBridge.edgesMesh(shape)
            if let c = metadata.modelColors?[safe: i], c.count == 4 {
                model.color = SIMD4<Float>(Float(c[0]), Float(c[1]), Float(c[2]), Float(c[3]))
            }
            models.append(model)
        }

        // Reconstruir cámara
        let camera = Scene3D.Camera(
            position: SIMD3<Float>(metadata.cameraPosition.map { Float($0) }),
            target: SIMD3<Float>(metadata.cameraTarget.map { Float($0) }),
            up: SIMD3<Float>(0, 1, 0),
            fov: 45,
            nearPlane: 0.1,
            farPlane: 100
        )

        logger.info("Project '\(metadata.name)' loaded: \(models.count) models, unit=\(metadata.displayUnit)")

        return LoadedProject(
            metadata: metadata,
            models: models,
            config: config,
            camera: camera,
            sourceURL: projectURL
        )
    }

    // MARK: - Gestión de proyectos (galería de Inicio)

    /// Carpeta canónica de proyectos del usuario: Documents/Projects
    /// (visible en la app Archivos vía UIFileSharingEnabled si se habilita).
    var projectsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Projects", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Todos los paquetes .appforge de la carpeta de proyectos, con sus
    /// metadatos, ordenados por fecha de modificación (recientes primero).
    func listProjects() -> [(url: URL, metadata: ProjectMetadata)] {
        guard let items = try? fileManager.contentsOfDirectory(
            at: projectsDirectory, includingPropertiesForKeys: nil) else { return [] }
        var result: [(URL, ProjectMetadata)] = []
        for url in items where url.pathExtension == Self.packageExtension {
            let metaURL = url.appendingPathComponent("project.json")
            guard let data = try? Data(contentsOf: metaURL),
                  let meta = try? JSONDecoder().decode(ProjectMetadata.self, from: data) else { continue }
            result.append((url, meta))
        }
        return result.sorted { $0.1.modifiedAt > $1.1.modifiedAt }
    }

    /// Nombre libre para "Proyecto", "Proyecto 2", ... sin pisar existentes.
    func availableProjectName(base: String = "Proyecto") -> String {
        let existing = Set(listProjects().map { $0.metadata.name })
        if !existing.contains(base) { return base }
        var n = 2
        while existing.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    func deleteProject(at url: URL) throws {
        try fileManager.removeItem(at: url)
        var urls = recentProjects()
        urls.removeAll { $0 == url }
        if let data = try? JSONEncoder().encode(urls.map { $0.absoluteString }) {
            try? data.write(to: recentProjectsURL)
        }
    }

    /// Duplica el paquete con nombre "<nombre> copia" (metadata renombrada).
    @discardableResult
    func duplicateProject(at url: URL) throws -> URL {
        let newName = availableProjectName(base: url.deletingPathExtension().lastPathComponent + " copia")
        let newURL = projectsDirectory
            .appendingPathComponent(newName)
            .appendingPathExtension(Self.packageExtension)
        try fileManager.copyItem(at: url, to: newURL)
        // Renombrar dentro de los metadatos para que la galería muestre el nuevo nombre
        let metaURL = newURL.appendingPathComponent("project.json")
        if let data = try? Data(contentsOf: metaURL),
           var meta = try? JSONDecoder().decode(ProjectMetadata.self, from: data) {
            meta.name = newName
            meta.modifiedAt = Date()
            if let out = try? JSONEncoder.pretty.encode(meta) { try? out.write(to: metaURL) }
        }
        return newURL
    }

    // MARK: - Auto-save

    /// URL del auto-save temporal
    func autoSaveURL() -> URL {
        let tmp = fileManager.temporaryDirectory
        return tmp.appendingPathComponent("AppForge_Autosave")
            .appendingPathExtension(Self.packageExtension)
    }

    /// Guarda auto-save. El servicio es @MainActor (la escena vive en main):
    /// se agenda como Task de prioridad utility en el MISMO actor — antes se
    /// despachaba a un hilo global, saltándose el aislamiento de actor.
    func autoSave(name: String, scene: Scene3D, config: ProjectConfig = .default) {
        let url = autoSaveURL()
        Task(priority: .utility) { @MainActor in
            do {
                _ = try self.saveProject(name: name, scene: scene, config: config,
                                         to: url.deletingLastPathComponent())
                logger.info("Auto-save completed")
            } catch {
                logger.error("Auto-save failed: \(error.localizedDescription)")
            }
        }
    }

    /// Recupera el auto-save si existe
    func recoverAutoSave() -> LoadedProject? {
        let url = autoSaveURL()
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? loadProject(from: url)
    }

    /// Elimina el auto-save (al guardar manualmente o cerrar)
    func clearAutoSave() {
        let url = autoSaveURL()
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Recent projects

    private var recentProjectsURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("recent_projects.json")
    }

    func recentProjects() -> [URL] {
        guard let data = try? Data(contentsOf: recentProjectsURL),
              let urls = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return urls.compactMap { URL(string: $0) }
            .filter { fileManager.fileExists(atPath: $0.path) }
    }

    func markProjectOpened(_ url: URL) {
        var urls = recentProjects()
        urls.removeAll { $0 == url }
        urls.insert(url, at: 0)
        let limited = Array(urls.prefix(20))
        if let data = try? JSONEncoder().encode(limited.map { $0.absoluteString }) {
            try? data.write(to: recentProjectsURL)
        }
    }
}

// MARK: - Errores

enum ProjectError: LocalizedError {
    case fileNotFound(String)
    case invalidFormat(String)
    case missingBrepData(Int)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Proyecto no encontrado: \(path)"
        case .invalidFormat(let detail):
            return "Formato de proyecto inválido: \(detail)"
        case .missingBrepData(let index):
            return "Falta geometría del modelo \(index)"
        }
    }
}

// MARK: - Helpers

extension Array {
    /// Acceso sin crash para metadatos opcionales de proyectos viejos.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - JSON Helpers

extension JSONEncoder {
    static let pretty: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
