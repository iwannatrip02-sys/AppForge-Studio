# Analisis Conexion AnimationEngine-SatinRenderer
> Fecha: 2026-04-30 18:34 UTC | Autor: Gotchi

## Estado Actual por Archivo

### AppState.swift (OK)
- `setRenderer()`: conecta `animationVM` -> `satinRenderer.animationEngine`
- Establece `onTransformsApplied` y `animationVM.onFrame` para escribir transforms en `canvasVM.scene`
- Llama desde AppForgeStudioApp.swift: `appState.setRenderer(appState.satinRenderer)`

### SatinRenderer.swift (OK)
- `updateAnimation()`: deltaTime real con `CACurrentMediaTime()`, descomposicion matriz->quaternion
- Evalua `engine.evaluate(at:)` por cada frame
- Convierte transforms a translation + rotation quaternion

### MetalView.swift (OK)
- Acepta `animationEngine: AnimationEngine?`
- Lo pasa al Coordinator
- Coordinator llama `animationEngine.update(deltaTime:)` en el draw loop

### AnimationModeView.swift (OK)
- Pasa `animationEngine: animationVM` a MetalView
- Slider de timeline bindeado a `animationVM.currentTime`

### RenderModeView.swift (OK)
- Pasa `animationEngine: animationVM` a MetalView

### UI/Components/ContentView.swift (OK parcial)
- Usa `canvasVM.animationEngine` seteado en AppState.setRenderer()
- Lo pasa a MetalView

### CADMode/ContentView.swift (BUG P1)
- Usa `SatinView(renderer:)` obsoleto
- No soporta animacion
- Struct SatinView repetido de UI/Components

### CADModeView.swift (BUG P1)
- Llama `ContentView(canvasVM:canvasVM,renderer:renderer)` sin animationEngine

### SculptModeView.swift (BUG P2)
- No recibe `animationVM` en constructor
- Usa ContentView de UI/Components (que si obtiene animationEngine indirectamente)
- Pero no puede pasar animacion a subvistas

### HybridModeView.swift (BUG P2)
- Recibe `animationVM` pero no lo pasa a ContentView

### Scene3D.swift (BUG P2)
- No conforma Codable -> no state restoration
- Tiene CADHistoryTree y GeometryConstraintManager que tampoco son Codable

## Cadena de Render

AppForgeStudioApp
  -> AppState.setRenderer(satinRenderer)
     -> satinRenderer.animationEngine = animationVM
     -> canvasVM.animationEngine = animationVM
  -> ModeView (segun selectedMode)
     -> MetalView(scene:strokes:renderer:animationEngine:)
        -> Coordinator
           -> draw loop: animationEngine.update(deltaTime)
              -> SatinRenderer.updateAnimation()
                 -> transforms a modelos en scene3D

## Resumen
- Conexion logica: OK (AppState->SatinRenderer->AnimationEngine)
- Conexion UI AnimationMode/RenderMode: OK (pasan animationEngine a MetalView)
- Conexion UI CADMode/SculptMode/HybridMode: ROTA (no pasan animationEngine)
- Scene3D Codable: PENDIENTE
- ContentView duplicado: PELIGRO (CADMode/ContentView.swift independiente de UI/Components)

## Proximas Acciones
1. Migrar CADMode/ContentView.swift a MetalView con animationEngine
2. Agregar animationEngine parameter a SculptModeView y pasarlo
3. Pasar animationVM desde HybridModeView a su ContentView
4. Hacer Scene3D Codable