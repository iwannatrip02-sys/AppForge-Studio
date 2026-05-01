# Estado de Animación — AppForge Studio
> 2026-04-30

## Hallazgos

1. **AnimationEngine** (`Core/Managers/AnimationEngine.swift`):
   - Existe con `Keyframe<T>`, `AnimationClip`, `Easing` (7 tipos)
   - Tiene `isPlaying`, `currentTime`, `clips`, `keyframes` publicados
   - NO tiene método `evaluateAnimation(for modelName: String, at time: Float) -> (position: SIMD3<Float>, rotation: simd_quatf, scale: SIMD3<Float>)?`
   - NO puede interpolar entre keyframes de un clip
   - NO tiene temporizador/display link para avanzar `currentTime` cuando `isPlaying = true`

2. **SatinRendererView** (`UI/Components/SatinRendererView.swift`):
   - Acepta `@Binding var scene: Scene3D`
   - Renderiza con `SatinRenderer` en MTKView
   - NO acepta `animationEngine` ni aplica transforms animados antes de dibujar
   - El `draw(in:)` llama `updateScene(&scene)` pero no modifica modelos según animación

3. **AnimationView** (`UI/Components/AnimationView.swift`):
   - UI completa: play/pause, slider de tiempo, botón add keyframe
   - Conectada a `@ObservedObject var engine: AnimationEngine`
   - NO hay duplicado en `Views/AnimationView.swift` (no existe)

4. **Toolbar** (`UI/Components/ToolbarView.swift`):
   - Usa `ToolViewModel` (no `ToolbarViewModel`)
   - Única versión existente. No hay duplicado.

5. **Scene3D** (`Models/Scene3D.swift`):
   - Tiene `models: [Model]` donde cada Model tiene `transform` con position, rotation, scale
   - Estructura compatible con animación vía SIMD

## Próximas acciones

1. Añadir `evaluateAnimation(at:)` a AnimationEngine que interpole clip activo y devuelva transforms
2. Añadir `DisplayLink` o `Timer` en AnimationEngine para avanzar currentTime cuando isPlaying
3. Modificar SatinRendererView para aceptar `animationEngine: AnimationEngine` y aplicar transforms animados antes de draw
4. Marcar TODO #t35 como desactualizado (done)
5. Crear TODO #t36: "Conectar AnimationEngine con SatinRenderer para playback real"
