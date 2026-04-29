# Fase 2 — Implementada
> 2026-04-27 18:59 UTC

## Cambios realizados

### 1. BrushEngine.swift — canUndo/canRedo
- Agregadas computed properties `canUndo`, `canRedo`, `getUndoCount()`, `getRedoCount()`
- Permite que la UI consulte el estado de los stacks sin exponerlos directamente
- Ruta: `ios-app/AppForgeStudio/Features/SculptMode/Brushes/BrushEngine.swift:39-42`

### 2. SculptModeView.swift — Botones Undo/Redo en UI
- Botones con SF Symbols `arrow.uturn.backward` y `arrow.uturn.forward`
- Llaman a `brushEngine.undo()` y `brushEngine.redo()` sobre `scene.models[0].meshes[0].vertices`
- Después de undo/redo ejecutan `uploadToGPU` para reflejar cambios en Metal
- Botones se deshabilitan con `.disabled(!brushEngine.canUndo/canRedo)`
- Ruta: `ios-app/AppForgeStudio/Features/SculptMode/SculptModeView.swift:59-71`

### 3. ContentView.swift — Modo Pintura en handleTouch
- Al inicio de handleTouch(), si `isPaintMode == true`:
  - Crea BrushPoint, saveState, PaintRenderer, commandBuffer
  - Llama a `engine.paintStroke()` con el renderer
  - Hace uploadToGPU y return (no ejecuta escultura)
- Ruta: `ios-app/Sources/ContentView.swift:52-67`

## Próximas acciones (Fase 3 recomendada)
1. Exportacion STL/OBJ — ya existe `ExportService.swift` con estructura base
2. Implementar triangulacion de malla + write STL binario
3. Agregar boton Exportar en UI