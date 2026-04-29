# Integración de AnimationEngine y SubdivisionEngine en la UI

## Estado actual
- `AppState` ya instancia `animationVM` y `subdivisionVM`
- `HybridModeView` ya recibe `animationVM` y tiene `TimelineView`
- `SculptModeView` NO recibe `subdivisionVM` ni `animationVM`
- `CADModeView` NO recibe ninguno de los dos

## Cambios necesarios

### 1. SculptModeView
- Inyectar `subdivisionVM: SubdivisionEngine`
- Agregar botón "Subdividir" (niveles 1-3) en la toolbar inferior
- Al presionar: `canvasVM.currentMesh = subdivisionVM.subdivide(canvasVM.currentMesh, levels: selectedLevel)`

### 2. CADModeView
- Inyectar `animationVM: AnimationEngine`
- Agregar botón "Animar" que crea un clip con la extrusión como keyframe
- Al presionar: `animationVM.registerClip(AnimationClip(name: "Extrude", duration: 2.0, ...))`

### 3. HybridModeView
- Ya tiene `animationVM` — solo falta agregar botón de subdivisión (inyectar `subdivisionVM`)

## Archivos a modificar
- `Features/SculptMode/SculptModeView.swift`
- `Features/CADMode/CADModeView.swift`
- `Features/HybridMode/HybridModeView.swift`

## Prioridad: SculptModeView primero (más impacto), luego CADModeView, luego HybridModeView