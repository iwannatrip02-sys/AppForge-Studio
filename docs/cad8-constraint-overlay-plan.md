# CAD-8: Constraint Visualization Overlay

## Que falta
El parametricTab de CADModeView tiene Operation Timeline pero NO muestra constraints activos.

## Archivos a crear
1. Features/CADMode/ConstraintOverlayView.swift — SwiftUI view
   - Lista de constraints activos con iconos por tipo (horizontal=→, vertical=↓, tangent=◯, concentric=◎, etc.)
   - Color coding: verde (solved), rojo (failed), gris (inactive)
   - Boton toggle para mostrar/ocultar overlay en la escena
   - Binding al constraintManager del sketchEngine

## Archivos a modificar
2. Features/CADMode/CADModeView.swift — parametricView
   - Agregar seccion "Constraints" debajo de Operation Timeline
   - Usar ConstraintOverlayView con sketchEngine.constraintManager
   - Boton "Show/Hide Constraints"

## Data flow
- GeometryConstraintManager.shared.constraints → ConstraintOverlayView
- ConstraintType enum con rawValue String para display
- SolverMetrics (iterationCount, residual, converged) para status
