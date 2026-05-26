# Diagnóstico de Estructura Real del Workspace
> 2026-05-07 — Gotchi

## Hallazgo #1: La app real está en ios-app/, NO en la raíz

El brain dice que el workspace es `C:\Users\USUARIO\Projects\appforge-studio\` pero el código real
está en `ios-app/AppForgeStudio/`. La raíz solo contiene:

- `Sources/CADCore/` — 5 engines CAD (Chamfer, Fillet, Loft, Shell, Sweep) — heredados
- `Hi-Rez-Satin/` — fork del framework Satin con Package.swift y .xcodeproj
- `docs/`, `_archive/`, `scripts/` — documentación y respaldos

## Hallazgo #2: Estructura real dentro de ios-app/AppForgeStudio/

```
ios-app/AppForgeStudio/
├── AppForgeStudio/        ← 3 archivos activos (App, SatinMesh, SatinRenderer)
├── Core/
│   ├── Engines/           ← 45 archivos (unified: CAD + render + sculpt + anim)
│   │   └── CAD: Bevel, Boolean, Chamfer, Extrusion, Fillet, Loft, Measure,
│   │       Shell, Sweep, SolverSwift, SDFEngine, OCCTEngine, Sketch2D
│   │   └── Render: SatinRenderer, SatinRendererView, SceneRenderer, IBLPipeline,
│   │       PBRMaterial, PBRMaterialUniforms, Scene3D, Mesh, Model3D, SubdivisionEngine
│   │   └── Sculpt: SculptEngine, BrushEngine, BrushStroke, PincelRenderer
│   │   └── Deform: Crease, Flatten, Grab, Inflate, Move, Pinch, Smooth, Twist
│   │   └── Animation: AnimationEngine, AnimationPlaybackController
│   │   └── UI: MaterialEditorView, MaterialData, MaterialPresets, LODManager
│   ├── Managers/          ← CADHistoryTree, OCCTEngine, PincelRenderer, SceneRenderer
│   ├── Services/          ← CrashReporter, ExportViewModel, ModelCacheService, ModelLoadService
│   ├── Shaders/           ← 4 .metal (PBRShaders, IBLShaders, IBLComputeShaders, Shaders)
│   ├── Theme/             ← AppTheme, AppThemeEnvironment, ThemeManager
│   └── UI/                ← AnimationView, AppState, ColorPickerView, GridView2, etc.
├── Features/
│   ├── CADMode/           ← CADModeView, CADSketchEngine, CADSketchView, CADTool, 
│   │                          ContentView, GeometryConstraintManager, SketchTool
│   │   └── Tools/         ← BevelEngine, BooleanEngine, CADToolEnum, ExtrusionEngine,
│   │                          LoopCutEngine, MeasureEngine, ToolViewModel
│   ├── AnimationMode/     ← AnimationModeView
│   ├── ExportMode/        ← ExportServiceSTEP, ExportView
│   ├── HybridMode/        ← HybridModeView
│   ├── PaintMode/         ← MaterialEditorPBRView, PaintRenderer
│   ├── RenderMode/        ← RenderModeView
│   └── SculptMode/        ← SculptModeView + Brushes/BrushEngine
├── Sculpting/
│   ├── Deformers/         ← 9 deformers (Crease, Flatten, Grab, Inflate, etc.)
│   └── SculptEngine.swift
├── Models/                ← BrushStroke, CADHistory, Mesh, Model, Model3D, Scene3D, TestCube
├── Views/                 ← no se exploró aún (presupuesto agotado)
├── ViewModels/            ← no se exploró aún
├── UI/                    ← no se exploró aún
├── Package.swift          ← Swift Package Manager
├── Resources/, Preview/, Tests/, Build/
└── backup_sources/        ← ~60 archivos duplicados de migración previa no completada
```

## Hallazgo #3: backup_sources/ contiene ~60 archivos redundantes

**Duplicados totales (ya existen activos en Core/ o Features/):**
- SatinMesh.swift, SatinRenderer.swift, SatinRendererView.swift, AppForgeStudioApp.swift
- Mesh.swift, Model3D.swift, Scene3D.swift, SceneRenderer.swift, IBLPipeline.swift
- PBRMaterial.swift, PBRMaterialUniforms.swift
- SculptEngine.swift, BrushEngine.swift, BrushStroke.swift
- Todos los deformers (Crease, Flatten, Grab, Inflate, Move, Pinch, Smooth, Twist)
- ExportViewModel.swift, ModelCacheService.swift, ModelLoadService.swift
- CrashReporter.swift, AppState.swift, AppTheme.swift
- PincelRenderer.swift, MaterialData.swift, MaterialPresets.swift
- AnimationView.swift, ColorPickerView.swift, GridView2.swift
- 4 .metal shaders (iguales a Core/Shaders/)

**Posibles únicos en backup_sources (no encontrados activos aún):**
- CanvasViewModel.swift, ExportView.swift, ContentView.swift, MaterialEditorView.swift
- MetalView.swift, ModeSelectorView.swift, OnboardingView.swift
- PreferencesView.swift, LoadingScreenView.swift, LayerPanelView.swift
- HapticService.swift, LODManager.swift
- AnimationModeView.swift, HybridModeView.swift
- Sketch2D.swift, SDFEngine.swift, OCCTEngine.swift, SubdivisionEngine.swift, TestCube.swift
- PBRMaterial.swift, MaterialEditorViewModel.swift

## Hallazgo #4: No hay .xcodeproj en ios-app — solo Package.swift

El proyecto se compila vía Swift Package Manager (`Package.swift` en ios-app/AppForgeStudio/).
Hi-Rez-Satin/ tiene su propio .xcodeproj para el framework fork.

## Conclusión

La migración estructural que describe el brain (Features/ + Core/ en raíz) NUNCA se ejecutó en disco.
Lo que existe es una estructura funcional dentro de ios-app/AppForgeStudio/ que ya tiene:
- Core/Engines/ unificado con 45 archivos
- Features/ con 7 modos (CAD, Animation, Export, Hybrid, Paint, Render, Sculpt)
- backup_sources/ con duplicados de una migración fallida

**Próximos pasos recomendados:**
1. Limpiar backup_sources/ (archivos redundantes)
2. Verificar qué archivos en backup_sources/ son ÚNICOS y deberían migrarse
3. Reubicar Views/, ViewModels/ y UI/ dentro de Core/UI/ y Features/
4. Sincronizar brain con la estructura real
