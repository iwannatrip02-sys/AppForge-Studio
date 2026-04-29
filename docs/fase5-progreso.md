# Fase 5 — Constraints e History Tree

## Archivos creados

### `Core/Managers/CADHistoryTree.swift`
- Historial de operaciones CAD con undo/redo.
- `CADHistoryItem` almacena tipo, entidad ID, datos before/after, timestamp.
- `CADHistoryTree` implementa stack de undo/redo con capacidad configurable (default 50).
- Persistencia vía `save()`/`load()` con UserDefaults.
- Factory helpers: `makeAddEntityItem`, `makeRemoveEntityItem`, `makeModifyEntityItem`, `makeConstraintItem`.

### `Core/Managers/GeometryConstraintManager.swift`
- 10 tipos de constraints geométricos: horizontal, vertical, perpendicular, tangent, concentric, equal, distance, angle, midpoint, collinear.
- Solver iterativo (hasta 10 pasadas) que modifica posiciones de puntos.
- Solvers reales implementados:
  - Horizontal: fija Y de extremo igual a Y de inicio.
  - Vertical: fija X de extremo igual a X de inicio.
  - Perpendicular: rota línea B para que quede perpendicular a A.
  - Tangent: desplaza círculo para que sea tangente a línea.
  - Concentric: iguala centro de círculo B al de A.
  - Equal: iguala radios de círculos/arcos.
  - Distance: escala distancia entre 2 puntos al valor dado.
  - Angle: rota línea B para que forme ángulo dado con A.
  - Midpoint: mueve punto al punto medio entre 2 puntos.
  - Collinear: alinea 3 puntos.

## Integración pendiente

Se lanzó `code_agent` para integrar ambos módulos en:
- `OCCTEngine.swift` (history.push en cada operación, undo/redo)
- `Scene3D.swift` (constraintManager + resolveConstraints)
- `Model3D.swift` (ídem)
- `Mesh.swift` (constraintManager)
- `CADSketchEngine.swift` (resolveConstraints tras crear entidades, createConstraint)
- `CADModeView.swift` (botón Constraints)

Resultado del code_agent aún no disponible.

## Entregables pendientes para completar Fase 5
1. Verificar integración exitosa en los 6 archivos.
2. Tests unitarios de constraints (10 tipos).
3. Tests de undo/redo (push/pop/clear).
4. Actualizar GOTCHI.md con nuevo estado.