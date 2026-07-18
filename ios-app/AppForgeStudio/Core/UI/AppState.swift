import SwiftUI
import Combine
import Metal
import Satin
import MetalKit
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "AppState")
@MainActor
class AppState: ObservableObject {
    @Published var selectedMode: AppMode = .cad
    @Published var isLoading: Bool = true
    @Published var isDarkMode: Bool = true
    @Published var showExport: Bool = false
    
    func toggleDarkMode() {
        isDarkMode.toggle()
    }
    let themeManager: ThemeManager
    let canvasVM: CanvasViewModel
    let toolVM: ToolViewModel
    let modelCache: ModelCacheService
    let modelLoader: ModelLoadService
    let exportVM: ExportViewModel
    lazy var animationVM: AnimationEngine = {
        AnimationEngine()
    }()
    let subdivisionVM: SubdivisionEngine
    /// Motor de escultura compartido — inyectado al renderer para que el
    /// pipeline táctil (MetalView → pendingStrokes → applySculpt) esté vivo.
    let sculptEngine = SculptEngine()
    /// Capas del modo híbrido (CAD/Sculpt/Paint sobre el mismo modelo).
    let layerManager = LayerManager()
    lazy var materialEditorVM: MaterialEditorViewModel = {
        MaterialEditorViewModel(canvasVM: canvasVM)
    }()
    var satinRenderer: SatinRenderer

    func setRenderer(_ renderer: SatinRenderer) {
        self.satinRenderer = renderer
        renderer.setSculptEngine(sculptEngine)
        renderer.animationEngine = animationVM
        self.canvasVM.animationEngine = animationVM
        renderer.onTransformsApplied = { [weak self] transforms in
            guard let self = self else { return }
            var scene = self.canvasVM.scene
            for (modelId, transform) in transforms {
                if let idx = scene.models.firstIndex(where: { $0.id.uuidString == modelId || $0.name == modelId }) {
                    scene.models[idx].transform = transform
                }
            }
            self.canvasVM.scene = scene
        }
        animationVM.onFrame = { [weak self] _, transforms in
            guard let self = self else { return }
            var scene = self.canvasVM.scene
            for (modelId, transform) in transforms {
                if let idx = scene.models.firstIndex(where: { $0.id.uuidString == modelId || $0.name == modelId }) {
                    scene.models[idx].transform = transform
                }
            }
            self.canvasVM.scene = scene
        }
    }

    enum AppMode: String, CaseIterable {
        case cad = "CAD"
        case sculpt = "Sculpt"
        case paint = "Paint"
        case hybrid = "Hybrid"
        case animation = "Animation"
        case render = "Render"
    }

    init() {
        self.themeManager = ThemeManager()
        self.canvasVM = CanvasViewModel()
        self.toolVM = ToolViewModel()
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal no soportado en este dispositivo")
        }
        self.modelCache = ModelCacheService(device: device)
        self.modelLoader = ModelLoadService(device: device, cacheService: modelCache)
        self.exportVM = ExportViewModel(exportService: ExportService(device: device))
        self.subdivisionVM = SubdivisionEngine(device: device)
        
        let dummyView = MTKView(frame: .zero, device: device)
        let renderer = SatinRenderer(mtkView: dummyView)
        self.satinRenderer = renderer
        setRenderer(renderer)
    }

    var scene: Scene3D { canvasVM.scene }
    var strokes: [BrushStroke] { canvasVM.scene.strokes }

    // MARK: - Proyecto actual (Inicio/galería — catálogo §5)

    @Published var currentProjectURL: URL?
    @Published var currentProjectName: String = "Proyecto"

    /// Documento nuevo: escena limpia con nombre libre ("Proyecto", "Proyecto 2"…).
    func newProject() {
        var scene = canvasVM.scene
        scene.models.removeAll()
        canvasVM.scene = scene
        currentProjectName = ProjectPersistenceService.shared.availableProjectName()
        currentProjectURL = nil
        canvasVM.objectWillChange.send()
    }

    /// True mientras un proyecto se carga en background (la galería puede
    /// mostrar spinner; el canvas aparece vacío y se puebla al terminar).
    @Published var isOpeningProject = false

    /// Abre un .appforge de la galería: modelos B-rep + cámara + nombre.
    ///
    /// CRÍTICO (crash device 2026-07-16): cargar el BREP + teselarlo con OCCT
    /// tomaba >5s y corría en el MAIN THREAD → iOS mataba la app por watchdog
    /// (0x8BADF00D) — el proyecto del usuario quedó inabrible (5 crashes
    /// seguidos en los logs del iPad). La carga va ahora en un hilo de fondo;
    /// la escena se aplica en el main actor al terminar.
    func openProject(at url: URL) {
        guard !isOpeningProject else { return }
        isOpeningProject = true
        Task { [weak self] in
            let loaded = await Task.detached(priority: .userInitiated) {
                try? ProjectPersistenceService.shared.loadProject(from: url)
            }.value
            guard let self else { return }
            self.isOpeningProject = false
            guard let loaded else {
                logger.error("No se pudo abrir el proyecto en \(url.path)")
                return
            }
            var scene = self.canvasVM.scene
            scene.models = loaded.models
            scene.camera = loaded.camera
            self.canvasVM.scene = scene
            self.currentProjectName = loaded.metadata.name
            self.currentProjectURL = url
            ProjectPersistenceService.shared.markProjectOpened(url)
            self.canvasVM.objectWillChange.send()
        }
    }

    /// Guarda el documento actual en la carpeta canónica de proyectos.
    func saveCurrentProject() {
        let dir = ProjectPersistenceService.shared.projectsDirectory
        do {
            let url = try ProjectPersistenceService.shared.saveProject(
                name: currentProjectName, scene: canvasVM.scene, to: dir)
            currentProjectURL = url
            ProjectPersistenceService.shared.markProjectOpened(url)
        } catch {
            logger.error("Guardado falló: \(error.localizedDescription)")
        }
    }
}