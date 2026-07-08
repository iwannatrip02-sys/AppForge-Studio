# BLUEPRINT UX — Batir a Shapr3D + Nomad en una sola interfaz
> 2026-07-08 · Doc canónico de mecánicas. Complementa a DISENO_INTERFAZ.md (que da el contrato
> de gestos); este doc da el CATÁLOGO: cada mecánica de la competencia, por qué es ingeniosa,
> y cómo la robamos-y-mejoramos. Toda ola de UI futura cita secciones de aquí.

---

## PARTE 1 — SHAPR3D: desglose de mecánicas

### 1.1 La filosofía (lo que de verdad los hizo ganar)
No fue el kernel (Parasolid, como Fusion). Fue **eliminar la pregunta "¿dónde está la
herramienta?"**. En Fusion360 el usuario navega menús para encontrar la operación; en Shapr3D
**la selección ES el menú**: tocas algo y la app te ofrece solo lo que tiene sentido para eso.
El catálogo de 40 herramientas se filtra a 4-6 relevantes en cada momento.

### 1.2 Mecánicas, una a una

| # | Mecánica | Por qué es ingeniosa | Cómo la superamos |
|---|---|---|---|
| S1 | **Dos manos, dos roles**: Pencil dibuja/selecciona/actúa; el dedo SOLO navega cámara. Nunca compiten. | Elimina el modo-error más común del 3D táctil: "quise rotar y moví el objeto". El hardware define el rol, no un botón de modo. | Ya tenemos el router geometría/vacío. Añadir: pencil siempre herramienta (UITouch.type == .pencil), y además presión del pencil = intensidad en sculpt (Nomad lo hace, Shapr3D no — nosotros en AMBOS mundos). |
| S2 | **Adaptive menu (selección filtra catálogo)**: cara → offset/push-pull/draft/shell; arista → fillet/chamfer; cuerpo → boolean/transform/mirror; nada → sketch/primitivas. | El usuario nunca aprende dónde viven 40 herramientas; aprende UNA regla: "toca y mira qué te ofrece". Curva de aprendizaje plana. | Generalizar nuestra pushPullBar a una **barra contextual por tipo de selección**. Necesita: picker de ARISTAS B-rep (hoy solo caras — nueva pieza en ScenePicking). Mejora: la barra muestra también el ATAJO de gesto de cada acción ("arrastra la cara ↑") — enseña el camino rápido mientras lo usas. |
| S3 | **Extrude por drag con número vivo**: tocas región/cara, arrastras, la distancia se muestra EN GRANDE junto al dedo; tap sobre el número → teclado numérico para valor exacto. | Une lo táctil (feel) con lo ingenieril (precisión exacta) sin modal ni panel. El número siempre editable = confianza CAD. | PushPullController ya separa selección de aplicación. Implementar drag-en-cara → preview en vivo (BRepFeat con distancia del drag) + **NumericPad flotante** al tocar el número. Mejora: el número recuerda las últimas 5 distancias usadas (chips). |
| S4 | **Sketch con auto-constraints e inferencia**: dibujas a mano alzada, la app detecta línea/arco/círculo, infiere paralelo/perpendicular/tangente/coincidente y los muestra como badges tocables. Regiones cerradas se detectan y sombreean → tap región = cara extruible. | Convierte el garabato en geometría exacta sin que el usuario conozca la palabra "constraint". La región sombreada es affordance pura: "esto ya es un objeto, tócalo". | Tenemos ConstraintEngine + SnapEngine + CADSketchEngine. Falta: reconocimiento de trazo (fit línea/arco/círculo — matemática simple), detección de regiones cerradas (planar graph → ciclos), y el sombreado tocable. Mejora: **presión del pencil decide "boceto" vs "línea exacta"** (trazo suave = a mano alzada se queda, trazo firme = se ajusta a primitiva). |
| S5 | **History-Based Parametric Modeling (2024-25)**: timeline de pasos re-ejecutable; editar un paso antiguo reconstruye el modelo; variables con expresiones (`altura*2`); preview antes de confirmar cambios. | Direct modeling para la velocidad + historia para el cambio de opinión. El preview-antes-de-aplicar elimina el miedo. | CADHistoryTree + BRepHistory ya existen (undo/redo). Falta re-ejecución paramétrica (guardar la OPERACIÓN con parámetros, no solo el snapshot — BRepHistory hoy guarda shapes). Timeline como tira de chips táctil inferior (deuda #3 de DISENO_INTERFAZ). Mejora: **scrub del timeline con el dedo = ver el modelo reconstruirse** (nadie lo tiene táctil). |
| S6 | **Items manager (árbol de cuerpos)**: panel colapsable con cuerpos/carpetas/visibilidad/aislamiento. Doble tap en item = zoom a él. | Organización sin ventanas: un solo panel, gestos consistentes. | Tenemos Scene3D.models plano. Añadir agrupación + visibilidad + aislar (render solo selección). Mejora: el árbol muestra el TIPO de cada cuerpo (B-rep exacto vs malla sculpt) con badge — clave en nuestra app híbrida. |
| S7 | **Secciones y planos de referencia con drag**: arrastras un plano de sección por el modelo y ves el corte en vivo. | Inspección sin destruir: el corte es una vista, no una operación. | OCCT tiene section reales. Implementar como overlay no-destructivo. Mejora: **sección + cota en vivo** (la sección muestra dimensiones del corte — útil para impresión 3D). |
| S8 | **Boolean por gesto**: arrastras un cuerpo DENTRO de otro → aparece menú union/subtract/intersect con preview coloreado. | La operación booleana deja de ser abstracta: es física ("meto esto aquí"). | BRepModeling.boolean ya es real. Falta el trigger por colisión de drag + preview coloreado (rojo=resta, verde=unión). |
| S9 | **Undo 2 dedos / redo 3 dedos** (tap). | Undo sin buscar botón, desde cualquier estado, ambidiestro. | Implementar global. Nuestro reto: DUAL undo (BRepHistory en CAD, SculptEngine en sculpt) — el router de modo decide cuál recibe el gesto. Mejora: **haptic distinto en undo vs redo** y toast mínimo "Deshecho: Fillet 2mm" (aprendizaje pasivo). |
| S10 | **Drawings 2D con cotas** + export DXF/PDF. | El entregable de ingeniería sin salir de la app. | YA LO TENEMOS (DrawingExportService, Fase C) — Shapr3D lo cobra en tier alto. Falta: cotas automáticas en el plano. |
| S11 | **Visualization**: render PBR en vivo con materiales drag&drop. | El "modo bonito" para enseñar al cliente sin exportar. | Tenemos PBR/IBL shaders + MaterialPresets + RenderMode. Falta drag&drop de material sobre cara/cuerpo. |

### 1.3 Lo que Shapr3D hace MAL (nuestras grietas de ataque)
- **No tiene escultura orgánica en absoluto.** Un jarrón con textura orgánica = imposible.
- **$299/año.** Somos gratis y open-source.
- **Sin animación** (nosotros: AnimationEngine + timeline).
- El sketch 2D sigue siendo un "modo" separado del 3D; la transición sketch→sólido tiene fricción.
- Sin vertex paint / texturizado en-app (solo materiales por cuerpo).

---

## PARTE 2 — NOMAD SCULPT: desglose de mecánicas

### 2.1 La filosofía
**El viewport es sagrado y el dedo es el pincel.** Todo control flota, todo es colapsable,
y los dos controles que importan (radio, intensidad) viven pegados a los pulgares. Nomad ganó
a ZBrush móvil porque respetó el medio: nada de portar UI de escritorio.

### 2.2 Mecánicas, una a una

| # | Mecánica | Por qué es ingeniosa | Cómo la superamos |
|---|---|---|---|
| N1 | **Sliders verticales en los bordes**: radio (borde izq) e intensidad (borde der), siempre visibles, operables con los pulgares SIN soltar la pose de trabajo. | Los 2 parámetros que cambias 200 veces/sesión no requieren ni un tap de navegación. Ergonomía de agarre real de tablet. | Implementar ambos sliders flotantes en modo Sculpt (hoy: sliders en barra inferior). Mejora: **el slider de radio muestra el círculo del pincel en vivo en el centro de pantalla mientras lo arrastras** (Nomad lo hace — igualar), y doble-tap en el slider = volver al valor anterior. |
| N2 | **Cada pincel tiene inverso con un toque** (botón +/- o pulsación secundaria): clay añade/quita, inflate infla/desinfla. | Duplica el vocabulario de pinceles sin duplicar la UI. | SculptEngine: `strength` negativa invierte inflate/flatten/crease trivialmente. Botón "invertir" en la barra sculpt + **pencil: doble-tap del Apple Pencil 2 = invertir pincel** (gesto hardware que Nomad no usa bien). |
| N3 | **Voxel remesh global con slider de resolución** — el corazón del workflow: esculpe sin miedo, funde cuerpos, remesh, sigue. | Libera al usuario de la topología (el terror #1 del 3D). Es el "ctrl+s mental" del escultor. | VoxelRemeshEngine YA existe y ya lo cableamos (Fase D). Falta: slider de resolución + preview del conteo de vértices ANTES de aplicar. Mejora: **remesh local por máscara** (Nomad lo tiene pedido en su foro y no lo ha hecho — nosotros sí: máscara → submalla → remesh → coser). |
| N4 | **Dynamic topology (dyntopo)**: subdivisión LOCAL bajo el pincel mientras esculpes. | Detalle donde lo necesitas sin pagar densidad global. | DynamicTopologyEngine existe en el repo — auditar y cablear al stroke (flag en la barra sculpt). |
| N5 | **Capas de escultura** (blend shapes): cada capa graba deltas de vértices con slider de intensidad -1..2; también capas de pintura. | Iteración sin miedo: "la versión musculosa" es un slider, no un archivo duplicado. | LayerManager existe (capas por tipo). Falta: capa = delta de vértices con slider (morph). MorphEngine/blend shapes ya hay base en Engines. Mejora: **capas compartidas CAD/sculpt** — ver Parte 3. |
| N6 | **Máscaras pintables**: pintas máscara, gesto para invertir, blur de máscara; extract/split por máscara; las herramientas respetan la máscara. | Convierte selección orgánica en primera clase: la mitad de las operaciones avanzadas parten de una máscara. | Nueva pieza: canal de máscara por vértice en Mesh + render tint + respeto en applyDeformer (multiplicar influence por 1-mask). Extract por máscara → nuevo Model. |
| N7 | **Gestos de cámara**: 2 dedos = orbit/pan/zoom simultáneo; doble tap = encuadrar lo tocado; 2-dedos tap = undo, 3 = redo. | Cámara y edición nunca se pisan; el undo es reflejo motor. | Igualar (S9). Nuestro doble-tap ya encuadra en CAD. |
| N8 | **Primitivas paramétricas con gizmo pre-validación**: la esfera/caja/toroide nace editable (radios, segmentos) con gizmo 3D, y se "valida" a malla cuando decides. | Retrasa el compromiso: mientras no valides, sigue siendo exacta. | ¡Esto es un B-REP MENTAL! Nosotros lo hacemos DE VERDAD: nuestras primitivas nacen B-rep OCCT y NUNCA necesitan validarse — se hornean a malla solo si eliges esculpirlas (ver Forge Flow, Parte 3). Superioridad estructural, no incremental. |
| N9 | **Pintura por vértice PBR** (color+roughness+metal por vértice, sin UVs). | Texturizar sin el infierno de UVs; con multires alcanza resolución de textura. | BrushEngine fue eliminado (F3): reimplementar sobre el pipeline de strokes existente escribiendo a color de vértice. Los shaders PBR ya soportan color por vértice (verificar). |
| N10 | **Post-proceso en vivo**: SSAO, bloom, tone mapping, matcaps, HDRI. | El modelo se ve "terminado" mientras trabajas → motivación. | IBL/PBR ya renderiza. Añadir matcaps (baratos) y SSAO si el presupuesto de frame lo permite en iPad. |
| N11 | **Multires (niveles de subdivisión navegables)** estilo ZBrush: bajas a nivel 1, mueves formas grandes, subes a nivel 5 y el detalle se preserva. | El workflow profesional de escultura ES esto. | SubdivisionEngine existe; falta la pila de niveles con detalles guardados por nivel (delta encoding). Pieza grande — ola propia. |

### 2.3 Lo que Nomad hace MAL (grietas)
- **Cero precisión**: no puedes hacer un agujero de exactamente 5mm. Nosotros: kernel OCCT al lado.
- **Sin export CAD** (STEP/DXF/planos). Nosotros ya lo tenemos.
- Los booleanos son de malla (frágiles); los nuestros de B-rep son exactos.
- Organización de escena débil con muchas piezas.
- Sin animación.

---

## PARTE 3 — LA SÍNTESIS: ambos mundos en UNA interfaz (lo nuestro)

### 3.1 El problema real de unificar
El conflicto central: **en Nomad el dedo sobre el modelo esculpe; en Shapr3D el dedo jamás
edita** (solo el pencil). Si mezclamos mal, el usuario CAD arruina su pieza al rotarla y el
escultor siente la app "dura". La solución no es un switch escondido — es que **el material
define el contrato**:

> **REGLA DE ORO: el tipo del objeto define qué hace tu dedo sobre él.**
> - Objeto **exacto** (B-rep vivo): dedo sobre él = SELECCIONA (cara/arista/cuerpo). Nunca deforma.
> - Objeto **libre** (malla horneada): dedo sobre él = PINCEL activo (esculpe).
> - Vacío = SIEMPRE cámara. Pencil = SIEMPRE herramienta, en ambos mundos.
>
> El usuario no aprende "modos": aprende que el metal se toca distinto que la arcilla.
> Feedback inmediato: los objetos exactos se dibujan con aristas marcadas (edge overlay);
> los libres, sin aristas. Se DISTINGUEN a la vista.

Los "modos" de la barra inferior dejan de ser mundos separados y pasan a ser **bancos de
herramientas** sobre la MISMA escena. CAD y Sculpt son perspectivas, no habitaciones.

### 3.2 Forge Flow — el puente que nadie tiene
El flujo asesino que ni Shapr3D ni Nomad pueden ofrecer:

```
   SKETCH ──extrude──▶ B-REP exacto ──[HORNEAR 🔥]──▶ MALLA esculpible
                          │    ▲                          │
                     fillet/shell                    deformers/capas
                     booleans/STEP                   voxel remesh
                          │    │                          │
                          │    └──[RECONSTRUIR ⚙️]────────┘
                          ▼         (feature recognition:
                     planos DXF/PDF   agujeros/cajeras detectados
                                      se re-crean como features)
```

- **Hornear (B-rep → malla)**: un botón en la barra contextual de cuerpo exacto. Tessellate
  (ya existe) + voxel remesh opcional. El B-rep original queda guardado en el historial del
  objeto: "des-hornear" = volver al sólido exacto (perdiendo sculpt, con aviso claro).
- **Reconstruir (malla → features)**: FeatureRecognitionService (Fase C) detecta agujeros y
  cajeras de la malla y ofrece re-crearlos como features B-rep. V1 imperfecta es aceptable:
  nadie más lo intenta siquiera.
- **Caso de uso completo en 60 segundos**: boceto de una taza (S4) → revolve exacto → fillet
  de labio 2mm exacto → hornear → esculpir textura orgánica con clay+dyntopo → capa de pintura
  → volver a CAD para el agujero del colgador Ø5mm exacto en la base aún-exacta → export STL
  a impresión + STEP del cuerpo base + render PBR. **Ni Shapr3D ni Nomad pueden hacer NI LA
  MITAD de esta secuencia.**

### 3.3 Anatomía de pantalla unificada (evolución de DISENO_INTERFAZ §2)

```
┌────────────────────────────────────────────────────────────┐
│ [items ☰]              viewport                    [history]│ ← 2 botones, no barras
│                                                            │
│ R                                                        I │ ← N1: slider Radio (izq)
│ A                LA GEOMETRÍA OCUPA TODO                 N │   e Intensidad (der),
│ D                                                        T │   flotantes, solo en
│ I    [rail de herramientas del banco activo]             E │   objetos-libres
│ O                                                        N │
│                                                            │
│ [═══ barra contextual: SOLO si hay selección ═══] [cubo]  │
│ [CAD] [Sculpt] [Paint] [Anim] [Render]                     │ ← bancos, no mundos
└────────────────────────────────────────────────────────────┘
```

- **Rail izquierdo** = herramientas del banco activo (pulgar izquierdo). En CAD, el rail es
  CORTO (4-5 items) porque el adaptive menu (S2) hace el trabajo; en Sculpt son los pinceles.
- **Barra contextual inferior** = el adaptive menu (S2): aparece con la selección, muere al
  deseleccionar. Con número vivo editable (S3) cuando la acción tiene magnitud.
- **Items** (S6) y **History** (S5) = paneles flotantes colapsables, nunca permanentes.
- Gestos globales: 2-dedos tap undo / 3-dedos redo (S9/N7), doble tap encuadra (N7),
  2 dedos drag = pan, pinch = zoom. Pencil doble-tap = invertir pincel (N2).

### 3.4 Ideas propias (ni Shapr3D ni Nomad las tienen)
1. **Badge de material** en cada objeto del árbol y al seleccionar: `⬡ exacto` / `〰 libre`.
   El usuario siempre sabe qué contrato aplica. (Resuelve la confusión #1 de apps híbridas.)
2. **Scrub del timeline** (S5+): arrastrar el dedo por la tira de historia reconstruye el
   modelo en vivo — "viajar en el tiempo" táctil.
3. **Cotas vivas en sección** (S7+): el plano de corte muestra medidas del perfil en vivo.
4. **Máscara → feature** (N6+S2): pintas máscara sobre un objeto exacto = selección parcial
   de cara para features locales (pocket con forma pintada). Fusión literal de ambos mundos.
5. **Presión = precisión** (S4+): trazo firme del pencil se auto-endereza a primitiva exacta;
   trazo suave queda orgánico. El MISMO gesto sirve a ambos mundos.
6. **Chips de valores recientes** en el numeric pad (S3+): los últimos N valores usados,
   porque el diseño real repite dimensiones constantemente.

### 3.5 Mapa a código existente (nada de esto parte de cero)

| Pieza del blueprint | Ya existe | Falta |
|---|---|---|
| Router dedo/pencil por material | ScenePicking + sculptEnabled (Fase D) | distinción por `model.cadShape != nil` en el router; UITouch.type pencil |
| Adaptive menu (S2) | pushPullBar, BRepModeling, barra contextual | picker de aristas B-rep; registry selección→acciones |
| Número vivo (S3) | PushPullController.distance | drag-en-cara preview; NumericPad flotante |
| Sketch inteligente (S4) | CADSketchEngine, ConstraintEngine, SnapEngine | fit de trazos; detección de regiones; sombreado |
| Timeline (S5) | CADHistoryTree, BRepHistory | ops paramétricas re-ejecutables; tira de chips UI |
| Hornear/Forge Flow | tessellate OCCT, VoxelRemeshEngine, FeatureRecognitionService | botón+flujo+historial de origen B-rep |
| Sliders laterales (N1) | toolVM.radius, sculptEngine.strength | los 2 sliders flotantes verticales |
| Pincel inverso (N2) | strength en deformers | signo + botón + pencil double-tap |
| Dyntopo (N4) | DynamicTopologyEngine | auditar + cablear al stroke |
| Capas morph (N5) | LayerManager, MorphEngine | deltas por capa + slider |
| Máscaras (N6) | — | canal por vértice + respeto en deformers |
| Vertex paint PBR (N9) | pipeline strokes, shaders PBR | reimplementar BrushEngine (F3) |
| Multires (N11) | SubdivisionEngine | pila de niveles con deltas |

### 3.6 Orden de ejecución (olas Fase D, cada una = CI verde + IPA probable en iPad)
- **Ola 2 — "Las manos"**: gestos globales (undo/redo por tap, doble-tap encuadre universal),
  sliders laterales de sculpt (N1), pincel inverso (N2), pencil=herramienta (S1).
  *Criterio: esculpir se siente Nomad; navegar se siente Shapr3D.*
- **Ola 3 — "La selección es el menú"**: picker de aristas, adaptive bar (S2), número vivo +
  numeric pad (S3), fillet/chamfer por arista con drag.
- **Ola 4 — "Forge Flow v1"**: hornear con badge de material y regla de oro del router (§3.1),
  des-hornear, remesh con slider de resolución (N3).
- **Ola 5 — "Sketch mágico"**: fit de trazos, regiones cerradas tocables, extrude por drag
  desde región (S4), presión=precisión (§3.4.5).
- **Ola 6 — "Tiempo"**: timeline paramétrico táctil con scrub (S5), variables simples.
- **Ola 7 — "Nomad parity+"**: máscaras (N6), capas morph (N5), dyntopo (N4), vertex paint (N9).
- **Ola 8 — "Vitrina"**: secciones con cotas (S7), boolean por gesto (S8), items tree (S6),
  matcaps/post (N10), drag&drop materiales (S11).

*Regla de siempre: cada actuador nuevo nace conectado o no nace (lección Fase D).*
