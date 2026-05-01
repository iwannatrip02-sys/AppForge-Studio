# Bugs P1 Identificados y Estado de Usabilidad

## 1. BrushEngine puramente 2D (P1 crítico para pintura 3D)
**Archivo:** Core/Engines/BrushEngine.swift
**Problema:** Solo maneja `CGPoint` en 2D. No tiene proyección a malla 3D (raycasting, coordenadas UV, ni profundidad). Las brochadas no pintan sobre la superficie de la malla.
**Evidencia:** `var strokePoints: [CGPoint] = []` — puntos en espacio de pantalla. No hay referencia a `SCNNode`, `MDLMesh` ni coordenadas 3D.
**Solución requerida:** Añadir `func projectToMesh(screenPoint: CGPoint, viewMatrix: float4x4, projectionMatrix: float4x4, meshVertices: [float3]) -> float3?` que haga raycasting contra el mesh.

## 2. Shaders.metal incompleto (P1)
**Archivo:** Core/Managers/Shaders.metal (línea 61)
**Problema:** Solo tiene `strokeVertex` y `strokeFragment` básicos. Faltan `vertex_main` y `fragment_main` para renderizado general de escena.
**Evidencia:** grep mostró que `vertex_main` NO existe en Shaders.metal (solo referencias en código Swift). `PincelRenderer` carga correctamente `strokeVertex` pero `SceneRenderer` falla al buscar `vertex_main` (imprime warning).
**Solución:** Añadir `vertex_main` y `fragment_main` a Shaders.metal con iluminación difusa básica.

## 3. MTKView recreado en cambio de modo (P1 - UX)
**Archivo:** AppForgeStudioApp.swift (líneas ~28-50)
**Problema:** `switch appState.selectedMode` destruye y recrea completamente `SatinRendererView` en cada cambio. `matchedGeometryEffect` con `transition(.opacity.combined(with: .slide))` causa 1-2s de pantalla negra mientras Metal reconfigura pipeline.
**Evidencia:** `case .sculpt: SculptModeView(...).equatable().matchedGeometryEffect(...)` — cada case crea nueva instancia de view.
**Solución:** Mover `SatinRendererView` a `ZStack` fuera del `switch`, compartido entre modos. Pasar solo el `appState.selectedMode` como binding.

## 4. SculptModeView sin subdivisionVM ni animationVM (P1)
**Archivo:** Features/SculptMode/SculptModeView.swift
**Problema:** No recibe `subdivisionVM` ni `animationVM` desde AppForgeStudioApp. En el switch de modos, `.sculpt` solo pasa `canvasVM, renderer, toolVM, subdivisionVM`. Falta binding a AnimationEngine.
**Evidencia:** `SculptModeView(canvasVM: ..., renderer: ..., toolVM: ..., subdivisionVM: ...)` — no hay parámetro animationVM.
**Solución:** Añadir `animationVM: AnimationViewModel` a la firma y pasar en AppForgeStudioApp.

## 5. AnimationEngine sin binding a SatinRendererView (P1)
**Archivo:** Core/Managers/AnimationEngine.swift + AppForgeStudioApp.swift
**Problema:** AnimationEngine existe pero no está conectado al ciclo de render de SatinRendererView. El playback requiere llamar `engine.evaluate(at:)` desde `SatinRenderer.update()`.
**Evidencia:** No hay `func startPlayback()` ni `CADisplayLink` en el código. El engine solo evalúa keyframes manualmente.
**Solución:** Añadir `CADisplayLink` o `MTKViewDelegate.draw()` que llame `engine.evaluate(at: currentTime)` cada frame.

## 6. Carpeta Brushes vacía (P1 - funcionalidad faltante)
**Archivo:** Features/SculptMode/Brushes/
**Problema:** La carpeta existe pero no contiene ningún archivo .swift. No hay implementación de brushes individuales (pincel, clay, inflate, pinch, smooth, flatten, crease, fill, grab).
**Evidencia:** `glob('**/*Brush*')` solo devolvió la carpeta vacía.
**Solución:** Implementar `protocol BrushProtocol { func apply(to mesh: inout Mesh3D, at point: float3, radius: Float, strength: Float) }` y 9 implementaciones.

---

## Estado de Usabilidad Real

### Qué funciona (estimado 30% de la app core):
- Navegación básica entre modos (CAD, Sculpt, Hybrid) con transiciones animadas
- SatinRenderer con pipeline Metal funcional (carga shaders, dibuja en pantalla)
- SceneRenderer con iluminación difusa básica (ambientColor, lightDirection)
- ExportService exporta OBJ (con try/catch), STL/USDZ (sin try/catch — corregido en P0)
- AnimationEngine evalúa keyframes en código (sin playback continuo)
- CADSketchEngine, CSGEngine, SubdivisionEngine declarados pero no verificados

### Qué NO funciona (70% restante):
- Pintura 3D: BrushEngine solo captura puntos 2D, no hay proyección a malla
- Escultura: Sin implementación de brushes (carpeta vacía)
- Playback de animación: AnimationEngine no conectado al render loop
- Shaders incompletos: Falta vertex_main/fragment_main para render general
- Transiciones de modo: Pantalla negra 1-2s al cambiar (recrea MTKView)
- Pintura sobre malla: Sin texturizado UV ni paintTexture conectado
- Subdivisión: SubdivisionEngine declarado pero no integrado en SculptModeView

### Puntaje de usabilidad: 2/10
- La app abre, muestra una escena 3D básica, y permite navegar entre pestañas
- Hacer clic en 'pintar' no pinta nada (BrushEngine 2D sin conexión a malla)
- Hacer clic en 'esculpir' muestra UI pero no deforma la malla (sin brushes)
- Animar un modelo no reproduce frames (sin playback continuo)

### Prioridad de corrección:
1. (Crítico) Conectar AnimationEngine → SatinRenderer para playback real
2. (P1) Añadir vertex_main/fragment_main a Shaders.metal
3. (P1) Mover SatinRendererView fuera del switch en AppForgeStudioApp
4. (P1) Implementar proyección 3D en BrushEngine
5. (P1) Añadir subdivisionVM/animationVM a SculptModeView
6. (P1) Implementar brushes de escultura
