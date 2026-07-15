import Foundation
import simd
import OSLog
import Metal

// =============================================================================
// UIProbeMode — arnés de UI-testing por launch-argument (NO es UI de producto)
// =============================================================================
//
// HONESTIDAD (léelo antes de confiar en las capturas):
//   Este modo ejercita la CADENA REAL de lógica y render de la app:
//     view models (AppState / CanvasViewModel) → kernel B-rep (OCCT vía
//     BRepModeling / OCCTEngine) → malla (OCCTBridge) → Metal/Satin.
//   NO simula gestos táctiles crudos (pan/orbit/pinch con el dedo). El "feel"
//   táctil — inercia del orbit, hit-testing por toque, haptics — SOLO se
//   calibra en device real. Lo que ves aquí demuestra que el pipeline
//   geométrico-visual funciona de punta a punta, no que el gesto se siente bien.
//
// ACTIVACIÓN: exclusivamente por el launch-argument `-UIProbeMode`
//   (el workflow lo pasa como `simctl launch booted <bundleid> -UIProbeMode`).
//   En producción / uso normal el flag está ausente → `isActive == false` →
//   CERO efecto, CERO UI, CERO botones. Es un arnés, no una pantalla.
//
// PATRÓN: es el estándar de UI-testing por launch-arguments (el mismo que usan
//   los targets de UITest de Apple): la app detecta el flag al arrancar, sella
//   el onboarding, monta directo el workspace y corre una secuencia cronometrada
//   sobre los controllers/VM reales, logueando cada paso con `os_log` para que
//   las capturas externas (simctl screenshot cada ~3s) se puedan alinear al log.

private let probeLog = Logger(subsystem: "com.appforgestudio", category: "UIProbe")

@MainActor
enum UIProbeMode {

    /// Launch-argument que activa el arnés. Debe coincidir con el workflow.
    static let launchFlag = "-UIProbeMode"

    /// Clave REAL del gate de onboarding (verificada en AppForgeStudioApp.swift:
    /// `showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingComplete")`).
    static let onboardingDefaultsKey = "onboardingComplete"

    /// ¿Estamos corriendo bajo el arnés? Única fuente de verdad de la activación.
    /// En producción el flag no está → false → la app se comporta normal.
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(launchFlag)
    }

    /// Launch-argument que fuerza la clasificación pencil en el seam de MetalView.
    /// Permite que XCUITest sintetice un trazo con `forcePencil == true` en simulador,
    /// donde `touch.type == .pencil` nunca ocurre. Cero costo cuando el flag no está.
    static let forcePencilFlag = "-UIProbeForcePencil"

    /// true ↔ la app fue lanzada con `-UIProbeForcePencil`.
    /// Evaluado UNA VEZ en el seam `gestureRecognizer(_:shouldReceive:)`.
    static let forcePencil: Bool = ProcessInfo.processInfo.arguments.contains("-UIProbeForcePencil")

    /// Launch-argument del visualizador de toques (TouchVisualizer).
    /// Activa el overlay de círculos ember SOLO para sesiones XCUITest/tutorial.
    static let touchVizFlag = "-UIProbeTouchViz"

    /// true ↔ la app fue lanzada con `-UIProbeTouchViz`.
    static let touchVizActive: Bool = ProcessInfo.processInfo.arguments.contains("-UIProbeTouchViz")

    /// Launch-argument para saltar el onboarding SIN activar el arnés completo.
    /// G-A lanza la app con este arg para que quede lista para gestos libres
    /// sin que UIProbeMode mueva nada de la escena.
    static let skipOnboardingFlag = "-UIProbeSkipOnboarding"

    /// Segundos entre pasos: da margen a que las capturas externas (cada ~3s)
    /// atrapen el estado de cada paso y a que Metal reconstruya buffers GPU.
    static let stepInterval: Duration = .seconds(3)

    /// Descripción declarada de la secuencia (para el test ligero y para
    /// documentar qué ejercita el arnés). El índice = número de PROBE-STEP.
    static let declaredSteps: [String] = [
        "Sellar onboarding + montar workspace CAD (landscape)",
        "Crear caja B-rep (OCCT box) y añadirla a la escena",
        "Crear cilindro B-rep al lado de la caja",
        "Seleccionar la cara superior de la caja (faceIndex por normal +Y)",
        "Push/pull: extruir la cara superior de la caja +0.4",
        "Ghost EN VIVO: beginExtrude+update sobre una cara SIN commit (fantasma translúcido)",
        "Commit del ghost: hornear el push/pull real (sólido cambiado, sin fantasma)",
        "Boolean union caja ∪ cilindro (B-rep real)",
        "Re-encuadrar cámara (resetView) para la captura final",
    ]

    // -------------------------------------------------------------------------
    // Sellado del onboarding (paso obligatorio ANTES de montar la UI)
    // -------------------------------------------------------------------------

    /// Sella el flag REAL de onboarding para que el gate de entrada
    /// (`AppForgeStudioApp.showOnboarding`) evalúe a false y NO muestre el
    /// carrusel. Llamar en el `init` del `App`, antes de leer el @State.
    static func sealOnboarding() {
        UserDefaults.standard.set(true, forKey: onboardingDefaultsKey)
        probeLog.log("PROBE: onboarding sellado (\(onboardingDefaultsKey)=true)")
    }

    // -------------------------------------------------------------------------
    // Secuencia programada — opera sobre los VM / servicios REALES
    // -------------------------------------------------------------------------

    /// Lanza la secuencia cronometrada. NUNCA lanza ni crashea: cada paso está
    /// aislado; si algo falla, loguea "PROBE-FAIL paso N" y CONTINÚA.
    /// Se dispara desde la vista raíz del workspace con `.task { }` cuando
    /// `isActive`.
    static func run(appState: AppState) async {
        guard isActive else { return }
        probeLog.log("PROBE-STEP 0: arnés activo — inicia secuencia (\(declaredSteps.count) pasos)")

        let canvasVM = appState.canvasVM

        // Paso 1 — asegurar modo CAD (el workspace ya está montado en landscape).
        step(1, "montar workspace CAD (landscape)")
        appState.selectedMode = .cad
        await pause()

        // Paso 2 — CAJA B-rep real vía OCCTEngine, añadida a la escena.
        var boxIndex: Int? = nil
        do {
            step(2, "crear caja B-rep")
            if let boxModel = makeSolid(named: "ProbeBox",
                                        shape: OCCTEngine.shared.box(width: 1.4, height: 1.4, depth: 1.4)) {
                canvasVM.scene.addModel(boxModel)
                boxIndex = canvasVM.scene.models.count - 1
                canvasVM.selectedModelIndex = boxIndex
                canvasVM.objectWillChange.send()
            } else {
                fail(2, "OCCTEngine.box devolvió nil (OCCT no disponible?)")
            }
        }
        await pause()

        // Paso 3 — CILINDRO B-rep al lado de la caja (traslación horneada al B-rep).
        var cylIndex: Int? = nil
        do {
            step(3, "crear cilindro al lado")
            let rawCyl = OCCTEngine.shared.cylinder(radius: 0.5, height: 1.4)?
                .translated(by: SIMD3<Double>(1.6, 0, 0))
            if let cylModel = makeSolid(named: "ProbeCyl", shape: rawCyl) {
                canvasVM.scene.addModel(cylModel)
                cylIndex = canvasVM.scene.models.count - 1
                canvasVM.objectWillChange.send()
            } else {
                fail(3, "OCCTEngine.cylinder/translated devolvió nil")
            }
        }
        await pause()

        // Paso 4 — SELECCIÓN de cara: cara superior de la caja (normal +Y).
        // Selección programática = fijar el modelo seleccionado + resolver el
        // índice de cara por normal (el mismo camino que usa el push/pull real).
        var topFaceIndex: Int? = nil
        do {
            step(4, "seleccionar cara superior de la caja")
            if let bi = boxIndex, bi < canvasVM.scene.models.count,
               let shape = canvasVM.scene.models[bi].cadShape {
                canvasVM.selectedModelIndex = bi
                topFaceIndex = BRepModeling.faceIndex(of: shape,
                                                      withNormal: SIMD3<Double>(0, 1, 0))
                if topFaceIndex == nil {
                    fail(4, "no se halló cara con normal +Y (tolerancia)")
                } else {
                    probeLog.log("PROBE: cara superior = índice \(topFaceIndex!)")
                    canvasVM.objectWillChange.send()
                }
            } else {
                fail(4, "no hay caja B-rep para seleccionar cara")
            }
        }
        await pause()

        // Paso 5 — PUSH/PULL de la cara superior (+0.4) vía BRepModeling real.
        do {
            step(5, "push/pull cara superior +0.4")
            if let bi = boxIndex, bi < canvasVM.scene.models.count,
               let fi = topFaceIndex {
                let model = canvasVM.scene.models[bi]
                let ok = BRepModeling.applyFeature(to: model) { shape in
                    BRepModeling.pushPullFace(shape, faceIndex: fi, distance: 0.4)
                }
                if ok {
                    canvasVM.selectedModelIndex = bi
                    canvasVM.objectWillChange.send()
                } else {
                    fail(5, "applyFeature/pushPullFace no mutó (feature falló)")
                }
            } else {
                fail(5, "faltan índice de caja o de cara para push/pull")
            }
        }
        await pause()

        // Paso 6 — GHOST EN VIVO sobre una cara SIN commit (Ola LiveInteraction · L2
        // · tarea 7a). Ejercita LivePreviewEngine.beginExtrude + update REALES y monta
        // el fantasma `__livePreview` en la escena tal como lo hace CADModeView (el
        // probe no corre la SwiftUI View, así que inyectamos el modelo aquí). La
        // captura de este paso debe mostrar el fantasma translúcido sobre el sólido.
        //
        // FIX PROBE-FAIL 6/7: OCCT crea el cilindro a lo largo del eje Z, por lo que
        // su cara plana superior tiene normal (0,0,1), NO (0,1,0). Buscar (0,1,0)
        // devolvía nil → condicional fallaba → "no hay cilindro/cara superior".
        let ghostEngine = LivePreviewEngine()
        do {
            step(6, "ghost en vivo (beginExtrude+update, sin commit)")
            if let ci = cylIndex, ci < canvasVM.scene.models.count,
               let shape = canvasVM.scene.models[ci].cadShape,
               let topFI = BRepModeling.faceIndex(of: shape, withNormal: SIMD3<Double>(0, 0, 1)) {
                ghostEngine.beginExtrude(shape: shape, faceIndex: topFI,
                                         direction: SIMD3<Float>(0, 0, 1), initialDistance: 0)
                ghostEngine.update(parameter: 0.6)   // arrastre simulado: +0.6 en vivo
                if let ghostMesh = ghostEngine.previewMesh {
                    let ghost = Model(name: "__livePreview")
                    var mesh = ghostMesh
                    if let device = deviceForUpload() { mesh.uploadToGPU(device: device) }
                    ghost.meshes = [mesh]
                    ghost.color = SIMD4<Float>(1.0, 0.48, 0.27, 0.45)  // ember translúcido
                    ghost.edgesMesh = ghostEngine.previewEdges
                    canvasVM.scene.models.removeAll { $0.name == "__livePreview" }
                    canvasVM.scene.addModel(ghost)
                    canvasVM.objectWillChange.send()
                    probeLog.log("PROBE: fantasma `__livePreview` inyectado (cara \(topFI), dist 0.6)")
                } else {
                    fail(6, "LivePreviewEngine.previewMesh nil (OCCT no generó la malla ghost)")
                }
            } else {
                fail(6, "no hay cilindro/cara superior para el ghost en vivo")
            }
        }
        await pause()

        // Paso 7 — COMMIT del ghost (tarea 7b): retira el fantasma y hornea el push/pull
        // REAL en el cilindro. La captura de este paso debe mostrar el sólido cambiado
        // (sin fantasma): la geometría creció +0.6, ya no es una malla translúcida.
        // FIX: usar (0,0,1) igual que paso 6 — cilindro OCCT tiene eje Z.
        do {
            step(7, "commit del ghost → sólido real (sin fantasma)")
            canvasVM.scene.models.removeAll { $0.name == "__livePreview" }
            if let ci = cylIndex, ci < canvasVM.scene.models.count,
               let shape = canvasVM.scene.models[ci].cadShape,
               let topFI = BRepModeling.faceIndex(of: shape, withNormal: SIMD3<Double>(0, 0, 1)) {
                let model = canvasVM.scene.models[ci]
                let ok = BRepModeling.applyFeature(to: model) { s in
                    BRepModeling.pushPullFace(s, faceIndex: topFI, distance: 0.6)
                }
                if ok {
                    canvasVM.selectedModelIndex = ci
                    canvasVM.objectWillChange.send()
                    probeLog.log("PROBE: ghost horneado — cilindro creció +0.6 (fantasma retirado)")
                } else {
                    fail(7, "applyFeature/pushPullFace del commit no mutó")
                }
            } else {
                fail(7, "no hay cilindro/cara para hornear el commit")
            }
            canvasVM.objectWillChange.send()
        }
        await pause()

        // Paso 8 — BOOLEAN union caja ∪ cilindro (B-rep real, barato para 2 sólidos).
        do {
            step(8, "boolean union caja ∪ cilindro")
            if let bi = boxIndex, let ci = cylIndex,
               bi < canvasVM.scene.models.count, ci < canvasVM.scene.models.count {
                let a = canvasVM.scene.models[bi]
                let b = canvasVM.scene.models[ci]
                if let unionModel = BRepModeling.boolean(.booleanUnion, a, b) {
                    if let device = deviceForUpload() {
                        for i in unionModel.meshes.indices {
                            unionModel.meshes[i].uploadToGPU(device: device)
                        }
                    }
                    // Reemplazar los dos cuerpos por el resultado (índices altos
                    // primero para no invalidar el bajo al remover).
                    let hi = max(bi, ci), lo = min(bi, ci)
                    canvasVM.scene.models.remove(at: hi)
                    canvasVM.scene.models.remove(at: lo)
                    canvasVM.scene.addModel(unionModel)
                    canvasVM.selectedModelIndex = canvasVM.scene.models.count - 1
                    canvasVM.objectWillChange.send()
                } else {
                    fail(8, "BRepModeling.boolean devolvió nil (geometría degenerada?)")
                }
            } else {
                fail(8, "faltan índices de caja/cilindro para boolean")
            }
        }
        await pause()

        // Paso 9 — re-encuadre para la captura final (cámara isométrica limpia).
        do {
            step(9, "re-encuadrar cámara (resetView)")
            canvasVM.resetView()
            canvasVM.objectWillChange.send()
        }
        await pause()

        probeLog.log("PROBE-STEP \(declaredSteps.count): secuencia completa — idle")
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /// Construye un `Model` con B-rep + malla subida a GPU desde un `CADShape`.
    /// Devuelve nil si el shape es nil o la triangulación falla (sin crashear).
    private static func makeSolid(named name: String, shape: CADShape?) -> Model? {
        guard let shape, var mesh = OCCTBridge.toMesh(shape, quality: .medium) else { return nil }
        if let device = deviceForUpload() { mesh.uploadToGPU(device: device) }
        let model = Model(name: name)
        model.cadShape = shape
        model.meshes = [mesh]
        model.edgesMesh = OCCTBridge.edgesMesh(shape)
        return model
    }

    private static func deviceForUpload() -> MTLDevice? {
        MTLCreateSystemDefaultDevice()
    }

    private static func step(_ n: Int, _ desc: String) {
        probeLog.log("PROBE-STEP \(n): \(desc)")
    }

    private static func fail(_ n: Int, _ reason: String) {
        // El arnés NUNCA crashea: registra y continúa.
        probeLog.error("PROBE-FAIL paso \(n): \(reason)")
    }

    private static func pause() async {
        try? await Task.sleep(for: stepInterval)
    }
}
