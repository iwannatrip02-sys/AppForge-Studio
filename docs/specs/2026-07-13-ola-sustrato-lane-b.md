# SPEC — Ola de Sustrato (Lane B): unificar selección→transform + colapsar doble sketch
> 2026-07-13 · Fuente de verdad del diagnóstico: `docs/AUDITORIA_DEVICE_SUBSTRATO_2026-07-13.md`.
> Producido con la disciplina de spec-kit (estado verificado + contrato + criterios de aceptación testables).
> Ejecutan **2 agentes Opus 4.8 en paralelo con propiedad de archivos DISJUNTA + contrato de API**.

## Contexto

El usuario probó la beta en iPad real: "todas las herramientas tienen errores". La auditoría
confirmó que NO es inestabilidad (los syslogs no muestran crashes) sino un **sustrato de
interacción fragmentado**. Un solo nudo genera la mayoría de síntomas: **gizmo/transform
siempre operan sobre `selectionController.bodyIndex` (cuerpo entero); la selección de
sub-objeto (`items[]`) nunca llega al transform.** Además hay un **doble sistema de sketch**
donde el camino de extrude es un no-op que compila.

## Estado verificado (file:símbolo, de la auditoría)

| # | Síntoma | Eslabón roto | Archivo:símbolo |
|---|---|---|---|
| 1 | Escalar/mover arista o cara mueve TODO el cuerpo | transform usa bodyIndex, no items | `CADModeView.activeGizmoCenter` (~147-152); `onGizmoDragBegan → dragModelIndex = selectionController.bodyIndex` (~473); aristas/puntos: `showHint("próximamente")` (~450-451) |
| 2 | Gizmo se reinicia tras rotar; sin numérico/snap | preview usa TRS del Model; `bakeTransform` llama `resetPreviewTRS` a identidad tras hornear | `CADModeView` (bake/preview TRS) |
| 3 | Sin drag-para-dibujar con el dedo | drag de sketch gateado tras pencil | `MetalView.handlePan` gate `lastTouchWasPencil` (~348) |
| 4 | Sketch no corta/extruye | no-ops que compilan | `CADSketchEngine.extrudeSketch` (~205) `return Mesh()`; `CADModeView.performExtrusion` (~1977-1980) `mesh=nil`; único vivo `SketchController.extrudeRegion` = siempre aditivo |
| 5 | Patrón solo hardcodeado, sin panel | linear/circular sin parámetros de UI | `CADModeView.selectionBar` (~1239-1269) |
| 6 | Puntos/aristas fantasma al mover | overlays `__faceHighlight`/`__edgeHighlight` reconstruidos por `.onChange`, no siguen el TRS durante drag | `CADModeView` (~651-681) |
| 7 | Export "extraño", sin puerta en CAD | `ExportView` (rica) solo abre desde Render | `RenderModeView.swift:81`; CAD solo STEP directo |

## El CONTRATO (frontera Agente 2 → Agente 1) — evita colisión

**Agente 2 provee** (en `SketchController`, lógica pura y testeable):
```swift
/// El perfil planar (B-rep face/wire) de la región cerrada activa del sketch, en coords mundo.
/// nil si no hay región cerrada válida bajo el punto/selección activa.
func activeRegionProfile() -> CADShape?

/// Prisma B-rep de extruir la región activa una distancia (mm). Puro: NO toca la escena.
/// Firma OCCT a usar: withPrism/extruded/localPrism — VERIFICAR contra tag v1.8.8.
func extrudedShapeForActiveRegion(distance: Double) -> CADShape?
```
**Agente 1 consume**: reescribe `CADModeView.performExtrusion` para (a) pedir el prisma a
`extrudedShapeForActiveRegion`, (b) decidir `add | cut | newBody`, (c) para `cut`/`add` llamar
al booleano existente `BRepModeling` (Sources/Services) contra el cuerpo objetivo. El motor de
sketch NUNCA modifica la escena; el commit vive en la capa de vista/CanvasViewModel.

Regla dura: ningún agente edita archivos del otro. Si Agente 1 necesita algo más del sketch,
lo pide AMPLIANDO ESTE CONTRATO (nueva firma aquí), no editando `SketchController`.

## Alcance — Agente 1 (capa vista/gesto)
**Dueño exclusivo:** `Features/CADMode/CADModeView.swift`, `Core/UI/MetalView.swift`, y los archivos de gizmo/transform (localizar: grep `Gizmo`/`TransformTool`). NO tocar `SketchController.swift` ni `CADSketchEngine.swift`.

1. **Resolver de objetivo de transform**: extraer una función pura `transformTarget(selection) -> TransformTarget` que devuelva el sub-objeto seleccionado (cara/arista/vértice) si lo hay, si no el cuerpo. `activeGizmoCenter` y `onGizmoDragBegan` la consumen. El gizmo se ancla al **centroide del sub-objeto**, no al centro del cuerpo.
2. **Mover CARA = push/pull real** vía la op de kernel existente (`BRepModeling.pushPullFace`/offsetFace). Este es el mecanismo estrella (lo que el usuario llama "pushear la base"). Debe funcionar con arrastre del gizmo + valor numérico en vivo.
3. **Arista/lazo y vértice (HONESTIDAD, ver §Realismo)**: anclar gizmo + numérico SIEMPRE; la geometría real solo si hay API OCCT verificada. Si no, estado claro "no soportado aún" — CERO botón falso.
4. **Sin reinicio del gizmo tras rotar**: acumular el TRS entre operaciones; no resetear a identidad mientras el gizmo esté activo. Hornear al B-rep sin perder el ancla visual.
5. **Numérico + snap** en el transform (distancia/ángulo/factor); snap a incrementos + haptic tick (HapticService ya existe).
6. **Refresco atómico de overlays**: durante drag, los overlays `__*Highlight` siguen el MISMO TRS que el cuerpo (o se ocultan durante el drag y se reconstruyen al soltar). Sin puntos/aristas fantasma.
7. **Panel de parámetros de patrón**: `linearPattern`/`circularPattern` con UI de cantidad/distancia/ángulo (motores ya existen; solo exponer parámetros en `selectionBar`).
8. **Abrir `ExportView` como sheet desde CAD**: botón dedicado de Exportar en el chrome de CAD → presenta la `ExportView` completa (formatos/calidad/nombre/AR). Sin motor nuevo.

## Alcance — Agente 2 (motor de sketch)
**Dueño exclusivo:** `Sources/Services/SketchController.swift`, `Features/CADMode/CADSketchEngine.swift`, y sus tests en `Tests/`. NO tocar `CADModeView.swift` ni `MetalView.swift`.

1. **Implementar el contrato**: `activeRegionProfile()` y `extrudedShapeForActiveRegion(distance:)` reales sobre `SketchController` (región cerrada → face/wire → prisma B-rep). Verificar firmas OCCT contra el tag **v1.8.8** (ver `mem:occtswift_api`) ANTES de llamar.
2. **Colapsar el doble sistema**: neutralizar los no-ops de `CADSketchEngine` (`extrudeSketch return Mesh()`); que todo camino de extrude pase por `SketchController`. Eliminar código muerto, no dejar cáscaras.
3. **Tests con oráculos de volumen** (ver Testing). El corte booleano en sí lo compone Agente 1 vía `BRepModeling`; Agente 2 garantiza que el prisma es correcto.

## Criterios de aceptación

**CI (lógica pura, sin device) — deben pasar en `build.yml`:**
1. `extrudedShapeForActiveRegion(distance:10)` de un rectángulo cerrado W×H → CADShape con volumen ≈ W·H·10 (tolerancia OCCT).
2. Resta booleana de ese prisma contra un box que lo solapa → volumen resultante = box − solape (oráculo exacto, patrón de `BRepModelingTests`).
3. `transformTarget(selección de cara)` resuelve al índice de esa cara, NO a bodyIndex (unit test del resolver puro).
4. Centro del gizmo para una cara seleccionada = centroide de la cara (unit test de la función pura extraída de `activeGizmoCenter`).
5. Cero no-ops de extrude: no queda call-site que devuelva `Mesh()` vacío / `nil` en el camino de extrude (función eliminada o test que lo verifica).

**Device (verifica Andrés, entre olas):**
- Cara circular de la base de un cono: el gizmo se ancla a la cara; mover a lo largo de la normal = push/pull con número en vivo.
- Dibujar un rectángulo arrastrando con el DEDO (sin pencil).
- Círculo dentro de una cara → extrude-corte hace un agujero real.
- Mover un cuerpo: sin puntos/aristas fantasma.
- Rotar un cuerpo: el gizmo se queda, no se reinicia.
- Seleccionar cuerpo → panel de patrón con cantidad/distancia.
- Botón Exportar en CAD abre la hoja completa de export.

## Testing pyramid
| Capa | Qué | Nuevos |
|---|---|---|
| Unit | resolver de transform target; centroide de sub-objeto; prisma de región (volumen); no-op eliminado | +5 |
| Integration | región→prisma→booleano corte contra box (volumen) | +2 |
| Device (manual, Andrés) | los 7 flujos de arriba | 7 |

## Realismo / honestidad (regla dura del repo: cero botones falsos)
- **Mover cara = push/pull (offsetFace): REAL, se entrega.** Es el 80% del valor.
- **Escalar arista/lazo ("hacer la base más ancha"): op de modelado directo dura.** Intentar SOLO si existe API OCCT verificada (v1.8.8) que lo haga bien; si no, entregar el gizmo anclado + numérico pero con estado honesto "no soportado aún" y reportarlo. NADA de fingir éxito.
- **Mover vértice: probablemente diferir** (lo más difícil). Anclar gizmo, sin geometría falsa.
- **Verificar TODA firma OCCT contra el tag v1.8.8 antes de llamar** — es el fallo #1 histórico del repo (código contra API imaginaria). Clonar el paquete, `checkout v1.8.8`, grep de la firma.
- No compilar localmente cuenta como hecho: se verifica en CI (`build.yml`) + device.

## Fuera de alcance (esta ola)
Fillet/trim/offset/mirror de sketch; arcos/curvas/spline avanzada; variables/expresiones;
2D drawings; split body; teclado numérico con aritmética inline (esta ola: numérico simple).
Estas van en la ola siguiente.

## Files reference
| Archivo | Dueño | Cambio |
|---|---|---|
| `Features/CADMode/CADModeView.swift` | A1 | transform target resolver, gizmo anclado, numérico/snap, overlays atómicos, panel patrón, sheet export, reescribir `performExtrusion` para llamar el contrato |
| `Core/UI/MetalView.swift` | A1 | quitar gate `lastTouchWasPencil` del drag de sketch (dedo dibuja) |
| gizmo/transform (grep `Gizmo`) | A1 | acumular TRS, sin reset, ancla a sub-objeto |
| `Sources/Services/SketchController.swift` | A2 | `activeRegionProfile()`, `extrudedShapeForActiveRegion(distance:)`, fuente única |
| `Features/CADMode/CADSketchEngine.swift` | A2 | neutralizar no-ops, eliminar código muerto |
| `Tests/` | A2 | oráculos de volumen de región+corte, resolver de target |

## Próxima ola (WAVE 2 — encolada 2026-07-13, confirmada por Andrés)
> Corre DESPUÉS de que aterricen Agentes 1 y 2 (evita colisión en CADModeView/ScenePicking/SketchController). Propiedad disjunta.

### Q1 · Escalado de arista/lazo a fondo (modelado directo)
Andrés confirma: mover CARA (push/pull) **y** escalar ARISTA/LAZO son AMBOS necesarios. El
escalado de arista/lazo es op dura → wave propia. Insumo: las notas OCCT que devuelva el Agente 1
(qué API existe para modificar/escalar el outer wire de una cara y reconstruir el B-rep).
Investigar: OCCT local ops (BRepTools, reconstrucción desde wire modificado, o "move edges" vía
offset de caras adyacentes al estilo Shapr3D). Entregar real; si es imposible en OCCT, documentar
por qué + la alternativa (p.ej. re-sketch de la cara). CERO botón falso.

### Q2 · Estética de aristas, puntos y dibujos (líneas OSCURAS nítidas tipo Shapr3D)
Problema (device): en muchos casos aristas/puntos/dibujos se renderizan como **TUBOS 3D** (cilindros
barridos) feos. Objetivo: **líneas oscuras, nítidas, anti-aliased**, como Shapr3D — leen la geometría.
- Aristas de display: geometría de tubo → líneas nítidas AA (line primitive / shader), color acero oscuro. NO cilindros.
- Puntos/vértices: puntos pequeños nítidos; no esferas/tubos gordos.
- Dibujos (sketch 2D): mismas líneas nítidas.
- **CONTRASTE (regla dura de Andrés): NO se confunden con el fondo NI con los elementos.** Color oscuro
  con contraste garantizado — halo/outline claro sutil alrededor de la línea, o color adaptativo a la
  luminancia del fondo/superficie. Silueta y aristas-sobre-superficie legibles siempre.
- Identidad Acero & Brasa (`docs/IDENTIDAD_FORGE.md`): default = acero oscuro; seleccionado/highlight =
  brasa. Los "tubos de highlight brasa" actuales → líneas brasa nítidas también.
- Dueños probables (fuera de los agentes vivos): `Sources/Engines/SatinRenderer.swift` (pipeline de
  líneas), `Sources/Shaders/*.metal` (posible shader de línea AA), constructores de geometría de
  arista/punto (grep `tube`/`cylinder`; `BRepEdgePicker.highlightMesh`), `Sources/Theme/`.
- OJO: intento previo `677779a` volvió las aristas *claras* ("no tubos negros"); Andrés ahora quiere
  *oscuras* con contraste. Revisar ese commit para no deshacer lo bueno ni repetir el error de dirección.
