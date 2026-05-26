# AppForge Studio — Análisis de Estabilización y Hoja de Ruta
> Basado en datos reales del código existente | 2026-05-04

## 1. ESTADO ACTUAL DEL CÓDIGO

### Archivos existentes en `ios-app/AppForgeStudio/AppForgeStudio/`
- **AppForgeStudioApp.swift** — entry point SwiftUI
- **SatinMesh.swift** — definiciones de mallas
- **SatinRenderer.swift** (~500+ líneas) — renderer completo con:
  - `animationEngine: AnimationEngine?`
  - `playbackController: AnimationPlaybackController?`
  - `updateAnimation()` llamado en cada frame del render loop
  - Estructuras PBR completas: `GPUPBRMaterial`, `GPUPointLight`, `GPUDirectionalLight`, `GPULightUniforms`, `FrameUniforms` con `cameraPosition`
  - Render loop en Coordinator (`draw(in:)`) que llama `renderer.updateScene(scene)` y `renderer.render(in: view)`

### Archivos temporales (encontrados pero no integrados)
- **temp_mv.txt** — `MetalView` con Coordinator, asigna `animationEngine` al renderer, usa CADisplayLink
- **temp_sr.txt** — Versión más simple de SatinRenderer **sin animación** (archivo de trabajo previo)
- **temp_sc.txt** — `Scene3D` con: models, strokes, camera, lighting, `CADHistoryTree`, `GeometryConstraintManager`

### Archivos NO existentes (módulos faltantes)
- `AnimationPlaybackController.swift` — NO existe
- `MetalView.swift` — NO existe (solo en temp_mv.txt)
- `Scene3D.swift` — NO existe (solo en temp_sc.txt)
- `BrushStroke.swift` / `PaintRenderer.swift` — NO existen
- `Shaders.metal` — Solo hay 1 archivo .metal de 763 bytes (insuficiente para compute shaders)
- `SculptEngine.swift` — NO existe
- `SubdivisionEngine.swift` — NO existe
- `OCCTEngine.swift` — NO existe
- `ExportService.swift` — NO existe
- `MaterialEditorView.swift` — NO existe
- `ThemeManager.swift` — NO existe
- `LoadingScreenView.swift` — NO existe
- Suite de 23 tests — NO existen

## 2. HOJA DE RUTA PARA ESTABILIZACIÓN

### FASE A — Completar y estabilizar código crítico (1-2 sesiones)

**Objetivo**: Unir los archivos temporales con el SatinRenderer real para que compile y renderice con animación básica.

1. **Crear `MetalView.swift`** desde `temp_mv.txt`:
   - UIViewRepresentable con Coordinator
   - Parámetro `animationEngine: AnimationEngine?`
   - En `updateUIView`: asigna `renderer.animationEngine = animationEngine`
   - Coordinator usa CADisplayLink para llamar `renderer.updateScene(scene)` + `renderer.render(in: view)`

2. **Crear `AnimationPlaybackController.swift`** (nuevo):
   - Envuelve CADisplayLink
   - Propiedades: `clips: [AnimationClip]`, `currentTime: TimeInterval`, `isPlaying: Bool`
   - Métodos: `play()`, `pause()`, `stop()`, `seek(to:)`
   - En cada tick: actualiza `currentTime`, llama `animationEngine.evaluateAnimation(at: currentTime)`
   - Callback opcional para notificar al renderer

3. **Parchar `SatinRenderer.swift`** (el real de 500+ líneas):
   - Completar `updateAnimation()` para que:
     a. Obtenga `currentTime` del `playbackController`
     b. Llame `animationEngine?.evaluateAnimation(at: currentTime)`
     c. Itere sobre los keyframes devueltos y aplique transformaciones a los modelos correspondientes en la escena
     d. Invalide el búfer de GPU para reflejar cambios
   - Verificar que `FrameUniforms` tenga `deltaTime` actualizado en cada frame

4. **Crear `Scene3D.swift`** desde `temp_sc.txt`:
   - Struct con: `models: [SatinMesh]`, `strokes: [BrushStroke]`, `camera: Camera`, `lighting: LightingConfig`, `cadHistory: CADHistoryTree`, `constraints: GeometryConstraintManager`
   - Método `update()` que recorre modelos y aplica animaciones

### FASE B — Restaurar módulos faltantes (2-3 sesiones)

**Objetivo**: Reconstruir los 8 módulos faltantes para tener funcionalidad completa de Paint, Sculpt, CAD y Export.

5. **Sistema de Pintura 3D** (BrushStroke + PaintRenderer + Shaders.metal):
   - `BrushStroke`: struct con puntos, grosor, color, opacidad, textura
   - `PaintRenderer`: clase que genera mallas procedurales (triangulación de pinceladas)
   - `Shaders.metal`: al menos 3 shaders — pincelada circular, pincelada texturizada, mezcla alfa
   - Referencia: lógica de brushes del análisis de Blender (archivos `brush_types.cc`, `paint_stroke.cc`)

6. **SculptEngine + SubdivisionEngine**:
   - 8 deformadores: Inflate, Smooth, Flatten, Pinch, Grab, Crease, Move, Rotate
   - Subdivisión Catmull-Clark con control de profundidad
   - Base: estructura de datos half-edge para gestión de topología

7. **OCCTEngine para CAD**:
   - Operaciones booleanas: unión, intersección, diferencia
   - Extrusión, revolución, lofts
   - `CADHistoryTree` (ya esbozado en temp_sc.txt): pila de operaciones con undo/redo

8. **ExportService**:
   - 5 formatos: OBJ, STL, USDZ, STEP, GLTF
   - Usar ModelIO para USDZ, Assimp o escritura directa para STL/OBJ

9. **Vistas UI faltantes**:
   - `MaterialEditorView`: sliders para color, roughness, metallic, emisión
   - `ThemeManager`: soporte dark/light con colores consistentes
   - `LoadingScreenView`: pantalla de carga con progreso

10. **Tests (23 total)**:
    - 12 tests de AnimationEngine
    - 6 tests de ExportService
    - 5 tests de ModelCacheService

### FASE C — Integración y Beta (1 sesión)

11. Compilar en Xcode y ejecutar todos los tests (TODO #1)
12. Validar render loop paint + sculpt + CAD + animation
13. Beta con AltStore y TestFlight

## 3. RECOMENDACIONES

- **Prioridad**: Fase A primero — sin MetalView y AnimationPlaybackController, la app ni compila
- **Riesgo**: Shaders.metal requiere conocimientos de Metal shading language; considerar reutilizar shaders de Satin v0.3.0
- **Dependencia externa**: OCCTSwift puede requerir wrapper Objective-C++ alrededor de OpenCASCADE
- **Timeout**: code_agent tiene límite de 600s — dividir Fase B en sub-batches de 3-4 archivos cada uno
