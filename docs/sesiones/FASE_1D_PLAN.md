# Fase 1D — Plan de Implementación

## Diagnóstico
- Codebase activa: `ios-app/AppForgeStudio/` (SPM package, target: AppForgeStudio, depends: Satin)
- MetalView.swift (UI/Components): Coordinator tiene setup+dibujo pero NO gestos táctiles ni raycast
- ContentView.swift (Sources/): handleTouch() vacío, solo guarda currentStroke
- BrushEngine.swift (Features/SculptMode/Brushes): sculptStroke() llama applyDeformation() que está INCOMPLETA (solo esqueleto)
- PaintRenderer.swift (Core/Managers): pipeline Metal completo con compute shader para pintura UV

## Lo que falta (Fase 1D completa)

### 1. MetalView.swift — Gestos táctiles + Raycast 3D
- Implementar touchesBegan/touchesMoved/touchesEnded en Coordinator
- Raycast: convertir touch point (CGPoint) a rayo 3D usando inverse(viewMatrix * projectionMatrix)
- Intersectar rayo con mallas de la escena (hit test contra bounding sphere + triángulos)
- Llamar onTouch3D callback con punto de impacto y normal

### 2. ContentView.swift — handleTouch activo
- handleTouch recibe (position, normal) desde MetalView
- Si isPaintMode: generar BrushPoint, agregar a currentStroke
- Si NO isPaintMode (sculpt): llamar brushEngine?.sculptStroke(at:point, on:&mesh)
- Después de sculptStroke: llamar mesh.uploadToGPU(device:) para actualizar GPU

### 3. BrushEngine.swift — applyDeformation COMPLETA
- Implementar deformación con los 10 brush types:
   - round: desplazar vértices en dirección de la normal * (1 - dist/radius)
   - flat: desplazar constante dentro del radio
   - inflate: desplazar hacia afuera a lo largo de la normal
   - pinch: mover vértices hacia el centro del pincel
   - smooth: promediar posiciones de vértices vecinos
   - crease: pliegue lineal
   - grab: arrastrar vértices en dirección del movimiento
   - clay: acumular capas de arcilla
   - airbrush: dispersión suave
- Falloff basado en hardness (smoothstep)

### 4. Reconnect scene → brushEngine
- SculptModeView.swift ya tiene brushEngine, pero NO conecta scene.models[0].meshes[0]
- Pasar referencia a la malla desde scene al brushEngine

## Archivos a modificar
1. `UI/Components/MetalView.swift` — agregar touchesBegan/Moved/Ended + raycast
2. `Sources/ContentView.swift` — handleTouch con lógica de escultura/pintura
3. `Features/SculptMode/Brushes/BrushEngine.swift` — applyDeformation completa
4. `Features/SculptMode/SculptModeView.swift` — conectar scene a brushEngine

## Orden de implementación
1. BrushEngine.swift (applyDeformation completa con 10 brush types)
2. MetalView.swift (touches + raycast)
3. ContentView.swift (handleTouch activo)
4. SculptModeView.swift (conexión scene→brushEngine)
