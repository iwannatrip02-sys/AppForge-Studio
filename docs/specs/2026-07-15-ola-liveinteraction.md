# SPEC — Ola LiveInteraction: manipulación directa en vivo (estilo Shapr3D)
> 2026-07-15 · Hechos base: `docs/specs/RECON_LIVEINTERACTION_2026-07-15.md` (file:línea verificados).
> Feedback device de Andrés 2026-07-14 que esta ola resuelve: "no hay preview real de nada,
> todo es slider arriba; el número no es flotante; el snap no muestra medidas ni guías;
> no sé cuánto voy a mover". Ejecutan 2 agentes Opus con propiedad DISJUNTA.

## Hechos del RECON que mandan el diseño
1. `transformReadout`/`transformNudge` se calculan por frame (`applyTransformPreview`, CADModeView:2343) — **nadie los muestra** (`parameterBar` cae a `EmptyView` para move/rotate/scale).
2. `LivePreviewEngine` (Sources/Services) tiene API completa `beginExtrude/beginFillet/update/commit/cancel` + generación de malla fantasma OCCT baja calidad + código de inyección en escena (CADModeView:599-618). **Cero llamadas hoy.**
3. `ViewportProjector.project(_:)` (Views/DimensionOverlayView.swift:15) proyecta mundo→pantalla con `canvasVM.viewMatrix`/`projectionMatrix` — el HUD flotante NO necesita infraestructura nueva.
4. **Obstáculo A**: modelos `__*` tienen `opaqueInXray=true` → el fantasma `__livePreview` NO se ve translúcido sin rayos-X.
5. **Obstáculo B**: add/remove de modelo = `rebuildSceneFrom` completo (SatinRenderer:921) → el fantasma debe VIVIR en escena y mutarse in-place (patrón ya existente del sculpt in-place refresh).

## CONTRATO (frontera L1↔L2) — basado en NOMBRE, sin API nueva
El modelo de escena llamado **`__livePreview`** (constante existente del código de inyección) es EL fantasma:
- **L1 garantiza**: se renderiza SIEMPRE translúcido (ghost) aunque `xrayEnabled=false`; su geometría/transform se actualizan **in-place sin rebuild** del renderer; sigue siendo no-tocable (prefijo `__`) y NUNCA se exporta.
- **L2 garantiza**: solo lo alimenta vía `LivePreviewEngine` + el código de inyección existente; lo retira al commit/cancel.
Estética del fantasma (tokens `docs/design/design_tokens.json`): tinte ember `#FF7A45` a alpha ~0.35-0.45 + wireframe/borde sutil — L1 define el material Metal equivalente.

## Carril L1 — sustrato de render del fantasma (Opus)
**Dueño exclusivo:** `Sources/Engines/SatinRenderer.swift` (+ `Sources/Engines/Model3D.swift`/`Scene3D` SOLO si necesita un flag) + tests renderer.
⚠️ NO ARRANCAR hasta que el agente MESH-QUALITY haya aterrizado (puede tocar SatinRenderer).
1. Ghost path: `__livePreview` → pipeline translúcido SIEMPRE (independiente de xray). Material tinte ember, alpha del token, sin escribir depth de forma que tape la geometría real (decidir orden de render: fantasma DESPUÉS de opacos).
2. Update in-place: cambiar mesh/transform de `__livePreview` NO dispara `rebuildSceneFrom` (espejo del refresh in-place del sculpt). Añadir/quitar el fantasma como tal puede seguir siendo rebuild (ocurre 1 vez por gesto, no por frame).
3. Verificar que los exports (ExportService/ExportViewModel) filtran modelos `__*`; si no, arreglarlo (bug real: hoy podrían exportar overlays).
4. Tests: el update del fantasma no incrementa `rebuildCount` (patrón RendererRegressionTests); export de escena con `__livePreview` presente no lo incluye.

## Carril L2 — capa de interacción (Opus)
**Dueño exclusivo:** `Features/CADMode/CADModeView.swift`, `Core/UI/MetalView.swift`, `Sources/Services/PushPullController.swift`, `Sources/Services/UIProbeMode.swift`, `Features/CADMode/Views/` (componentes nuevos), tests puros nuevos.
1. **HUD flotante** (`TransformHUD`, componente nuevo en Views/): anclado al centro del gizmo vía `ViewportProjector`; muestra `transformReadout` EN VIVO (mono grande, ember, per Design System `.glassPanel(context: .hud)` — ForgeGlass.swift ya existe); TAP sobre el número → editable (NumericField) → aplicar exacto al soltar/confirmar. Reemplaza el `default: EmptyView()` del parameterBar para move/rotate/scale.
2. **Guías de snap visibles**: durante drag con `gridSnapEnabled`: línea-guía del eje activo (proyectada con ViewportProjector) + ticks de incremento + el HUD marca visualmente el detent (cambio de color al snapear, con el haptic existente). El snap ya cuantiza — esto es hacerlo VISIBLE.
3. **Toggle local/global** en la barra del transform; la matemática de `transformParams` respeta el espacio elegido (local = ejes rotados por la orientación del modelo).
4. **Ghost real en push/pull**: `dragFace` → `LivePreviewEngine.beginExtrude` al empezar, `.update(distance)` por frame (alimenta `__livePreview` vía el código de inyección existente), `.commit`/`.cancel` al soltar. Muere el pseudo-ghost de mover-el-highlight.
5. **Drag directo sobre la cara**: con cara seleccionada + tool Mover, un drag que EMPIEZA sobre esa cara = push/pull (no solo desde la flecha del gizmo). Regla de oro intacta: tocar vacío = orbitar.
6. **Extrude de región con ghost**: `performExtrusion`/extrude de sketch usa el mismo begin/update/commit mientras se ajusta la distancia, antes de Añadir/Cortar.
7. **UIProbeMode**: añadir 2 pasos a la secuencia: (a) `LivePreviewEngine.beginExtrude`+`update` sobre una cara SIN commit → captura muestra el fantasma translúcido; (b) commit → captura muestra el sólido cambiado. Logs `PROBE-STEP` correspondientes.
8. Tests puros: cuantización de snap (función extraída), transformación de ejes local/global, formateo del readout.

## Criterios de aceptación
**CI:** tests de L1 (rebuildCount estable en update de ghost; export filtra `__`) y L2 (snap/ejes/formateo) verdes; suite completa verde.
**Probe (evidencia visual, revisa agente Sonnet):** en las capturas: fantasma translúcido ember visible sobre el sólido en el paso (a); geometría cambiada en (b); HUD con número visible si el paso lo permite.
**Device (Andrés, feel):** arrastrar cara = preview en vivo + número flotante editable + guía de snap; el número "se siente Shapr3D".

## Fuera de alcance (olas siguientes)
Re-skin FORGE GLASS completo del chrome; sketch (cerrar regiones/spline/orbitar-con-tool); rail permanente; teclado numérico con aritmética; fillet/chamfer con flecha draggable (usa este mismo sustrato después).
