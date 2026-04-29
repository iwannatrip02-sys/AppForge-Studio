# Estructura Real — AppForge Studio
> Mapeo completo de archivos 2026-04-27

## ios-app/AppForgeStudio/ (codigo real)

### Raiz
- `Package.swift` — Define Satin 0.3.0, target path AppForgeStudio
- `AppForgeStudioApp.swift` — Entry point 3 modos (CAD, Sculpt, Hybrid)
- `SatinRenderer.swift` — Renderer con Satin framework

### Models/
- `BrushStroke.swift` — 10 brush types + StrokeMode (paint/sculpt/hybrid)
- `Mesh.swift` — Estructura Vertex, Mesh con uploadToGPU
- `Scene3D.swift` — Escena 3D con camara, luces, modelos

### Core/
#### Managers/
- `PaintRenderer.swift` — Pipeline Metal completo (vertex_main/fragment_main)
- `PincelRenderer.swift` — Clase StrokeRenderer con billboard quads
- `Shaders.metal` — Shaders vertex/fragment + stroke + compute
#### Services/
- `ExportService.swift` — Exportacion STL/OBJ via ModelIO (funcional)
- `ModelLoadService.swift` — Carga de modelos + primitivas (box, sphere, cylinder, plane, torus)
#### Models/
- (vacio — modelos principales en Models/ raiz)

### Features/
#### CADMode/
- `CADModeView.swift` — Toolbar con 9 herramientas CAD
- `Tools/` — Herramientas CAD individuales
#### SculptMode/
- `SculptModeView.swift` — UI con selector brushes + sliders + undo/redo
- `Brushes/BrushEngine.swift` — 10 brush types + applyDeformation + undo/redo
#### HybridMode/
- `HybridModeView.swift` — Switch entre submodos paint/sculpt

### UI/
#### Components/
- `ContentView.swift` — Camara orbital con quaternions, handleTouch
- `MetalView.swift` — Pipeline Metal, touchesBegan/Moved con raycast 3D
#### Navigation/
- (vacio)

### Preview/
### Resources/

## Archivos obsoletos / duplicados (NO existen en disco)
- `AppForgeStudio/AppForgeStudio/BrushEngine.swift` — No existe
- `AppForgeStudio/AppForgeStudio/ExportService.swift` — No existe
- `Services/ExportService.swift` (en raiz) — No existe, esta en Core/Services/

## Documentacion
- `ESTADO_ACTUAL.md` — Estado del proyecto
- `PLAN_ESTRATEGICO.md` — Roadmap 4 fases
- `GOTCHI.md` — Config del agente
- `plan_desarrollo.md` — Plan de desarrollo detallado

## Resumen
- **Total archivos Swift funcionales:** 17
- **Archivos en estructura real:** 18 (17 Swift + 1 .metal)
- **Carpetas vacias por implementar:** UI/Navigation/, Core/Models/
