# Migracion Estructural AppForge Studio
> 2026-05-07 | Gotchi

## Resumen
Migracion completa de Sources/ (legacy) a Features/ + Core/ (moderno).

## Estado final — 2026-05-07
**Sources/ quedo VACIO** (solo RenderModeView.swift pendiente de eliminar, ya existe en Features/RenderMode/).

| Destino | Archivos | Origen |
|---------|----------|--------|
| Core/Engines/ | 45 archivos (unified: 10 CAD + 21 render + 10 sculpt + 4 animation/CAD) | Sources/CADCore/, Sources/RenderEngine/, Sources/SculptEngine/ |
| Core/Shaders/ | 4 .metal (PBR, IBL compute, IBL, Shaders) | Sources/RenderEngine/ |
| Core/UI/ | 25 archivos (App, Views, ViewModels) | Sources/UIComponents/ |
| Core/Services/ | 4 servicios + ExportService/ subdir | Sources/ExportService/ |
| Features/CADMode/ | 8 archivos (vistas + engines de sketch) | Mantenido (Sources/ dups eliminados) |
| Features/ExportMode/ | ExportView + ExportServiceSTEP | Sources/CADCore/ + Sources/ExportService/ |
| Features/PaintMode/ | PaintRenderer + MaterialEditorPBRView | Sources/CADCore/ |
| Features/RenderMode/ | RenderModeView | Mantenido |
| Features/AnimationMode/ | AnimationModeView | Mantenido (dup Sources/ respaldado) |
| Features/SculptMode/ | SculptModeView + Brushes/ | Mantenido |
| backup_sources/ | ~50 archivos respaldados | Todos los Sources/ |

## Fase 1 — COMPLETADA: Sources/CADCore/
- 10 engines → Core/Engines/ (Bevel, Boolean, Chamfer, Extrusion, Fillet, Loft, Measure, Shell, Sweep, SolverSwift)
- ExportServiceSTEP.swift → Features/ExportMode/
- MaterialEditorPBRView.swift → Features/PaintMode/
- 4 duplicados eliminados (CADSketchEngine, CADSketchView, CADTool, SketchTool)
- Backup en backup_sources_cadcore/

## Fase 2 — PENDIENTE: Sources/RenderEngine/ (25 archivos)
Archivos clave: PBRShaders.metal, IBLComputeShaders.metal, IBLPipeline.swift, Scene3D.swift, SatinRenderer.swift, OCCTEngine.swift, SDFEngine.swift, SubdivisionEngine.swift, PBRMaterial.swift, PBRMaterialUniforms.swift, MaterialEditorView.swift, Shaders.metal, Sketch2D.swift, Model3D.swift, Mesh.swift, LODManager.swift, BrushStroke.swift, PincelRenderer.swift, TestCube.swift, SceneRenderer.swift, SatinMesh.swift, SatinRendererView.swift, RenderModeView.swift, MaterialData.swift, MaterialPresets.swift
**Destino**: Core/Engines/ (engines) + features/RenderMode/ (vistas) + Core/Engine/ (shaders)

## Fase 3 — PENDIENTE: Sources/SculptEngine/ (11 archivos)
BrushEngine.swift (DUPLICADO en Core/Engines/), CreaseDeformer.swift, Deformer.swift, FlattenDeformer.swift, GrabDeformer.swift, InflateDeformer.swift, MoveDeformer.swift, PinchDeformer.swift, SculptEngine.swift, SmoothDeformer.swift, TwistDeformer.swift
**Destino**: Core/Engines/

## Fase 4 — PENDIENTE: Sources/ExportService/ (5 archivos)
CrashReporter.swift, ExportView.swift (DUPLICADO en Features/ExportMode/), ExportViewModel.swift, ModelCacheService.swift, ModelLoadService.swift
**Destino**: Features/ExportMode/ + Core/Services/

## Fase 5 — PENDIENTE: Sources/AnimationEngine/ (1 archivo)
AnimationModeView.swift
**Destino**: Features/AnimationMode/

## Fase 6 — PENDIENTE: Sources/UIComponents/ (25 archivos)
AppForgeStudioApp.swift, AppState.swift, ContentView.swift, ToolbarView.swift, etc.
**Destino**: Core/UI/ o mantener como Sources/

## Fase 7 — PENDIENTE: Documentacion
project_organize_docs para archivar ~22 docs obsoletos de abril 2026

## Duplicados detectados
| Archivo | Origen 1 | Origen 2 | Accion |
|---------|----------|----------|--------|
| ExportView.swift | Features/ExportMode/ | Sources/ExportService/ | Eliminar Sources/ |
| BrushEngine.swift | Core/Engines/ | Sources/SculptEngine/ | Comparar y mergear |
| AnimationEngine.swift | Core/Engines/ | (ya unico) | Verificado OK |
| CADSketchEngine.swift | Features/CADMode/ | Sources/CADCore/ | ELIMINADO |
| CADSketchView.swift | Features/CADMode/ | Sources/CADCore/ | ELIMINADO |
| CADTool.swift | Features/CADMode/ | Sources/CADCore/ | ELIMINADO |
| SketchTool.swift | Features/CADMode/ | Sources/CADCore/ | ELIMINADO |

## Estado actual
Sources/ vaciandose progresivamente. Backup en backup_sources_cadcore/.
Package.swift usa path="." — sin imports que romper.