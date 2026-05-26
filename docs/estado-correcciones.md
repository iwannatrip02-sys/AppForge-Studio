# Estado de Correcciones Estructurales — 2026-04-30

## Archivos creados (10/10 tipos faltantes)
| Archivo | Ruta | Estado |
|---------|------|--------|
| CADTool.swift | Features/CADMode/ | Creado (12 casos) |
| SketchTool.swift | Features/CADMode/ | Creado (6 casos) |
| CADSketchEngine.swift | Features/CADMode/ | Creado (ObservableObject) |
| BrushEngine.swift | Core/Engines/ | Creado (ObservableObject) |
| GridView2.swift | UI/Components/ | Creado (Canvas grid) |
| ExportViewModel.swift | ViewModels/ | Creado (progress + formatos) |
| ContentView.swift | Features/CADMode/ | Creado (SatinView wrapper) |
| SatinMesh.swift | AppForgeStudio/ | Creado (Object subclass) |
| CSGEngine.swift | Core/Engines/ | Creado (union/merge) |
| ExportFormat enum | ViewModels/ExportViewModel | Creado (4 formatos) |

## Pendientes Batch 1 (code_agent refactor)
1. Renombrar Model3D -> Model (class ObservableObject)
2. Marcar Models/Model.swift como eliminado
3. Reescribir SatinRenderer (MTKViewDelegate, SatinMesh)
4. Actualizar ExportService (STEP manual + CSGEngine)
5. Actualizar ModelLoadService (class Model)
6. Actualizar CanvasViewModel (class Model)
7. Actualizar CADModeView (class Model)
8. Actualizar CADSketchView (class Model)
9. Actualizar Package.swift (exclusiones, resources)
