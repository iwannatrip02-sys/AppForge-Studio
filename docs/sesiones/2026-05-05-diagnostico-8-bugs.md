# Diagnóstico: 8 Bugs vs Código Actual

> Fecha: 2026-05-05 | Commit: b6766b4
> Estructura real: AppForgeStudio/AppForgeStudio/ (no Sources/App/)

## Bugs que APLICAN al código actual:

### BUG2 — updateAnimation deltaTime Float (SatinRenderer.swift:28-30)
- `let deltaTime = Float(now - lastFrameTime)` con `lastFrameTime` en `CFTimeInterval (Double)`
- No hay doble llamada a updateAnimation (solo una)
- Fix: declarar `lastFrameTime` como `Double` y deltaTime como `Double`

### BUG4 — Package.swift apunta a mattrajca/Satin
- `https://github.com/mattrajca/Satin.git` debe ser `https://github.com/s1ddok/Satin.git`
- Fix: cambiar URL en Package.swift

### BUG5 — Normal matrix sin inverse/transpose (Shaders.metal:32)
- `uniforms.modelMatrix * float4(in.normal, 0.0)` para normal en vertex shader
- Debe ser `inverse(transpose(uniforms.modelMatrix)) * float4(in.normal, 0.0)` para escalado no uniforme
- Fix: agregar inverse(transpose()) en vertex shader

### BUG6 — Stroke sin aspect ratio (Shaders.metal:70-75)
- Stroke no tiene uniform para aspect ratio, usa offsets fijos sin corrección
- Fix: agregar uniform float aspectRatio y escalar offsets.x

## Bugs que NO aplican (archivos no existen en esta versión):

### BUG1 — Padding GPU SatinRenderer (no hay buffer padding issue aquí)
### BUG3 — UInt16 index limit (no hay index buffers)
### BUG7 — grab dragDelta (no existe SculptEngine.swift)
### BUG8 — currentMode hardcodeado (no existe CanvasViewModel.swift)

## Plan de acción:
1. Aplicar fix BUG4 en Package.swift (1 línea)
2. Aplicar fix BUG5 en Shaders.metal (1 línea)
3. Aplicar fix BUG6 en Shaders.metal (agregar uniform + escalado)
4. Aplicar fix BUG2 en SatinRenderer.swift (tipo de variables)
5. git commit con mensaje v0.9
6. git push para disparar CI
