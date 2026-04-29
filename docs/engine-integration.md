# Integración de AnimationEngine y SubdivisionEngine en la UI

## Cambios realizados

### SculptModeView (Features/SculptMode)
- Nuevo parámetro: `@ObservedObject var subdivisionVM: SubdivisionEngine`
- Botón "Sub" en la toolbar inferior que llama `subdivisionVM.subdivide(canvasVM.currentMesh, levels: 1)`
- Muestra `ProgressView` cuando `isSubdividing` es true
- Llama a `canvasVM.saveState()` antes de subdividir (undo support)

### CADModeView (Features/CADMode)
- Nuevo parámetro: `@ObservedObject var animationVM: AnimationEngine`
- Botón con icono `play.rectangle` que crea un `AnimationClip` y lo registra
- Botón deshabilitado si `canvasVM.scene.models.isEmpty`
- Indicador visual "Anim" / "Playing"

### HybridModeView (Features/HybridMode)
- Nuevo parámetro: `@ObservedObject var subdivisionVM: SubdivisionEngine`
- Botón con icono `square.grid.3x3.topleft.filled` junto al botón de timeline
- Llama a `subdivisionVM.subdivide()` sobre el primer modelo de la escena
- Deshabilitado si no hay modelos o `isSubdividing`

### AppForgeStudioApp.swift
- `SculptModeView` ahora recibe `subdivisionVM: appState.subdivisionVM`
- `CADModeView` ahora recibe `renderer: appState.satinRenderer, animationVM: appState.animationVM`
- `HybridModeView` ahora recibe `subdivisionVM: appState.subdivisionVM`

## Próximos pasos
- Compilar en Xcode y verificar que las vistas reciben los parámetros correctos
- Agregar menú de niveles de subdivisión (1-3) en SculptModeView
- Conectar AnimationEngine con TimelineView en HybridModeView (ya existe)
- Agregar keyframes de animación para herramientas CAD (extrusión animada)