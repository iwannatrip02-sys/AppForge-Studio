## Problem Statement

Dibujar y manipular en el workspace CAD se siente amateur y no responde donde el
usuario toca. En concreto, desde su iPad: el punto de una línea aparece
desfasado de donde presiona; no puede volver a tocar/seleccionar un círculo,
cuadrado ni línea ya dibujados; no puede mover puntos ni aristas de un dibujo;
las áreas cerradas que forman los dibujos no se pueden extruir; no existe la
previsualización natural arrastrando (como Shapr3D); la selección es "malísima"
y depende de un botón de selección en vez de ser directa. El objetivo del
producto es **reemplazar a Shapr3D por completo**, y hoy la capa de interacción
del sketch no llega a prototipo usable.

## Solution

Llevar la capa de interacción del sketch y la manipulación directa a **paridad
funcional con Shapr3D**: el toque cae exactamente donde el usuario presiona;
toda figura (sketch entity) y sus vértices son seleccionables y arrastrables
directamente en el lienzo; las regiones cerradas (incluidas las formadas por
intersección de segmentos) se sombrean, se tocan y se extruyen; cada operación
muestra un preview fantasma en vivo que se ajusta arrastrando con el dedo o el
Pencil; y la selección es directa (sin depender de un modo/botón), precisa y
fluida, con selección por área estilo Shapr3D (izquierda→derecha vs
derecha→izquierda). Todo respeta la máquina de estados universal de la
herramienta: activar → pedir entrada → preview vivo → commit → encadenable.

## User Stories

1. Como usuario dibujando, quiero que el punto aparezca exactamente donde toco, para dibujar con precisión.
2. Como usuario dibujando, quiero que la precisión se mantenga en los bordes de la pantalla, no solo en el centro.
3. Como usuario, quiero tocar una figura ya dibujada (círculo, rectángulo, línea, polígono, spline) para seleccionarla, tocando su contorno, no solo su centro exacto.
4. Como usuario, quiero que al seleccionar una figura se resalte y se abran sus parámetros editables (radio, tamaño, lados), para ajustarla.
5. Como usuario, quiero arrastrar cualquier vértice/punto de una figura para moverlo, y que la figura se re-forme en vivo.
6. Como usuario, quiero arrastrar una arista (segmento) completa para moverla, no solo sus extremos.
7. Como usuario, quiero que las esquinas de un rectángulo sean todas arrastrables (las cuatro), no solo dos.
8. Como usuario, quiero que al arrastrar un punto con constraints activas, el solver re-resuelva sin deformar el boceto.
9. Como usuario, quiero ver una previsualización fantasma en vivo de la operación (extruir/fillet/chamfer/shell) mientras arrastro, antes de confirmar.
10. Como usuario, quiero ajustar la magnitud de una operación arrastrando con el dedo o el Pencil de forma fluida, como en Shapr3D.
11. Como usuario, quiero poder también teclear un número exacto para la magnitud de la operación, y que ese teclado numérico funcione.
12. Como usuario, quiero que las áreas cerradas por intersección de varios segmentos (no solo perfiles individuales) se detecten como regiones sombreadas.
13. Como usuario, quiero tocar una región sombreada para seleccionarla como base de una operación 3D.
14. Como usuario, quiero extruir una región cerrada y obtener un sólido B-rep real.
15. Como usuario, quiero que revolucionar/barrer/loft acepten regiones igual que perfiles cerrados.
16. Como usuario, quiero seleccionar directamente puntos, aristas y caras sin activar primero un botón/modo de selección.
17. Como usuario, quiero selección por área: arrastrar de izquierda a derecha selecciona lo totalmente contenido; de derecha a izquierda selecciona lo que la caja toca (mecánica Shapr3D).
18. Como usuario, quiero que la selección por área funcione para puntos, aristas y caras según el filtro activo.
19. Como usuario, quiero que las herramientas de transformación (mover/rotar/escalar) operen sobre la selección actual sin re-seleccionar.
20. Como usuario, quiero que una herramienta de dibujo/edición no me expulse al terminar: puedo encadenar varias acciones seguidas.
21. Como usuario, quiero que los dibujos aparezcan en el panel de Elementos y pueda seleccionarlos desde ahí.
22. Como usuario, quiero un solo historial coherente, sin dos historiales distintos en dos esquinas.
23. Como usuario, quiero que al tocar el primer punto de una cadena se cierre el perfil de forma predecible.
24. Como usuario, quiero un indicador claro (badge/hint) de qué está esperando la herramienta activa.
25. Como usuario dibujando líneas, quiero que un quiebre del trazo conmute a arco tangente (línea/arco automático), como Shapr3D.

## Implementation Decisions

- **Consolidar el sistema de sketch**: la manipulación e interacción vive en
  `SketchController` (el que dibuja en vivo). El segundo sistema (`CADSketchEngine`,
  usado solo por el timeline) se reduce/absorbe; el `CADHistoryTree` deja de estar
  duplicado. Ver deuda #1 en `CONTEXT.md`.
- **Un solo camino de entrada de puntero**: los gestos entran por el `MetalView`
  (raycast toque→plano vía `planePoint`/`CameraRay`), que ya proyecta a
  coordenadas de plano. El overlay 2D sigue siendo visual (`allowsHitTesting(false)`);
  no se crea un segundo camino de entrada que compita.
- **Selección directa como parámetro, no como modo**: el hit-test de selección
  (puntos/aristas/caras/entidades de sketch) se resuelve por el mismo raycast; la
  "herramienta Seleccionar" deja de ser prerequisito para poder tocar geometría.
- **Selección por área**: caja en espacio de pantalla; izquierda→derecha =
  contención total, derecha→izquierda = intersección (cruce). Filtro por tipo
  (punto/arista/cara) según el contexto de selección activo.
- **Hit-test de entidades de sketch por contorno**, no solo por centro: distancia
  del toque al anillo del círculo / lados del rect / segmentos de la polilínea,
  con tolerancia cómoda; sin secuestrar el inicio de una figura nueva sobre un
  vértice existente (respetar el fix del loft).
- **Arrastre de puntos completo**: `beginDrag`/`drag`/`endDrag` cubren los 4
  vértices del rect y las aristas (mover segmento = mover sus dos extremos juntos).
- **Regiones → 3D**: `SketchRegionDetector` (grafo planar) produce regiones que
  alimentan `extrude/revolve/sweep/loft` como wires cerrados, no solo los
  `isClosedProfile` de una entidad. La región tocada se vuelve el perfil de la op.
- **Preview en vivo unificado**: `LivePreviewEngine` produce el fantasma de la op
  mientras se arrastra; el commit lo materializa. El mismo camino sirve al drag
  del dedo/Pencil y al valor tecleado.
- **Coordenadas**: `CameraRay.from` debe seguir coincidiendo con
  `SatinRenderer.projectionMatrix` (ADR-0001) — cubierto por test de ida y vuelta.
- **Historial único**: exponer un solo historial en la UI (el `CADHistoryTree`
  del DAG); retirar/ocultar el segundo panel.

## Testing Decisions

- **Qué es un buen test aquí**: probar comportamiento externo a través de seams
  existentes, no detalles de implementación ni la capa SwiftUI. La UI (gestos,
  render) no se testea unitariamente; su LÓGICA sí.
- **Seam #1 — `ScenePicking`/`CameraRay`** (proyección): test de ida y vuelta —
  proyectar un punto mundo→pantalla con las matrices del render y unproyectar
  pantalla→rayo con `CameraRay` debe reintersectar el mismo punto (incluye
  bordes, donde el bug de `aspect²` fallaba). Prior art: no existe aún; es nuevo.
- **Seam #2 — `SketchController` API pública**: `tap`, `beginDrag`/`drag`/`endDrag`,
  `selectEntity`, `entities`, `hasClosedProfile`, `extrudeProfile`. Tests:
  seleccionar por contorno; arrastrar cada vértice re-forma la entidad; cerrar
  perfil; constraints re-resuelven sin deformar. Prior art: `SketchControllerTests`,
  `ConstraintBridgeTests`.
- **Seam #3 — detección de regiones** (`SketchRegionDetector`): dado un conjunto
  de segmentos que se cruzan, produce las regiones cerradas esperadas; una región
  produce un wire cerrado extruible. Prior art: parcial.
- **Seam #4 — selección por área**: dada una caja y un conjunto de entidades,
  izquierda→derecha vs derecha→izquierda seleccionan los conjuntos correctos.
  Prior art: no existe; es nuevo.
- Regla: preferir el seam más alto y el menor número de seams. Estos cuatro son
  los seams existentes/naturales de la lógica de interacción.

## Out of Scope

- **Estética/visual** (aristas sin "tubos", puntos de vértice visibles,
  iluminación, opciones de visualización, belleza de la UI): es un concern
  distinto sin seam de test unitario; va en un **spec hermano de estética**.
- Nuevas herramientas de dibujo que Shapr3D no expone (offset 2D, trim, mirror
  de sketch): fase posterior; este spec es paridad de interacción del set actual.
- 2D Drawings, materiales/render, slicer, animación: fuera del chunk.
- Herramientas de superficie/manufactura avanzadas.

## Further Notes

- Objetivo rector: **reemplazar a Shapr3D**. Este spec cubre la capa de
  interacción; la estética va en paralelo.
- Verificación: CI verde (build + 41 tests + los nuevos) y **prueba en device**
  (AltStore) antes de declarar hecho. El bug de `aspect²` (ADR-0001) ya fue
  corregido; este spec añade su test de regresión y construye encima.
- La mecánica universal de herramienta (activar→entrada→preview→commit→
  encadenable) aplica a TODAS; ver `docs/INGENIERIA_INVERSA_CAD.md` §0.
