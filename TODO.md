# TODO - AppForge Studio
> Pendientes accionables. Reescrito post-sesion por Gotchi.
> Updated: 2026-04-29 22:01 UTC

## Foco actual
- Fase 4 completada (animacion keyframes + onboarding + pipeline CI/CD)
- Siguiente: compilar localmente + push para build en GitHub Actions + instalacion en iPad via AltStore

## Pendientes

### PENDIENTE - Correcciones post-Fase 4
- ~~**Eliminar archivos temporales**: ya eliminados~~
- ~~**Implementar exportModel() real**: ExportViewModel.exportModel() (112 lineas, conectado a ExportService real)~~
- ~~**Conectar AnimationView**: Integrado como 5to modo en AppForgeStudioApp~~
- **Compilar localmente**: Verificar build con Xcode antes de push

### COMPLETADO - Correcciones estructurales Fase 4
- ~~**Model.swift unificado**: Con id, color, cadHistoryID, originOp~~ ✅
- ~~**ExportView refactorizada a MVVM**: Usa exportVM.selectedModel~~ ✅
- ~~**AnimationView creada**: En UI/Components/ con controles de reproduccion~~ ✅
- ~~**AppState consolidado**: Unico en ViewModels/, eliminado Core/AppState.swift~~ ✅
- ~~**Archivo de estado**: docs/estado-post-correcciones.md con verificacion completa~~ ✅


### COMPLETADO - Fase 4A (3 bugs corregidos)
- ~~**Bug SatinRenderer.updateScene inout** - Arreglado: firma cambiada a inout Scene3D. SatinRendererView.swift actualizado (3 llamadas con &)~~ ✅
- ~~**Bug BooleanEngine en ToolViewModel** - Arreglado: caso .boolean ahora une malla con copia desplazada 0.15 en X~~ ✅
- ~~**Bug BevelEngine seleccion aristas** - Arreglado: ahora desplaza puntos hacia el centro de la arista y conecta triangulos correctamente~~ ✅

### COMPLETADO - Fase 4B (4 features)
- ~~**Revolve desde sketch**: Boton Revolve en SketchView, genera solido de revolucion (16 segmentos, eje Y, 360)~~ ✅
- ~~**Primitivas parametricas**: Sliders en CADModeView para Box/Cylinder/Sphere~~ ✅
- ~~**Mediciones reales**: MeasureEngine con distancia entre vertices y area de caras~~ ✅

### COMPLETADO - Fase 4C (5 features)
- ~~**Lofts/sweeps**: OCCTEngine.loft() y OCCTEngine.sweep() con UI en CADModeView~~ ✅
- ~~**Shell (vaciado)**: Boton Shell con slider de espesor, conectado a OCCTEngine.shell()~~ ✅
- ~~**Integrar OCCTEngine real**: meshToShape/shapeToMesh bridge en OCCTEngine~~ ✅
- ~~**Fillet/Chamfer UI**: Botones en toolbar con sliders de radio~~ ✅
- ~~**Conectar MeasureEngine con OCCTEngine**: Mediciones CSG reales via OCCTEngine~~ ✅

### COMPLETADO - Fase 4D (Exportacion completa)
- ~~**ExportService reescrito**: exportToSTEP (via OCCTEngine.meshToShape), exportToUSDZ, manejo de errores real~~ ✅
- ~~**ExportViewModel con 4 formatos**: OBJ, STL, STEP, USDZ con iconos SF Symbols~~ ✅
- ~~**ExportView sin duplicacion**: LazyVGrid visual, ProgressView, fileExporter con ExportFileData~~ ✅

### COMPLETADO - Sesion 2026-04-29 (Pipeline CI/CD)
- ~~**Workflow build-ios.yml**: Creado en .github/workflows/. Compila .ipa en GitHub Actions con macos-14. Sin firma (CODE_SIGNING_ALLOWED=NO).~~ ✅
- ~~**Docs pipeline**: compilacion-desde-windows.md + compilacion-instalacion-ipad.md con paso a paso AltStore~~ ✅
- ~~**Animacion keyframes UI**: AnimationEngine.swift con @Published keyframes, TimelineView.swift con AddKeyframeSheet~~ ✅
- ~~**Onboarding tutorial**: OnboardingView.swift con 3 paginas, persistencia UserDefaults, conectado a AppForgeStudioApp.swift~~ ✅
- ~~**Decisiones registradas**: DECISIONS.md actualizado con entrada 2026-04-29 pipeline Windows->iPad~~ ✅
- ~~**Resumen CI/CD**: docs/resumen-ci-pipeline.md con resumen del pipeline~~ ✅

### ALTA - Fase 5 (Testing integral)
- **Push a main** del repo para triggerear build en GitHub Actions y verificar que compila
- **Instalar AltStore** en iPad desde AltServer en Windows
- **Cargar .ipa** desde GitHub Actions artifacts al iPad via AltStore
- **Probar flujo completo**: CAD (sketch/revolve) -> escultura -> pintura -> animacion -> exportacion STL
- FASE 5: UI polishing y onboarding
- Mejorar OnboardingView con animaciones de transicion y tutorial interactivo
- Pulir ExportView: progress bar circular, animacion de exito, preview del modelo
- Unificar toolbar entre modos: estilos consistentes, iconografia, atajos
- Mejorar AnimationView: keyframes draggeables, curvas de easing, loop toggle

## Bloqueos
(ninguno)

## Completados
(ninguno)
