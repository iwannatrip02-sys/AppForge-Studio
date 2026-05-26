# CAD Fase 1 - Plan de implementacion

> Basado en diagnostico del codigo existente (16 archivos CADCore)

## Arquitectura objetivo

AppForgeStudioApp (@main)
  +-- CADModeView
       +-- CADSketchView (PencilKit + toolbar 11 constraints)
       |    +-- CADSketchEngine
       |         +-- GeometryConstraintManager -> SolverSwift (NUEVO)
       |         +-- CADHistoryTree (conectado a CanvasViewModel.undoStack)
       +-- SatinRendererView -> SatinRenderer (PBR)
       |    +-- CanvasViewModel -> Scene3D
       +-- ToolViewModel

## Paso 1: SolverSwift (HOY)

Archivo: Sources/CADCore/SolverSwift.swift
- Reemplaza SolveSpaceSolver (solo structs vacios, sin binding C++ real)
- Metodo Newton-Raphson con Jacobiana analitica
- 11 tipos de constraint: horizontal, vertical, coincident, distance,
  angle, parallel, perpendicular, equal, midpoint, tangent, concentric
- Gauss-Seidel para sistema lineal con damping adaptivo

## Paso 2: GeometryConstraintManager update

- Cambiar solver.solveSystem() por solverSwift.solve()
- Traducir GeometryConstraint a SolverConstraint
- Mapear ConstraintType a SolverConstraintType

## Paso 3: Package.swift fix

- .executableTarget -> .target (iOS no usa executableTarget)
- Remover excludes que no existen (Models/Model.swift, etc.)
- Agregar OCCTSwift si BooleanEngine lo necesita (o marcar como comentado)

## Paso 4: ExtrusionEngine parametrico

- Registrar operacion en CADHistoryTree.beginOperation("extrude")
- Al cambiar sketch, regenerar extrusion via history tree
- Conectar CADHistoryTree con CanvasViewModel.undoStack

## Paso 5: Feature tree unificado

- CADHistoryTree de sketch mode conectado a undoStack de CanvasViewModel
- undo() en sketch mode: deshacer ultima operacion y regenerar escena
- redo() similar

## Orden de implementacion

1. SolverSwift.swift (crear archivo nuevo)
2. GeometryConstraintManager.swift (modificar)
3. Package.swift (corregir)
4. ExtrusionEngine.swift (hacer parametrico)
5. CADModeView.swift (conectar history tree a canvasVM)

---
*Plan generado 2026-05-06 basado en codigo real*