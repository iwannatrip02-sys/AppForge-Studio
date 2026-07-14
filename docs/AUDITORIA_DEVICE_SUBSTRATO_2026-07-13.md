# Auditoría de sustrato de interacción — AppForge Studio (device real)

Fecha: 2026-07-13
Rama: `feature/fase-c`
Alcance: auditoría de SOLO LECTURA. Ningún archivo de código modificado.
Método: Serena (símbolos) + Grep/Read dirigidos. Rutas verificadas contra el árbol real.

Base de código real: la raíz del proyecto Xcode es `ios-app/AppForgeStudio/`.
Los archivos "semilla" existen pero con rutas distintas a las supuestas:
- `Sources/Services/ScenePicking.swift`
- `Sources/Services/SketchController.swift` (sistema de sketch ACTIVO)
- `Features/CADMode/CADSketchEngine.swift` (sistema de sketch PARALELO / muerto)
- `Features/CADMode/CADModeView.swift` (orquestador central, 2424 líneas)
- `Core/UI/MetalView.swift` (gestos + raycast toque→plano)
- Gizmo: `Sources/Services/GizmoBuilder.swift` (mallas) + lógica en `CADModeView`
- Transform: métodos en `CADModeView` (`transformParams`, `applyTransformPreview`, `bakeTransform`)
- Pattern: `Sources/Services/BRepModeling.swift` (`linearPattern`, `circularPattern`)
- Export: `Features/ExportMode/ExportView.swift`, `ARQuickLookView.swift`, `ExportServiceSTEP.swift`
- Region: `Sources/CAD/SketchRegionDetector.swift`

---

## (a) Veredicto sobre la causa raíz del sustrato

**CONFIRMADA (con matices).** El sustrato de interacción está fragmentado. Las
cuatro sospechas se verifican en código, con un quinto factor añadido que es el
más grave:

1. **Doble sistema de sketch — CONFIRMADO y peor de lo supuesto.** Coexisten dos
   motores de sketch VIVOS con estado separado, y el segundo produce geometría
   vacía:
   - `SketchController` (propiedad `sketch` en `CADModeView`) — sistema activo:
     taps/drags en viewport, regiones, spline, arcos, `extrudeRegion` que SÍ
     genera sólidos B-rep reales vía OCCT.
   - `CADSketchEngine` (propiedad `sketchEngine` en `CADModeView:25`) — sistema
     paralelo: alimenta el Timeline, constraints, PencilKit import y el botón
     "Extruir" del `parameterBar`. Pero su `extrudeSketch(distance:)` es un STUB:
     `return Mesh()` (malla vacía) — `CADSketchEngine.swift:205-209`, con
     `TODO(F3)`. Y `CADModeView.performExtrusion()` es un NO-OP explícito:
     `let mesh: Mesh? = nil // For now, extrusion is a no-op that compiles`
     (`CADModeView.swift:1977-1980`).
   - Resultado: el usuario tiene DOS "sketch" que se comportan distinto; uno crea
     sólidos solo por arrastre de región, el otro no crea nada.

2. **`allowsHitTesting(false)` en el overlay de sketch — CONFIRMADO.**
   `SketchCanvasOverlay` se dibuja con `.allowsHitTesting(false)`
   (`CADModeView.swift:557`). Es puramente visual. TODA la entrada del sketch
   pasa por el raycast de `MetalView` (`planePoint(at:in:)`,
   `MetalView.swift:570`). Esto no es malo en sí, pero acopla toda la interacción
   a un único `handlePan` cuyo router decide qué hacer según banderas.

3. **Tres+ enums de modo/herramienta duplicados — CONFIRMADO.**
   - `AppState.AppMode` (`AppState.swift:66`) — modos top-level.
   - `CanvasViewModel.AppMode` (`CanvasViewModel.swift:192`) — segundo enum homónimo.
   - `WorkspaceToolViewModel.ActiveMode` + `ActiveTool` (`WorkspaceToolViewModel.swift:7,20`).
   - Herramientas: `CADTool`, `SketchTool`, `SketchController.Tool`,
     `CADSketchEngine.SketchEngineTool`, `CADModeView.ToolGroup`/`CADModeTab`.
   La entrada de gestos se enruta según `selectedTool` (un `CADTool`), pero el
   sketch depende del `SketchController.Tool` interno y el otro sketch de
   `SketchEngineTool`. La verdad de "en qué herramienta estoy" está repartida.

4. **"La selección es el menú" a medias — CONFIRMADO.** El `SelectionController`
   distingue `bodyIndex: Int?` de `items: [Item]` (face/edge/vertex,
   `SelectionController.swift:20-34`). La `selectionBar` muestra acciones según
   qué haya seleccionado — PERO las acciones de sub-objeto (cara/arista) son solo
   Push/Pull, Quitar, Redondear, Chaflán. No hay mover/rotar/escalar sub-objeto.
   El único puente a transform es el botón "Cuerpo" (`escalateToBody`), que sube
   la selección al cuerpo entero.

**Factor raíz #5 (el que amplifica todo): el gizmo/transform opera SIEMPRE sobre
el cuerpo entero.** `activeGizmoCenter` y el drag del gizmo leen
`selectionController.bodyIndex` (`CADModeView.swift:147-152`, `473`), nunca
`items`. `transformParams` centra en `bboxCenter(of: model)` (cuerpo). No existe
ninguna ruta selección-de-sub-objeto → gizmo → transform de sub-objeto. La única
excepción es `dragFace` (mover UNA cara por push/pull con la herramienta Move),
y para aristas/puntos hay un `showHint("Mover aristas/puntos: próximamente")`
(`CADModeView.swift:450-451`) — es decir, admitidamente NO implementado.

**Evidencia de runtime:** los `syslog_install*.txt` son logs de instalación de
AltStore (WiFi/SMC/CFNetwork/RunningBoard). Cero entradas del proceso de la app,
cero crashes, cero errores de Metal. Los síntomas NO son crashes: son de lógica
de sustrato/UX. Las capturas `ipad_*.png` son estáticas; no aportan más que la
confirmación visual de que las primitivas/fillet/chamfer/bool/shell/pushpull sí
renderizan.

---

## (b) Tabla por síntoma

| # | Síntoma | Estado real | file:símbolo del eslabón roto | Seam del arreglo |
|---|---------|-------------|-------------------------------|------------------|
| 1 | Escalar arista/cara escala TODO el cuerpo | CONFIRMADO. Sub-objeto nunca llega al transform; solo `bodyIndex` alimenta gizmo/transform. Aristas/puntos: `showHint("próximamente")` | `CADModeView.activeGizmoCenter` (147-152); `onGizmoDragBegan`→`dragModelIndex = selectionController.bodyIndex` (473); `transformParams` centra en `bboxCenter(of: model)` (2007-2050); rama sub-objeto ausente (439-454) | En `transformParams`/`applyTransformPreview`/`bakeTransform`: enrutar por `selectionController.lastItem` (face/edge) → transform de sub-objeto (BRep local move-face / edge, o escala local con centro = centroide del sub-objeto). Nuevo puente en `SelectionController` que exponga el centro del sub-objeto seleccionado |
| 2 | Gizmo feo, no anclado, sin local/global, se reinicia tras rotar, sin numérico, sin snap | PARCIAL. Gizmo sí se ancla a `bboxCenter` y viaja con el cuerpo en el preview (`applyTransformPreview` 2088-2094). "Reset al origen" = el preview usa TRS del `Model`; `bakeTransform` aplica al B-rep y luego `resetPreviewTRS` (2136,2097-2101) → si el bake falla o hay un frame de desfase, el TRS vuelve a identidad. Sin toggle local/global, sin snap, sin entrada numérica: no existen en el código | `CADModeView.rebuildGizmoOverlays` (181-205), `transformParams` (2007-2050), `bakeTransform`/`resetPreviewTRS` (2105-2187/2097-2101); hit-test `MetalView.gizmoAxisHit` (601-639) | (i) Estado de rotación acumulado: mantener quaternion acumulado en el controller en vez de reemplazar `model.rotation = q`. (ii) Toggle local/global: parámetro de espacio en `transformParams` (usar ejes del `Model.rotation` vs mundo). (iii) Entrada numérica: campo en la barra de transform → alimenta `dragAccum`/ángulo. (iv) Snap: cuantizar `amount`/`angle`/`factor` en `transformParams` |
| 3 | Sketch: sin drag-para-dibujar; arcos/spline/snap flojos; sin numérico | CONFIRMADO el punto clave: el drag-para-dibujar SOLO se activa con Apple Pencil. `handlePan` gatea `onSketchDragBegan` tras `lastTouchWasPencil` (`MetalView.swift:348`); con el dedo, un drag ORBITA la cámara (388-389). Arcos/spline SÍ existen en `SketchController.Entity`; snap existe (`snapRadius`, `SnapEngine`) pero el radio es fijo | `MetalView.handlePan` router (336-392, cond. 348); overlay pasivo `CADModeView:557` (`allowsHitTesting(false)`) | En `handlePan .began`: permitir `onSketchDragBegan` también con el dedo cuando `isSketchTool` y hay una herramienta de trazo activa (line/arc/spline), reservando orbitar a 2 dedos o a "select". Entrada numérica de medidas: campo en `sketchBar` que fije longitud/radio del último trazo vía `SketchController.editSelected*` |
| 4 | Sketches no cortan/extruyen; regiones cerradas → 3D incompleto | MIXTO. `SketchRegionDetector` es REAL (ciclos de grafo planar, 116-206). La ÚNICA ruta que produce sólido es `SketchController.extrudeRegion` (811-829) vía arrastre de región (`finishRegionDragExtrude`, 1112-1137) — y es SIEMPRE ADITIVA (`addModel`), nunca corte/boolean. El botón "Extruir" del otro sketch (`sketchEngine`) es NO-OP: `CADSketchEngine.extrudeSketch` = `return Mesh()` (205-209) y `performExtrusion` = `mesh = nil` (1977-1980) | `CADSketchEngine.extrudeSketch` (205); `CADModeView.performExtrusion` (1969-1989); ausencia de rama boolean en `extrudeRegion`/`finishRegionDragExtrude` | (i) Matar el pipeline muerto: eliminar `performExtrusion`/`sketchEngine.extrudeSketch` o re-cablearlo a `SketchController`. (ii) Corte: en `finishRegionDragExtrude`, si el sketch está sobre la cara de un cuerpo existente, ofrecer restar (`OCCTBooleanEngine`/`BRepModeling` boolean) en vez de solo `addModel` |
| 5 | Pattern solo al crear primitiva; falta lineal | REFUTADO parcialmente. `linearPattern` y `circularPattern` SÍ existen y SÍ son acción sobre cuerpo seleccionado (`selectionBar`, botones "Patrón ×3" / "Patrón ○×6", `CADModeView.swift:1239-1269`). PERO: (a) solo visibles con `bodyIndex != nil` (hay que pulsar "Cuerpo" antes si tienes cara/arista); (b) parámetros HARDCODEADOS (×3, ○×6, spacing calculado), sin UI de cantidad/eje/espaciado | `CADModeView.selectionBar` (1239-1269); `BRepModeling.linearPattern`/`circularPattern` (199,222) | Exponer un panel de parámetros (count/spacing/axis) para patrón; hacer el botón un `parameterBar` como los demás. El patrón LINEAL ya existe: el arreglo es de UI/descubribilidad, no de motor |
| 6 | Fantasmas: puntos/aristas se quedan en la pos vieja; malla colapsa a un punto en drag | CONFIRMADO como bug de refresco de overlay. Los highlights de cara/arista son MODELOS overlay separados (`__faceHighlight`, `__edgeHighlight`) que solo se reconstruyen vía `.onChange(highlightMesh)` reactivo (651-681), no atados al TRS/geometryVersion del cuerpo que se mueve. Además, durante `applyTransformPreview` el `__edgeHighlight` se REUTILIZA como ghost de cara (`overlay.position = df.normal * d`, 2063) — puede colapsar visualmente | `CADModeView` overlays reactivos (651-681); reuso del highlight en `applyTransformPreview` (2059-2066); gizmos con TRS propio (2088-2094) | Reconstruir/mover los overlays de highlight DENTRO del mismo tick que el cuerpo (en `applyTransformPreview`/`bakeTransform`), no vía `.onChange`. Alternativamente, ocultar highlights durante el drag y regenerarlos al soltar. Separar el ghost de cara del `__edgeHighlight` reutilizado |
| 7 | Export "extraña"/rota; sin botón dedicado; sin formatos/calidad/nombre; AR no real | REFUTADO en su mayor parte. `ExportView` es RICO: formato (`ExportFormat.allCases`), calidad (`ExportQuality`), nombre (`exportFileName`), validación, progreso real, share, import, y AR Quick Look REAL de Apple (`ARQuickLookView` = `QLPreviewController` con USDZ). El problema es de ACCESO: `ExportView` solo se instancia desde `RenderModeView` (`RenderModeView.swift:81-95`). Desde CADMode el único export es STEP directo por alerta (`exportToSTEP`, 1914-1966). No hay botón de export rico en CAD | `AppForgeStudioApp.swift:147-148` (Render es un modo aparte); `RenderModeView.swift:81` (único punto que abre `ExportView`); `CADModeView.exportToSTEP` (1914-1966) | Añadir un botón "Exportar" en CADModeView que presente `ExportView` como sheet (igual que `RenderModeView`), reutilizando el `ExportViewModel` ya existente en `AppState`. Cero motor nuevo: es wiring de navegación |

---

## (c) Mapa de símbolos del pipeline selección → gizmo → transform → sub-objeto

```
TOQUE (1 dedo)
  └─ MetalView.Coordinator.handlePan(.began)            MetalView.swift:336
       ├─ [sketchInputEnabled && lastTouchWasPencil] → onSketchDragBegan   (348) ← DEDO NO ENTRA (síntoma 3)
       ├─ [transformEnabled]
       │     ├─ gizmoAxisHit(at:) != nil → onGizmoDragBegan(axis)          (356-358, 601)
       │     │        └─ CADModeView.onGizmoDragBegan:                      (470-474)
       │     │             gizmoAxis = axis
       │     │             dragModelIndex = selectionController.bodyIndex   ← SIEMPRE CUERPO (síntoma 1)
       │     └─ ScenePicker.hitTest → onTransformBegan(hit)                 (362-364)
       │            └─ CADModeView.onTransformBegan:                        (431-456)
       │                 · si hay cara seleccionada → dragFace (push/pull)  (441-448)  ← única ruta sub-objeto
       │                 · si hay arista/punto → showHint("próximamente")   (450-451)  ← NO IMPLEMENTADO
       │                 · else → dragModelIndex = hit.modelIndex           (455)
       └─ TAP (select) → selectionController.handleTap(hit:)               (407)
              └─ SelectionController: llena items[] (face/edge/vertex) o bodyIndex  SelectionController.swift:47

DRAG
  └─ handlePan(.changed) → onTransformChanged(dx,dy)                        MetalView.swift:403
       └─ CADModeView.applyTransformPreview()                              CADModeView.swift:2055
            └─ transformParams(for: model)  → centro = bboxCenter(CUERPO)  2007-2050 / 160-168
            └─ escribe model.position/rotation/scale (PREVIEW TRS)         2072-2085
            └─ mueve gizmos __gizmoX/Y/Z con el mismo TRS                  2088-2094
            └─ (highlights NO se mueven aquí → fantasma, síntoma 6)

SOLTAR
  └─ handlePan(.ended) → onTransformEnded()                               MetalView.swift:448
       └─ CADModeView.bakeTransform()                                     CADModeView.swift:2105
            ├─ dragFace → BRepModeling.pushPullFace (mover cara real)      2109-2132
            ├─ cadShape → BRepModeling.translate/rotate/scaleUniform       2137-2163  (CUERPO)
            ├─ malla → hornear a vértices world-space                      2164-2182
            └─ resetPreviewTRS(model) → TRS a identidad                    2136/2097  ← "reset" (síntoma 2)
            └─ rebuildGizmoOverlays()                                      2186/181

SELECCIÓN (modelo de datos)
  SelectionController.bodyIndex : Int?        ← lo ÚNICO que ve el gizmo
  SelectionController.items     : [Item]      ← face/edge/vertex, NO llega al gizmo
  SelectionController.escalateToBody()        ← único puente items → bodyIndex → transform de CUERPO

SKETCH (dos motores, estado separado)
  sketch      : SketchController   (ACTIVO)   → extrudeRegion → sólido B-rep real (ADITIVO)
  sketchEngine: CADSketchEngine    (PARALELO) → extrudeSketch = Mesh() vacío (MUERTO)
```

---

## (d) Orden de arreglo recomendado por apalancamiento

Ordenado por cuántos síntomas desbloquea cada arreglo y por dependencia.

1. **Unificar el modelo de selección → transform (desbloquea síntomas 1, 2, 6 en parte).**
   Hacer que `activeGizmoCenter`, `onGizmoDragBegan`, `transformParams`,
   `applyTransformPreview` y `bakeTransform` lean el objeto activo de una sola
   fuente ("selección activa" que puede ser cuerpo O sub-objeto), exponiendo su
   centro y su ruta de bake. Este es el nudo del sustrato: casi todo lo demás
   cuelga de aquí. Sin esto, el gizmo nunca podrá tocar sub-objetos.

2. **Colapsar el doble sistema de sketch (desbloquea síntoma 4 y limpia el 3).**
   Elegir `SketchController` como único motor. Retirar/re-cablear
   `CADSketchEngine.extrudeSketch` y `CADModeView.performExtrusion` (hoy no-ops
   que engañan al usuario). Mantener el Timeline/constraints alimentándose del
   motor único. Elimina una clase entera de "botones que no hacen nada".

3. **Abrir el drag-para-dibujar al dedo (síntoma 3).** Quitar el gate
   `lastTouchWasPencil` en `handlePan .began` para herramientas de trazo, moviendo
   la desambiguación a nº de dedos / herramienta activa. Cambio quirúrgico en un
   solo `switch`, alto impacto en la sensación del sketch.

4. **Refresco atómico de overlays (síntoma 6).** Mover la actualización de
   `__faceHighlight`/`__edgeHighlight` al mismo tick del transform (dentro de
   `applyTransformPreview`/`bakeTransform`), o esconderlos durante el drag. Depende
   de #1 estar hecho para no duplicar lógica.

5. **Añadir corte booleano al extrude de región (segunda mitad del síntoma 4).**
   En `finishRegionDragExtrude`, detectar sketch sobre cara de cuerpo existente y
   ofrecer restar vía el motor boolean ya presente. Depende de #2.

6. **Wiring de export en CAD (síntoma 7).** Presentar el `ExportView` existente
   como sheet desde `CADModeView` reusando el `ExportViewModel` de `AppState`.
   Trivial, sin motor nuevo. La vista ya es completa; solo le falta puerta.

7. **UI de parámetros de patrón y de transform numérico (síntomas 5 y 2).**
   Convertir "Patrón ×3/○×6" en un `parameterBar` con count/eje/espaciado; añadir
   campos numéricos de ángulo/distancia y snap a la barra de transform. Motores ya
   existen (`linearPattern`, `circularPattern`, `transformParams`); es UI.

**Nota de honestidad (patrón histórico "✓ pero muerto"):** los dos casos
literales encontrados son `CADSketchEngine.extrudeSketch` (`return Mesh()`) y
`CADModeView.performExtrusion` (`mesh = nil`, "no-op that compiles"). Ambos con
`TODO(F3)`. Ningún crash en syslog: los fallos son de sustrato lógico/UX, no de
estabilidad.
