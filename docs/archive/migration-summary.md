# Migration Summary — AppForge Studio
> 2026-05-07 | Gotchi (NanoAtlas Agent)

## Que se Hizo

### FASE 1 — Diagnostico Estructural
Se mapeo TODO el workspace: 67 archivos en backup_sources/ (flat), 16 en backup_sources_cadcore/, y la estructura activa en Core/ + Features/.

### FASE 2 — Comparacion Codigo
- PBRShaders.metal: backup == activo (mismo codigo PBR: Fresnel-Schlick, GGX, Smith)
- IBLPipeline.swift: backup == activo (misma pipeline irradiance+prefilter+BRDF)
- OCCTEngine.swift: backup == activo (mismas primitivas CAD)
- CADSketchEngine.swift: backup_cadcore == activo (mismo codigo comprimido)
- BrushEngine.swift: backup (134 lineas, 9 tipos pincel, undo/redo, Metal) >> activo (25 lineas). REEMPLAZADO.
- PincelRenderer: Managers/ tiene `StrokeRenderer` (nombre incorrecto, render de strokes) vs Engines/ tiene `PincelRenderer` (clase real de pincel). BUG.

### FASE 3 — Reubicacion
Directorios eliminados de la raiz (unificados en Core/):
- Views/ -> Features/ExportMode/
- ViewModels/ -> Core/ViewModels/ + Core/UI/
- Models/ -> Core/Engines/
- Sculpting/ -> Core/Engines/
- AppForgeStudio/ -> Core/UI/ + Core/Engines/
- UI/Components/ -> Core/UI/

## Estado Final

### Core/ (nucleo central, ~80 archivos):
- Engines/ (44): CAD(12) + Sculpt(2) + Deformers(8) + Animation(2) + Render(5) + Brush(2) + Data(7) + IBL + PBR + OCCT + SDF + Subdiv + Solver + Sketch2D + LOD
- Managers/ (6): CADHistoryTree + OCCTEngine(dup) + StrokeRenderer(dup name) + SceneRenderer(dup) + SubdivisionEngine(dup) + Shaders.metal(dup)
- Services/ (5): CrashReporter, ExportService/, ExportViewModel, ModelCacheService, ModelLoadService
- Shaders/ (4): IBLComputeShaders.metal, IBLShaders.metal, PBRShaders.metal, Shaders.metal
- Theme/ (3): AppTheme, AppThemeEnvironment, ThemeManager
- UI/ (25): Todas las vistas SwiftUI
- ViewModels/ (2): ExportViewModel, ToolViewModel

### Features/ (7 modos):
- CADMode/ (8+Tools/), AnimationMode/ (1), ExportMode/ (2), HybridMode/ (1), PaintMode/ (2), RenderMode/ (1), SculptMode/ (2+Brushes/)

### Package.swift:
Swift 6.0, target path: ".", exclude: ["docs/", "Resources/", "Models/Model.swift", "Models/CADHistory.swift"]
BUG: exclude refs Models/ que ya no existe como directorio.

## Lo Que Falta
1. Limpiar Core/Managers/ (5 duplicados de Engines/Shaders)
2. Renombrar StrokeRenderer en Managers/ si es legitimo, o eliminar
3. Actualizar exclude en Package.swift (quitar refs a Models/)
4. Mapear Features/HybridMode, PaintMode, RenderMode, SculptMode (tienen stubs, ver si backup_sources tiene mas)
5. backup_sources_cadcore/ revisar si MaterialEditorPBRView tiene algo que Core no tenga
6. Eliminar backup_sources/ y backup_sources_cadcore/ cuando se confirme
7. Verificar si SculptMode/Brushes/ tiene contenido