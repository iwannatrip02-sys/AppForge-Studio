# RECON LiveInteraction — 2026-07-15

> Rama: `feature/fase-c` | Agente: RECON (solo lectura). Alimenta el spec de la ola "LiveInteraction".

---

## A. Pipeline de Transform

### Estado (`@State` en `CADModeView`)

| Símbolo | file:línea | Firma | Rol |
|---|---|---|---|
| `dragFace` | CADModeView.swift:115 | `@State var dragFace: (modelIndex:Int, faceIndex:Int, normal:SIMD3<Float>)?` | Cara bajo el dedo durante un drag de push/pull manual; nil = transform de cuerpo entero |
| `dragAccum` | CADModeView.swift:155 | `@State var dragAccum: SIMD2<Float>` | Acumulador de píxeles de pantalla del pan UIKit, integrado cada frame |
| `gizmoAxis` | CADModeView.swift:157 | `@State var gizmoAxis: SIMD3<Float>?` | Eje restringido elegido por `onGizmoDragBegan`; nil = drag libre XY |
| `transformNudge` | CADModeView.swift:166 | `@State var transformNudge: Double` | Empujón numérico que se suma al escalar derivado del drag; NUNCA se renderiza en ninguna View — solo se escribe en lógica y se lee en `transformParams` |
| `lastSnapDetent` | CADModeView.swift:169 | `@State var lastSnapDetent: Double?` | Último valor snap cruzado; dispara tick háptico al cambiar |
| `transformReadout` | CADModeView.swift:172 | `@State var transformReadout: String` | Texto vivo de la medida (distancia/ángulo/factor); se escribe en `applyTransformPreview` pero NO se muestra en ningún componente SwiftUI actualmente — es estado huérfano |

### Propiedades calculadas

| Símbolo | file:línea | Firma | Rol |
|---|---|---|---|
| `activeTransformTarget` | CADModeView.swift:179 | `private var activeTransformTarget: TransformTarget?` | Fuente única: resuelve `selectionController.lastItem` vs `bodyIndex` vía `TransformTargetResolver.target`; llama `activeGizmoCenter`, `beginTransformDrag`, `applyTransformPreview`, `bakeTransform` |
| `activeGizmoCenter` | CADModeView.swift:187 | `private var activeGizmoCenter: SIMD3<Float>?` | Centro del gizmo: `TransformTargetResolver.center(for:in:)` sobre el target activo; pasado a `MetalView.gizmoCenter` |

### Funciones principales

| Símbolo | file:línea | Firma | Rol |
|---|---|---|---|
| `transformParams(for:)` | CADModeView.swift:2130 | `private func transformParams(for model: Model) -> (delta:SIMD3<Float>, angle:Float, axis:SIMD3<Float>, factor:Float, center:SIMD3<Float>)` | Motor aritmético puro: combina `dragAccum + transformNudge + snap`; callee de `applyTransformPreview` y `bakeTransform` |
| `beginTransformDrag(hitModelIndex:)` | CADModeView.swift:2285 | `private func beginTransformDrag(hitModelIndex: Int?)` | Inicializa estado de drag: resetea `dragAccum/transformNudge/lastSnapDetent/transformReadout`; arma `dragFace` si el target es `.face` y la herramienta es `.move`; llamado desde `onTransformBegan` en MetalView |
| `applyTransformPreview()` | CADModeView.swift:2343 | `private func applyTransformPreview()` | Llama `transformParams`, actualiza posición/rotación/scale del modelo en memoria y escribe `transformReadout`; NO hornea B-rep; llamado desde `onTransformChanged` cada frame de pan |
| `bakeTransform()` | CADModeView.swift:2401 | `private func bakeTransform()` | Al soltar: si `dragFace` activa ejecuta `BRepModeling.pushPullFace`; si sub-objeto llama `bakeSubObjectEdit`; si cuerpo entero commitea TRS y llama B-rep; resetea todo estado; llamado desde `onTransformEnded` |
| `bakeSubObjectEdit(target:)` | CADModeView.swift:2516 | `private func bakeSubObjectEdit(target: TransformTarget) -> Bool` | Ramifica por `.face/.edge/.vertex` y aplica la edición OCCT real (escala cara, mueve arista/vértice); llamado por `bakeTransform` cuando `target.isSubObject` |
| `snapTransformScalar(_:)` | CADModeView.swift:2234 | `private func snapTransformScalar(_ value: Double) -> Double` | Cuantiza a rejilla (move: `gridStep`, rotate: `angleSnapDegrees`, scale: 0.25); llamado por `transformParams` |
| `transformReadoutText(for:)` | CADModeView.swift:2265 | `private func transformReadoutText(for model: Model) -> String` | Formatea el escalar activo como "%+.2f", "%+.1f°" o "×%.2f"; llamado por `applyTransformPreview` |

### Callbacks de MetalView (Core/UI/MetalView.swift)

| Símbolo | file:línea | Firma | Rol en MetalView |
|---|---|---|---|
| `onTransformChanged` | MetalView.swift:68 | `var onTransformChanged: ((Float, Float) -> Void)?` | Emitido en `handlePan` estado `.changed` cuando `isTransforming == true`; lleva `translation.x/y` de `UIPanGestureRecognizer` |
| `onTransformEnded` | MetalView.swift:69 | `var onTransformEnded: (() -> Void)?` | Emitido en `handlePan` estado `.ended/.cancelled` cuando `isTransforming`; sin payload |
| `onGizmoDragBegan` | MetalView.swift:78 | `var onGizmoDragBegan: ((SIMD3<Float>) -> Void)?` | Emitido en `.began` cuando `gizmoAxisHit` retorna un eje; lleva el eje mundo del gizmo |
| `onEmptyTap` | MetalView.swift:71 | `var onEmptyTap: (() -> Void)?` | Emitido en `handleTap` cuando el ray cast no golpea geometría; deselecciona en CADModeView |
| `gizmoCenter` | MetalView.swift:74 | `var gizmoCenter: SIMD3<Float>?` | Input: centro del gizmo pasado al Coordinator; `gizmoAxisHit` lo usa para proyectar manijas a pantalla |
| `gizmoStyle` | MetalView.swift:77 | `var gizmoStyle: Int` | 0 = flechas (move/scale), 1 = anillos (rotate); selector de geometría en `gizmoAxisHit` |

**Flujo UIKit de gestos:** `UIPanGestureRecognizer` (`maximumNumberOfTouches=2`) en `handlePan` (MetalView.swift:336). Estado `.began` con 1 dedo: si `gizmoAxisHit` da eje → `isTransforming = true` + `onGizmoDragBegan`; si `ScenePicker.hitTest` golpea → `isTransforming = true` + `onTransformBegan`; si vacío → `isOrbiting`. Estado `.changed`: si `isTransforming` → `onTransformChanged(dx, dy)`. Estado `.ended` → `onTransformEnded`.

### Barra de parámetros del transform / snap / local-global

- **`parameterBar`** (CADModeView.swift:1701): switch por `selectedTool`; los casos `.move`, `.rotate`, `.scale` caen en `default: EmptyView()` — **no existe barra de parámetros para move/rotate/scale**.
- **`transformNudge`** y **`transformReadout`** se calculan pero ningún componente SwiftUI los lee ni los muestra.
- **`gridSnapEnabled`** se controla en `bottomBar` (CADModeView.swift:1933) con un `Toggle("Snap", isOn: $toolVM.gridSnapEnabled)`.
- **Toggle local/global** (espacio de coordenadas): **NO existe**. `transformParams` usa espacio mundo por defecto; la única restricción de eje viene del gizmo (`gizmoAxis`).

---

## B. Preview en Vivo — LivePreviewEngine

**Archivo:** `Sources/Services/LivePreviewEngine.swift`

| Símbolo | file:línea | Firma | Rol |
|---|---|---|---|
| `LivePreviewState` | LivePreviewEngine.swift:11 | `enum LivePreviewState: Equatable` | Casos: `.inactive`, `.extruding(modelIndex:faceIndex:direction:distance:)`, `.fillet(…radius:)`, `.chamfer(…distance:)`, `.shell(…thickness:)` |
| `state` | LivePreviewEngine.swift:36 | `@Published var state: LivePreviewState` | Estado publicado; la View lo observa vía `livePreviewEngine.state.isActive` |
| `previewMesh` | LivePreviewEngine.swift:38 | `@Published var previewMesh: Mesh?` | Malla fantasma del preview; nil cuando no hay preview activo |
| `previewEdges` | LivePreviewEngine.swift:40 | `@Published var previewEdges: Mesh?` | Malla de aristas del preview (tubos `radius:0.005`) |
| `beginExtrude(shape:faceIndex:direction:initialDistance:)` | LivePreviewEngine.swift:50 | `func beginExtrude(shape:CADShape, faceIndex:Int, direction:SIMD3<Float>, initialDistance:Float)` | Inicia estado extrusión; llama `updateMesh` |
| `beginFillet(shape:edgeIndex:initialRadius:)` | LivePreviewEngine.swift:59 | `func beginFillet(shape:CADShape, edgeIndex:Int, initialRadius:Float)` | Inicia estado fillet |
| `beginChamfer(shape:edgeIndex:initialDistance:)` | LivePreviewEngine.swift:66 | `func beginChamfer(shape:CADShape, edgeIndex:Int, initialDistance:Float)` | Inicia estado chamfer |
| `beginShell(shape:openFaceIndex:initialThickness:)` | LivePreviewEngine.swift:73 | `func beginShell(shape:CADShape, openFaceIndex:Int?, initialThickness:Float)` | Inicia estado shell |
| `update(parameter:)` | LivePreviewEngine.swift:82 | `func update(parameter: Float)` | Actualiza el parámetro escalar del estado activo y regenera mesh via `updateMesh` |
| `commit()` | LivePreviewEngine.swift:101 | `func commit()` | Llama `onCommit?(state)` luego `clear()`; el owner aplica la operación real |
| `cancel()` | LivePreviewEngine.swift:107 | `func cancel()` | Limpia sin aplicar |
| `onCommit` | LivePreviewEngine.swift:45 | `var onCommit: ((LivePreviewState) -> Void)?` | Callback que el owner (CADModeView) debe atar para ejecutar la operación B-rep real |

**Quién lo usa hoy:** `CADModeView` lo instancia como `@StateObject private var livePreviewEngine = LivePreviewEngine()` (CADModeView.swift:35). El código de inyección en escena existe (CADModeView.swift:599-618): cuando `livePreviewEngine.state.isActive && previewMesh != nil`, crea un `Model(name: "__livePreview")` con `color = SIMD4<Float>(1.0, 0.48, 0.27, 0.45)` (ámbar translúcido) y lo añade a `canvasVM.scene`. Sin embargo, **nadie llama `beginExtrude/beginFillet/beginChamfer/beginShell` ni `update(parameter:)` hoy** — el motor está cableado pero sin disparadores.

**Material fantasma:** `model.color` con alpha 0.45 sobre el `basicXrayPipelineState` (blending `sourceAlpha / oneMinusSourceAlpha`, `isDepthWriteEnabled = false`). El modelo `__livePreview` tiene `opaqueInXray = true` (prefijo `__`), lo que lo excluye del modo rayos X por defecto pero sí lo renderiza normalmente con su alpha.

**Picking — convención `__`:** `ScenePicker.hitTest` (ScenePicking.swift:119-148) filtra `model.name.hasPrefix("__")` → los modelos `__livePreview`, `__faceHighlight`, `__edgeHighlight`, `__gizmoX/Y/Z`, `__measureDot*` son invisibles al picking.

---

## C. Extrude/Push-Pull en Vivo

| Símbolo | file:línea | Firma | Rol |
|---|---|---|---|
| `PushPullController` | Sources/Services/PushPullController.swift:11 | `@MainActor final class PushPullController: ObservableObject` | Máquina de estados: `selection: Selection?` + `distance: Double` + `highlightMesh: Mesh?` |
| `PushPullController.selectFace(from:in:)` | PushPullController.swift:28 | `func selectFace(from hit: SurfaceHit, in models: [Model])` | Resuelve hit → cara B-rep vía `BRepFacePicker`; publica `highlightMesh` |
| `PushPullController.apply()` | PushPullController.swift:52 | `@discardableResult func apply() -> Bool` | Ejecuta `BRepModeling.pushPullFace`; commitea o descarta historial; llama a resetear `selection` |
| `performExtrusion()` | CADModeView.swift:2053 | `private func performExtrusion()` | Lee `sketch.extrudedShapeForActiveRegion(distance:)` y commitea a escena como cuerpo nuevo o booleano según `extrudeCut`; llamado por el botón "Extruir" del `parameterBar` |
| `extrudeRegion(vertices:height:)` | SketchController.swift:812 | `func extrudeRegion(vertices: [SIMD2<Float>], height: Double) -> Model?` | Extruye una región 2D conocida a un sólido; retorna `Model?` sin tocar la escena |
| `extrudeRegion(at:height:)` | SketchController.swift:834 | `func extrudeRegion(at point: SIMD2<Float>, height: Double) -> Model?` | Variante: detecta la región más grande bajo el punto y llama la anterior |
| `extrudedShapeForActiveRegion(distance:)` | SketchController.swift:901 | `func extrudedShapeForActiveRegion(distance: Double) -> CADShape?` | Puro: devuelve `CADShape?` sin tocar la escena; usa `OCCTSwift.Shape.extrude(profile:direction:length:)`; llamado por `performExtrusion()` en CADModeView |

**Push-pull interactivo actual:** el flujo es tap-en-cara → `pushPullController.selectFace` → slider/`NumericField` en `pushPullBar` → botón "Añadir/Excavar" → `pushPullController.apply()`. No hay drag-en-cara como en Shapr3D. El `dragFace` en CADModeView implementa una variante de push/pull vía transform (mueve el overlay `__edgeHighlight` como fantasma) pero hornea con `BRepModeling.pushPullFace`, no con `LivePreviewEngine`.

---

## D. HUD Flotante / Proyección Mundo→Pantalla

| Símbolo | file:línea | Firma | Rol |
|---|---|---|---|
| `ViewportProjector` | Views/DimensionOverlayView.swift:8 | `struct ViewportProjector` | Proyecta `SIMD3<Float>` → `CGPoint?` usando `viewMatrix` + `projectionMatrix`; retorna nil si detrás de cámara |
| `ViewportProjector.project(_:)` | DimensionOverlayView.swift:15 | `func project(_ worldPoint: SIMD3<Float>) -> CGPoint?` | NDC → pantalla: `(ndc+1)*0.5*size`; usada solo por `DimensionOverlayView` (cotas de medición) |
| `MeasurementOverlay` | DimensionOverlayView.swift:241 | `struct MeasurementOverlay: View` | Overlay SwiftUI sobre el viewport; construye `ViewportProjector` con `canvasVM.viewMatrix` + `canvasVM.projectionMatrix(for:)` |
| `CanvasViewModel.projectionMatrix(for:)` | Core/UI/CanvasViewModel.swift:135 | `func projectionMatrix(for viewportSize: CGSize) -> simd_float4x4` | Genera la matriz de proyección perspectiva compatible con el renderer |
| `MetalView.Coordinator.projectToScreen(_:in:)` | Core/UI/MetalView.swift:588 | `private func projectToScreen(_ p: SIMD3<Float>, in view: UIView) -> CGPoint?` | Función privada del Coordinator; idéntica matemática a `ViewportProjector.project`; usada solo para hit-test del gizmo |
| `SatinRenderer.projectionMatrix(for:aspect:)` | Sources/Engines/SatinRenderer.swift:1253 | `nonisolated static func projectionMatrix(for cam: Scene3D.Camera, aspect: Float) -> simd_float4x4` | Fuente de verdad de la matriz de proyección; llamada por el renderer y por `projectToScreen` |

**HUD anclado a punto 3D:** No existe ningún componente SwiftUI de texto/número flotante anclado a un punto 3D proyectado. Las cotas (`DimensionOverlayView`) proyectan mediante `ViewportProjector` pero son anotaciones de medición, no labels de parámetro en vivo durante un drag.

---

## E. Renderer — Mallas Temporales y Material Translúcido

| Símbolo | file:línea | Firma | Rol |
|---|---|---|---|
| `SatinRenderer.updateScene(_:)` | SatinRenderer.swift:908 | `func updateScene(_ scene3D: Scene3D)` | Compara firma (`models.count × geometryVersion`); si cambia llama `rebuildSceneFrom`; si no, actualiza matrices in-place |
| `rebuildSceneFrom(_:)` | SatinRenderer.swift:921 | `private func rebuildSceneFrom(_ scene3D: Scene3D)` | Reconstruye todos los `pbrRenderables/basicRenderables/edgeRenderables` desde cero; cada `addModel` a `canvasVM.scene` que cambie el count o `geometryVersion` dispara un rebuild completo |
| `basicXrayPipelineState` | SatinRenderer.swift:537-547 | pipeline MTL con blending `sourceAlpha/oneMinusSourceAlpha`, `isDepthWriteEnabled=false` | Pipeline translúcido (usado para rayos X y cualquier modelo con alpha < 1) |
| `xrayEnabled` | SatinRenderer.swift:306 | `var xrayEnabled = false` | Flag: cuando true, los `basicRenderables` con `opaqueInXray=false` se dibujan con alpha 0.30 vía `basicXrayPipelineState` |
| Convención `__` y `opaqueInXray` | SatinRenderer.swift:1065 | `color: SIMD4<Float>(...), opaqueInXray: model.name.hasPrefix("__")` | Los modelos `__*` tienen `opaqueInXray=true`: no se translucifican con rayos X; esto incluye `__livePreview` |

**Cómo se añade un modelo temporal:**
1. `canvasVM.scene.addModel(model)` — muta `scene3D.models` y dispara `objectWillChange`.
2. `SatinRenderer.updateScene` detecta cambio de firma → `rebuildSceneFrom` (rebuild completo, `rebuildCount++`).
3. Para quitar: `canvasVM.scene.models.removeAll { $0.name == "…" }` + `objectWillChange.send()` → rebuild siguiente frame.

**No existe actualización in-place de un modelo recién añadido** — cada añadir/quitar un modelo es un rebuild completo. Las matrices de transform sí se actualizan in-place (SatinRenderer.swift:1334) para modelos ya existentes.

**Material translúcido disponible:** El color de un `Model` con `usesPBR = false` pasa directamente como `model.color: SIMD4<Float>`; el alpha actúa cuando se usa `basicXrayPipelineState`. El `__livePreview` actual (CADModeView.swift:607) usa `color = SIMD4<Float>(1.0, 0.48, 0.27, 0.45)` — funciona con blending ya que el renderer elige el pipeline x-ray cuando `xrayEnabled`, pero con `xrayEnabled=false` y `opaqueInXray=true` (porque el nombre empieza con `__`) se dibuja con el pipeline opaco — **el alpha 0.45 no tiene efecto sin xray activo para modelos `__`**.

**Hook de ghost/preview:** No existe un hook dedicado "ghost". El único mecanismo es inyectar un `Model(name:"__livePreview")` a la escena con un color de alpha menor que 1, y activar `xrayEnabled` para que el pipeline con blending lo renderice translúcido.

---

## GAPS — Lo que NO existe hoy

1. **`transformReadout` y `transformNudge` son estado huérfano** — se calculan correctamente pero ningún elemento de UI los muestra al usuario durante el drag. No existe barra, HUD ni tooltip que despliegue la medida viva ni que permita escribir un número durante el arrastre para las herramientas move/rotate/scale.

2. **No hay toggle local/global de espacio de coordenadas.** `transformParams` opera siempre en espacio mundo; no hay matriz de objeto que permita restricción en eje local.

3. **`LivePreviewEngine` está cableado pero sin disparadores.** Ningún gesto ni herramienta llama `beginExtrude/beginFillet/…/update(parameter:)` — el motor de preview en vivo está muerto en runtime.

4. **El alpha del `__livePreview` no funciona sin xray.** Los modelos `__*` tienen `opaqueInXray=true` y se dibujan con el pipeline opaco cuando `xrayEnabled=false`. Para un ghost translúcido real se necesita o (a) cambiar la convención de naming para que no lleve `__`, o (b) añadir un flag `isGhost`/`forceTranslucent` al pipeline básico independiente del xray.

5. **No existe HUD flotante anclado a punto 3D durante drag.** `ViewportProjector` existe y proyecta correctamente mundo→pantalla (usado para cotas de medición), pero no hay ningún componente SwiftUI de campo/número anclado al punto de arrastre o al centro del gizmo. Implementarlo requeriría superponer un `GeometryReader` + `Canvas`/`Text` posicionado con `offset` calculado desde `ViewportProjector.project`.

6. **No hay snap con guía visual.** El snap (`snapTransformScalar`) cuantiza el valor y dispara háptico al cruzar un detente, pero no renderiza ninguna guía (línea de snap, highlight de plano, línea de referencia) en el viewport.

7. **`dragFace` push-pull no usa `LivePreviewEngine`.** El preview de cara durante drag es un hack de mover el overlay `__edgeHighlight`; no genera una malla fantasma de la geometría resultante. Conectarlo a `LivePreviewEngine.beginExtrude/update` requeriría llamarlo en `beginTransformDrag` y `applyTransformPreview`.

8. **`PushPullController` no tiene drag en vivo.** La distancia se controla con slider/`NumericField` en una barra estática; no hay drag directo sobre la cara seleccionada.
