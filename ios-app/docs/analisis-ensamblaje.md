# Analisis de ensamblaje — AppForge Studio iOS
> 2026-05-11 | Gotchi diagnostic

## Problema raiz
**Sources/AppForgeStudio** es un ARCHIVO, no un directorio. Package.swift espera que sea un directorio con `AppForgeStudioApp.swift` adentro. Eso impide que el proyecto compile.

## Que existe (resultados verificados)

### backup_sources/AppForgeStudio/ — 67 archivos COMPLETOS
- **Entry point**: AppForgeStudioApp.swift
- **Core/Engines/** (10+): PaintEngine, SculptEngine, AnimationEngine, PincelRenderer, PincelStrokes, etc.
- **Core/Managers/** (8+): SatinRenderer, SceneManager, PBRMaterial, IBLPipeline, LightManager, CameraManager, RenderPipelineManager, TextureManager
- **Core/Services/** (2): ExportService, ModelLoadService
- **Core/UI/** (4): ContentView (v2/v3), CanvasViewModel, CanvasState
- **Core/ViewModels/** (2): ExportViewModel, ToolViewModel
- **Features/** (7 modos): CADMode, SculptMode, HybridMode, ExportMode, AnimationMode, PaintMode, SettingsMode
- **Models/** (4): BrushStroke, Mesh, Model3D, Scene3D
- **Sculpting/** (9): SculptEngine + 8 deformers (Inflate, Flatten, Smooth, Grab, Pinch, Crease, Rotate, Scale)
- **UI/Components/** (6+): MetalView, ContentView v1, ColorPickerView, ToolbarView, SatinRendererView, etc.
- **ViewModels/** (2): AppState, CanvasViewModel v1
- **Resources/**: xib, storyboard, entitlements

### Package.swift targets correctos
AppForgeStudio → `Sources/AppForgeStudio/...`
PaintEngine → `Sources/PaintEngine/...`
SculptEngine → `Sources/SculptEngine/...`
AnimationEngine → `Sources/AnimationEngine/...`
ExportService → `Sources/ExportService/...`
ModelLoadService → `Sources/ModelLoadService/...`

### Lo que falta vs funcional
1. **CanvasViewModel.swift** — existe en backup como `CanvasState` pero no como ViewModel completo
2. **Conexion entry point → ContentView → CanvasViewModel** — existe en backup/AppForgeStudioApp.swift
3. **Shaders.metal** — NO encontrado en backup ni en Sources

## Plan de accion

### Fase 1 — Ensamblaje (AHORA)
1. Borrar `Sources/AppForgeStudio` (archivo)
2. Crear `Sources/AppForgeStudio/` como directorio
3. Mover los 67 archivos de `backup_sources/AppForgeStudio/` a `Sources/AppForgeStudio/`
4. Copiar shaders Metal a `Resources/Shaders/` si existen en el xcodeproj
5. Verificar que Package.swift compile

### Fase 2 — Cableado UI
1. Confirmar que ContentView v1 apunte a todos los 7 Features modes
2. Verificar que CanvasViewModel tenga bindings para Scene3D, tool selection, paint mode
3. Asegurar que SatinRenderer se inicialice desde ContentView

### Fase 3 — Funcional faltante
1. Shaders.metal — crear shaders basicos para PBR + IBL
2. Onboarding (no existe en ningun lado)
3. Undo/Redo stack (no existe)
4. Gestos multi-touch nativos
5. Exportacion funcional a STL/OBJ/STEP
