# Estructura real del proyecto AppForgeStudio (iOS)

## Ubicacion real
`C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\`

## Sources/ activos (6 carpetas planas)
- `AnimationEngine/` — no listado aun
- `CADCore/` — ChamferEngine, FilletEngine, LoftEngine, ShellEngine, SweepEngine
- `ExportService/` — VACIO
- `RenderEngine/` — no listado aun
- `SculptEngine/` — no listado aun
- `UIComponents/` — no listado aun

## Core/ (funcionalidad compartida)
- `CAD/` — ConstraintEngine, SnapEngine
- `CSG/` — BSPNode, CSGOperation, Polygon3D, Shape
- `Engines/`
- `Managers/`
- `Services/`
- `Shaders/`
- `Theme/`
- `UI/`

## Features/ (modos de la app)
- AnimationMode, CADMode, ExportMode, HybridMode, PaintMode, RenderMode, SculptMode

## backup_sources/ (codigo sin restaurar)
64+ archivos incluyendo: ExportView, ExportViewModel, AnimationView, AnimationModeView, AppState, BrushEngine, SatinRenderer, Scene3D, SceneManager, SculptEngine, etc.

## Problemas identificados
1. ExportService/ en Sources/ esta vacio — codigo real en backup_sources/
2. AnimationEngine/ no listado aun
3. Features/CADMode/ no listado aun
4. Archivos CSG existen en Core/CSG/ pero falta ver si implementan logica booleana real
5. Shape.swift esta en Core/CSG/ y no en Sources/ — hay que ver Package.swift si lo incluye
