# Sintesis de Migracion: backup_sources vs Estructura Activa

Generado: 2026-05-07

## Estructura Activa (ya migrada y organizada)

### Core/
- Engines/
- Managers/
- Services/
- Shaders/
- Theme/
- UI/
- ViewModels/

### Features/
- AnimationMode/
- CADMode/
- ExportMode/
- HybridMode/
- PaintMode/
- RenderMode/
- SculptMode/

### Views/
- ExportView.swift (solo 1 archivo)

### ViewModels/
- AppState.swift
- CanvasViewModel.swift
- ExportViewModel.swift
- ToolViewModel.swift

### UI/Components/ (vacio por mapear)

### Models/
- BrushStroke.swift
- CADHistory.swift
- Mesh.swift
- Model.swift
- Model3D.swift
- Scene3D.swift
- TestCube.swift

### Sculpting/
- Deformers/
- SculptEngine.swift

### AppForgeStudio/
- AppForgeStudioApp.swift
- SatinMesh.swift
- SatinRenderer.swift

---

## Archivos en backup_sources/ NO presentes en activos

### Core Shaders (CRITICO — mas avanzados que activos)
- PBRShaders.metal — shaders PBR completos
- PBRMaterial.swift + PBRMaterialUniforms.swift — material system PBR
- IBLComputeShaders.metal + IBLPipeline.swift + IBLShaders.metal — Image Based Lighting
- Shaders.metal — shaders generales
- MaterialData.swift + MaterialPresets.swift — sistema de materiales
- LODManager.swift — Level of Detail

### Core Engines (CRITICO — no existen en activos)
- OCCTEngine.swift — OpenCASCADE CAD engine
- SDFEngine.swift — Signed Distance Fields engine
- BrushEngine.swift — engine de pinceles de pintura
- SubdivisionEngine.swift — subdivision de mallas

### Deformers (CRITICO — Sculpting/Deformers/ existe pero vacio)
- CreaseDeformer.swift
- FlattenDeformer.swift
- GrabDeformer.swift
- InflateDeformer.swift
- MoveDeformer.swift
- PinchDeformer.swift
- SmoothDeformer.swift
- TwistDeformer.swift
- Deformer.swift (protocolo base)

### Core Services/Managers (no existen en activos)
- SceneManager.swift
- SceneRenderer.swift
- ModelCacheService.swift
- ModelLoadService.swift
- HapticService.swift
- CrashReporter.swift
- ThemeManager.swift
- SatinRenderer.swift — version completa (activo tiene version minimalista)

### Views/UI (no existen en activos)
- ContentView.swift — vista principal
- ModeSelectorView.swift — selector de modo
- ToolbarView.swift — barra de herramientas
- ToolMenuView.swift + ToolViewModel.swift — menu de herramientas
- ColorPickerView.swift — selector de color
- LayerPanelView.swift — panel de capas
- MaterialEditorView.swift + MaterialEditorViewModel.swift — editor de materiales
- AnimationModeView.swift + AnimationView.swift + TimelineView.swift — modo animacion
- HybridModeView.swift — modo hibrido CAD+Sculpt
- MetalView.swift + SatinRendererView.swift — vistas de render
- TransformationGizmoView.swift — gizmo de transformacion
- GridView2.swift — grid 3D
- LoadingScreenView.swift — pantalla de carga
- OnboardingView.swift — onboarding
- PreferencesView.swift — preferencias
- PincelRenderer.swift — renderer de pinceles

### Modelos/Entidades (no existen en activos)
- Sketch2D.swift — bocetos 2D para CAD
- BrushStroke.swift — strokes de pincel (activo tiene version en Models/)

## Plan de Migracion Recomendado

### LOTE 1 — Core Shaders y Engines (prioridad ALTA)
1. PBRShaders.metal + PBRMaterial.swift + PBRMaterialUniforms.swift → Core/Shaders/
2. IBLComputeShaders.metal + IBLPipeline.swift + IBLShaders.metal → Core/Shaders/
3. Shaders.metal → Core/Shaders/
4. MaterialData.swift + MaterialPresets.swift → Core/Engines/ o Core/Services/
5. LODManager.swift → Core/Managers/
6. OCCTEngine.swift → Core/Engines/
7. SDFEngine.swift → Core/Engines/
8. BrushEngine.swift → Features/PaintMode/
9. SubdivisionEngine.swift → Core/Engines/

### LOTE 2 — Deformers (prioridad MEDIA)
10. Deformer.swift + 8 deformers → Sculpting/Deformers/

### LOTE 3 — Services/Managers (prioridad MEDIA)
11. SceneManager.swift + SceneRenderer.swift → Core/Managers/
12. ModelCacheService.swift + ModelLoadService.swift → Core/Services/
13. HapticService.swift → Core/Services/
14. CrashReporter.swift → Core/Services/
15. ThemeManager.swift → Core/Theme/

### LOTE 4 — Views/UI (prioridad ALTA — vistas completas)
16. ContentView.swift, ModeSelectorView.swift, ToolbarView.swift → UI/Components/
17. ToolMenuView.swift, ColorPickerView.swift, LayerPanelView.swift → UI/Components/
18. MaterialEditorView.swift + MaterialEditorViewModel.swift → UI/Components/
19. AnimationModeView.swift, AnimationView.swift, TimelineView.swift → Features/AnimationMode/
20. HybridModeView.swift → Features/HybridMode/
21. MetalView.swift, SatinRendererView.swift → Core/UI/
22. TransformationGizmoView.swift, GridView2.swift → UI/Components/
23. LoadingScreenView.swift, OnboardingView.swift, PreferencesView.swift → UI/Components/
24. PincelRenderer.swift → Features/PaintMode/

### LOTE 5 — Package.swift + Targets
25. Revisar Package.swift para incluir todos los nuevos archivos en el target
26. Verificar que AppForgeStudioApp.swift importe ContentView en lugar de lo que usa actualmente

## Notas Importantes
- backup_sources/ no tiene subdirectorios — todo es flat. Hay que distribuir organizadamente.
- Algunos archivos existen TANTO en activos como en backup (ej: AppState.swift, Scene3D.swift). Comparar versiones para quedarse con la mejor.
- Hay shaders Metal (.metal) que son archivos de recursos, no Swift — verificar que estén en Resources/ o junto a los .swift.
