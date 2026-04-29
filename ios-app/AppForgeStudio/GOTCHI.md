# AppForge Studio — iOS sub-proyecto
> Sub-proyecto de AppForge Studio. Reglas locales de iOS/Swift/Metal.
> Padre: `../../GOTCHI.md` (visión global, fases, KPIs).

## Stack local
- Swift 5.9+, SwiftUI (iOS 17+), Metal 2, Satin 0.3.0, ModelIO/MetalKit, simd.

## Estructura
- `AppForgeStudio/` — entry app (AppForgeStudioApp, SatinRenderer)
- `Core/Managers/` — render + animation engines (PaintRenderer, PincelRenderer, AnimationEngine, Shaders.metal)
- `Core/Services/` — ExportService, ModelLoadService
- `Core/ViewModels/` — ExportViewModel, ToolViewModel
- `Models/` — BrushStroke, Mesh, Model3D, Scene3D
- `Features/{CADMode,SculptMode,HybridMode,ExportMode}/` — vistas + lógica por modo
- `Sculpting/` — SculptEngine + Deformers (8)
- `UI/Components/` — MetalView, ContentView, SatinRendererView, ColorPickerView, ToolbarView
- `ViewModels/` — AppState, CanvasViewModel
- `Resources/` — assets

## Reglas de trabajo iOS
- `Scene3D` es **struct** — pasar por `inout` cuando se muta desde un engine (ver TODO.md → bug AnimationEngine).
- Cambios al pipeline Metal: validar con Xcode antes de marcar como hechos.
- Backup de Sources legacy en `../Sources_backup.zip` por si algo falta tras la migración del 2026-04-28.
