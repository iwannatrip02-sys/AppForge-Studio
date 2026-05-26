# CAD Baseline — Diagnostico del codigo existente

> Fecha: 2026-05-06 | Archivos leidos: 16 en CADCore/ + RenderEngine + UIComponents + Package.swift

## Arquitectura verificada

AppForgeStudioApp (@main)
  +-- CADModeView
       +-- CADSketchView (constraint toolbar + PencilKit canvas)
       |    +-- CADSketchEngine
       |         +-- GeometryConstraintManager (10 tipos: horiz, vert, dist, angle, etc.)
       |         |    +-- SolveSpaceSolver (ROTO - solo structs Slvs vacias, solveSystem() es stub)
       |         +-- CADHistoryTree (arbol undo/redo funcional con beginOperation/undo/redo)
       +-- SatinRendererView -> SatinRenderer (UIViewRepresentable)
       |    +-- CanvasViewModel -> Scene3D (undoStack, selectedModelIndex, currentMesh)
       +-- ToolViewModel (CADTool enum: 20 herramientas)

## Hallazgos clave

1. SolveSpaceSolver.swift NO funciona - 150 lineas con structs Slvs_Param/Entity/Constraint
   y constantes SLVS_RESULT_OKAY. solveSystem() es stub vacio. Sin binding C++ real.

2. CADSketchEngine + GeometryConstraintManager cableados a solver muerto -
   CADSketchEngine tiene @Published constraintManager que llama solver.solveSystem().
   Pipeline visual existe, solver no resuelve nada.

3. CADHistoryTree tiene undo/redo funcional con arbol de nodos (beginOperation, undo, redo).
   Pero no conectado a CanvasViewModel.undoStack (que usa Scene3D snapshots).

4. ExtrusionEngine NO es parametrico - trabaja a nivel de vertices/indices directamente,
   no registra operacion en CADHistoryTree. No se puede cambiar cota y regenerar.

5. Package.swift usa .executableTarget (deberia ser .target para iOS).
   Excluye Models/Model.swift y Models/CADHistory.swift que NO EXISTEN.
   OCCTSwift (BooleanEngine) no esta en dependencias.

## Decision: Solver Swift puro

NO usar SolveSpace C++. Implementar SolverSwift.swift con:
- Metodo Newton-Raphson con Jacobiana analitica
- 11 tipos de constraint: horizontal, vertical, coincident, distance, angle,
  parallel, perpendicular, equal, midpoint, tangent, concentric
- Damping adaptivo si residual empeora
- Max 100 iteraciones, tolerancia 1e-8

## Acciones inmediatas

1. CREAR Sources/CADCore/SolverSwift.swift
2. MODIFICAR GeometryConstraintManager para usar SolverSwift
3. CORREGIR Package.swift (.target en vez de .executableTarget)
4. MODIFICAR ExtrusionEngine para ser feature-based con CADHistoryTree
5. CONECTAR CADHistoryTree con CanvasViewModel.undoStack
