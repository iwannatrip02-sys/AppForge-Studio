# Estado Fase 6 — Paso 1: Correcciones Estructurales
> 2026-04-30 | Archivos creados: 10 | Modificados: 6 | Removidos: 2

## Archivos creados desde cero
1. `Features/CADMode/CADTool.swift` — enum con 12 tools CAD (select, move, extrude, booleanos, sketch)
2. `Features/CADMode/SketchTool.swift` — enum con 6 tools de sketch (line, arc, circle, rectangle, trim, extend)
3. `Features/CADMode/CADSketchEngine.swift` — ObservableObject con constraintManager integrado
4. `Core/Engines/BrushEngine.swift` — ObservableObject para pincel con stroke tracking
5. `UI/Components/GridView2.swift` — Canvas grid reutilizable
6. `ViewModels/ExportViewModel.swift` — ViewModel con progress bar + 4 formatos (STL, OBJ, USDZ, STEP)
7. `Features/CADMode/ContentView.swift` — SatinView UIViewRepresentable wrapper
8. `AppForgeStudio/SatinMesh.swift` — Subclase Object de Satin con vertex/index buffers Metal
9. `Core/Engines/CSGEngine.swift` — Operaciones booleanas: union (merge de vertices), subtract stub, intersect stub, mergeMeshes
10. `ViewModels/ExportViewModel.swift` — ExportFormat enum con STL/OBJ/USDZ/STEP

## Archivos modificados estructuralmente
1. **Models/Model3D.swift** — Renombrado a `class Model: ObservableObject` con @Published en 10 props
2. **AppForgeStudio/SatinRenderer.swift** — Reesecrito: ahora `MTKViewDelegate`, usa SatinMesh en vez de Mesh local, commandQueue propia
3. **Core/Services/ExportService.swift** — Agregado CSGEngine, STEP AP214 manual con CARTESIAN_POINT + POLYLOOP
4. **Package.swift** — Exclusiones: docs/, Resources/, Models/Model.swift, Models/CADHistory.swift
5. **Models/Model.swift** — Marcado como removido (comment)
6. **Models/CADHistory.swift** — Marcado como removido (comment)

## Error detectado en ExportService (a corregir)
- Línea `for mesh in mesh.meshes` debe ser `for mesh in model.meshes` en exportToSTEP

## Pendientes inmediatos
1. Corregir ExportService (mesh -> model)
2. Actualizar ModelLoadService (createMesh, PrimitiveType)
3. Actualizar CanvasViewModel (referencia a class Model)
4. Actualizar AppState (ExportViewModel init con ExportService)
5. Conectar GeometryConstraintManager a Scene3D
6. Conectar CADHistoryTree a UI de CADModeView

## Proximo paso: Batch 2 — ModelLoadService + CanvasViewModel + AppState
