# Analisis de Arquitectura CAD: Undo/Redo + GeometryConstraintManager
> Fecha: 2026-04-29 | Proyecto: AppForge Studio

## Resumen Ejecutivo

Se verifico la infraestructura para Undo/Redo y Constraints en 6 archivos clave.
El 80% del andamiaje ya esta en su lugar pero falta conectar los botones UI y migrar la sheet de constraints.

## Hallazgos por Componente

### 1. OCCTEngine.swift (Core/Managers/)
- **Ruta:** `ios-app/AppForgeStudio/Core/Managers/OCCTEngine.swift`
- **Estado:** YA tiene `var historyTree = CADHistoryTree()` en la linea 6
- Opera con Shape (OCCTSwift). Exporta operaciones: createBox, union, subtract, fillet, extrude, revolve, sweep
- **Falta:** Las operaciones CAD no registran automaticamente en `historyTree` — habria que agregar `historyTree.addOperation(...)` en cada funcion

### 2. CADHistoryTree.swift (Core/Managers/)
- **Ruta:** `ios-app/AppForgeStudio/Core/Managers/CADHistoryTree.swift`
- **Estado:** Estructura completa con CADNode, arbol de operaciones, undo/redo funcionales
- Capacidades: `addOperation()`, `undo()` (retrocede al padre), `redo()` (avanza al hijo), `canUndo` (currentNode?.parent != nil), `canRedo` (currentNode?.children.count > 0)
- Ya soporta `getAllOperations()`, `clearHistory()`, y `findOperation(by:)`

### 3. Scene3D.swift (Models/)
- **Ruta:** `ios-app/AppForgeStudio/Models/Scene3D.swift`
- **Estado:** YA tiene `var cadHistory = CADHistoryTree()` y `var constraintManager = GeometryConstraintManager()`
- Scene3D expone ambos objetos directamente, accesibles desde canvasVM.scene

### 4. Model3D.swift (Models/)
- **Ruta:** `ios-app/AppForgeStudio/Models/Model3D.swift`
- **Estado:** YA tiene `var cadHistoryID: UUID?` y `var originOp: String?`
- Permite rastrear que operacion CAD origino cada modelo 3D

### 5. CADSketchEngine.swift (Features/CADMode/Tools/)
- **Ruta:** `ios-app/AppForgeStudio/Features/CADMode/Tools/CADSketchEngine.swift`
- **Estado:** YA tiene tanto `var constraintManager = GeometryConstraintManager()` como `var historyTree = CADHistoryTree()`
- El enum `Constraint` legacy y `@Published var constraints: [Constraint]` existen con `toGeometryConstraint()`
- **Pendiente:** Migrar @Published var constraints a computed property que lea de constraintManager.constraints. Code_agent intento esta migracion pero quedo como diff sin aplicar (error de permisos)

### 6. CADSketchView.swift (Features/CADMode/)
- **Ruta:** `ios-app/AppForgeStudio/Features/CADMode/CADSketchView.swift`
- **Estado:** La sheet de constraints actualmente itera sobre `sketchEngine.constraints` (el array legacy)
- **Pendiente:** Cambiar ForEach a `sketchEngine.constraintManager.constraints` y .onDelete a `constraintManager.removeConstraint(at:)`

### 7. CADModeView.swift (Features/CADMode/)
- **Ruta:** `ios-app/AppForgeStudio/Features/CADMode/CADModeView.swift`
- **Estado:** No tiene botones Undo/Redo. toolbarSection tiene transformTools + cadTools via ForEach
- **Pendiente:** Agregar 2 botones al inicio del HStack de toolbarSection con canvasVM.scene.cadHistory.undo()/redo()

### 8. GeometryConstraintManager.swift (Core/Managers/)
- **Ruta:** `ios-app/AppForgeStudio/Core/Managers/GeometryConstraintManager.swift`
- **Estado:** Completo y funcional. 2241 chars.
- Ofrece: addConstraint(), removeConstraint(at: UUID), removeConstraint(at: Int), updateConstraint(), toggleConstraint(), solve() (pendiente implementacion real)
- Tipos: horizontal, vertical, perpendicular, tangent, concentric, equal, distance, angle, midpoint, collinear

## Tareas Pendientes (Priorizadas)

### Alta Prioridad
1. **Botones Undo/Redo en CADModeView** — agregar al HStack de toolbarSection, llamando canvasVM.scene.cadHistory.undo()/redo() con disabled() por canUndo/canRedo
2. **Migrar CADSketchView sheet** — cambiar ForEach de sketchEngine.constraints a sketchEngine.constraintManager.constraints

### Media Prioridad
3. **Sincronizar operaciones OCCTEngine con historyTree** — agregar historyTree.addOperation() en cada metodo de OCCTEngine
4. **Convertir @Published var constraints a computed property** en CADSketchEngine para que lea de constraintManager.constraints

### Baja Prioridad
5. **Implementar solve() real en GeometryConstraintManager** — actualmente es stub
6. **UI de historial CAD** — arbol expandible de operaciones

## Resumen de Rutas Absolutas

| Archivo | Ruta | Estado |
|---------|------|--------|
| OCCTEngine.swift | C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Core\Managers\OCCTEngine.swift | historyTree OK, falta logging |
| CADHistoryTree.swift | C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Core\Managers\CADHistoryTree.swift | Completo |
| Scene3D.swift | C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Models\Scene3D.swift | cadHistory+constraintManager OK |
| Model3D.swift | C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Models\Model3D.swift | cadHistoryID+originOp OK |
| CADSketchEngine.swift | C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Features\CADMode\Tools\CADSketchEngine.swift | constraintManager+historyTree OK, falta migracion |
| CADSketchView.swift | C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Features\CADMode\CADSketchView.swift | Falta migrar a constraintManager |
| CADModeView.swift | C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Features\CADMode\CADModeView.swift | Faltan botones Undo/Redo |
| GeometryConstraintManager.swift | C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Core\Managers\GeometryConstraintManager.swift | Completo (con solve stub) |
