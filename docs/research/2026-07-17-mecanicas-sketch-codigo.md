# Mecánicas de Sketch por Código — FreeCAD, SolveSpace, Dune3D vs SketchKernel

**Fecha:** 2026-07-17  
**Investigador:** Claude (subagente de investigación)  
**Objetivo:** Contrastar las mecánicas reales de los sketchers open-source maduros contra nuestro SketchKernel; determinar si snap-first sin solver puede llegar a la sensación Shapr3D.

---

## 1. Fuentes consultadas (código real, no marketing)

| Proyecto | Archivos clave leídos |
|----------|----------------------|
| FreeCAD Sketcher | `src/Mod/Sketcher/App/planegcs/GCS.h`, `GCS.cpp`, `SketchObject.cpp`, `SketchAnalysis.cpp`, `SketchGeometryExtension.h`, `DrawSketchHandler.cpp`, `DrawSketchHandlerLine.h`, `DrawSketchController.h`, `SketcherToolDefaultWidget.cpp`, `ViewProviderSketch.cpp`, `Constraints.h` |
| SolveSpace | `src/sketch.h`, `src/mouse.cpp`, `src/entity.cpp`, `src/constraint.cpp`, `src/system.cpp`, `src/solvespace.h`, `src/generate.cpp` |
| Dune3D | `src/document/entity/entity.hpp`, `src/document/constraint/constraint.hpp`, `src/core/tools/tool_draw_contour.cpp`, `src/core/tools/tool_draw_line_3d.cpp`, `src/core/tools/tool_common.cpp`, `src/core/tools/tool_helper_constrain.cpp`, `src/document/solid_model/solid_model_extrude.cpp`, `src/document/solid_model/solid_model_util.hpp` |
| Nuestro kernel | `SketchModel.swift`, `SnapEngine.swift`, `HitTester.swift`, `RegionFinder.swift`, `CurveGeometry.swift`, `SketchController.swift` |

---

## 2. FreeCAD Sketcher — Arquitectura profunda

### 2.1 planegcs: el solver numérico

Código: `src/Mod/Sketcher/App/planegcs/GCS.h`, `GCS.cpp`  
Licencia: **LGPL-2.1-or-later** (encabezado: `// SPDX-License-Identifier: LGPL-2.1-or-later`)

La clase central es `System`. Implementa **tres algoritmos de resolución**: BFGS (quasi-Newton con line search), Levenberg-Marquardt (dampening adaptativo) y DogLeg (región de confianza combinando steepest descent + Gauss-Newton). El código selecciona entre ellos así:

```cpp
if (alg == BFGS) { return solve_BFGS(subsys, isFine, isRedundantsolving); }
else if (alg == LevenbergMarquardt) { return solve_LM(subsys, isRedundantsolving); }
else if (alg == DogLeg) { return solve_DL(subsys, isRedundantsolving); }
```

**DoF:** El sistema parte el sketch en subsistemas desacoplados mediante `boost::connected_components` sobre un grafo bipartito parámetros↔restricciones. La DoF se calcula por descomposición QR del Jacobiano: `dofsNumber = params - jacobianRank`.

**Diagnóstico de sobre-restricción:** `diagnose()` devuelve tres conjuntos: `conflictingTags` (restricciones mutuamente inconsistentes), `redundantTags` (sin añadir info) y `partiallyRedundantTags`. Tras `hasConflicting()` el solver excluye las redundantes del pase principal y aplica la solución parcial.

**Restricciones disponibles:** Más de 40 tipos incluyendo `ConstraintPointOnBSpline`, `ConstraintSlopeAtBSplineKnot`, `ConstraintSnell` (¡refracción de Snell!), `ConstraintInternalAlignmentPoint2Ellipse`. La lista completa está en `planegcs/Constraints.h`.

**Durante drag:** El sistema guarda una "referencia" con `setReference()` y llama `solve()` en cada frame de drag. La referencia permite refinar la solución iterativamente sin reconstruir el grafo de restricciones, haciendo el drag fluido incluso con sketches complejos.

### 2.2 Flujo de dibujo: DrawSketchHandler / DrawSketchController

**Arquitectura:** `DrawSketchController` es el mediador. Recibe `mouseMoved()` y delega en el handler. Las posiciones se validan (coordenadas finitas) antes de actualizar el estado. Los parámetros numéricos se muestran como `EditableDatumLabel` widgets en la vista 3D misma ("on-view parameters" / OVP).

**Estado de una línea:** `DrawSketchHandlerLine.h` define dos estados (`SeekFirst`, `SeekSecond`). NO hay polilinea automática en el handler de línea aislada — cada segmento es independiente. El encadenamiento de polilineas está en un handler separado (DrawSketchHandlerPolyline).

**Snap/autoconstraint durante el dibujo:** `seekAutoConstraint()` en `DrawSketchHandler.cpp` evalúa en cada movimiento del ratón:
- `seekPreselectionAutoConstraint()`: proximidad a geometría existente (puntos, curvas, ejes)
- `seekLineExtensionAutoConstraint()`: extensión de línea más allá de sus extremos
- Detección de tangencias con círculos/arcos
- Alineación H/V/paralela/perpendicular

El radio de búsqueda es `0.1 * sketchgui->getScaleFactor()` — **adaptativo al zoom**, igual que nuestro `snapRadiusPlane`. Las sugerencias se renderizan como iconos sobre el cursor vía `renderSuggestConstraintsCursor()`.

**Autoconstraint batch post-dibujo:** `SketchAnalysis.autoconstraint()` hace tres pases:  
1. Detectar H/V (ángulo < `angleprecision` de 90°)  
2. Detectar puntos coincidentes sin restringir: `detectMissingPointOnPointConstraints()` agrupa vértices por posición (sort + `adjacent_find`) y genera `ConstraintCoincident` faltantes  
3. Aplicar con `makeConstraintsOneByOne()` verificando rango entre cada adición

**Input numérico:** `SketcherToolDefaultWidget.cpp` gestiona hasta 10 `QuantitySpinBox`. Cuando el usuario escribe un valor, emite `signalParameterValueChanged` → `DrawSketchController` llama `adaptDrawingToOnViewParameterChange()` → avanza el estado del handler. Tab/Enter ciclan entre parámetros. **Esta es la funcionalidad que nos falta para entradas tipo "L=50 mm, A=45°".**

**Geometría de construcción:** Flagging por `GeometryMode::Construction` en `SketchGeometryExtension.h` (bitset de 32 bits). Las curvas de construcción participan en el solver pero no generan aristas en el cuerpo B-Rep resultante.

**Geometría externa:** Las aristas 3D proyectadas al plano viven en `ExternalGeo`, gestionadas por `externalGeoRefMap` y `onExternalGeometryChanged()`. Tienen IDs negativos (`GeoEnum::RefExt`). Participan en snap y restricciones pero son read-only.

---

## 3. SolveSpace — Arquitectura profunda

### 3.1 Modelo entidad/restricción

Código: `src/sketch.h`, `src/entity.cpp`, `src/constraint.cpp`  
Licencia: **GPL-3.0-or-later** (según repositorio GitHub)

Los puntos viven **dentro de cada entidad** (`hEntity point[MAX_POINTS_IN_ENTITY]`, máx 12 puntos por entidad), no en un pool compartido. Es decir: si dos líneas comparten un extremo, eso se expresa mediante una `ConstraintCoincident` explícita, no mediante el mismo PointID — arquitectura opuesta a la nuestra.

**Tipos de restricción:** `ConstraintBase::Type` incluye: coincident, distance, incidence (point-in-plane, on-line, on-face), equal, symmetric, midpoint, horizontal, vertical, diameter, tangent, parallel, perpendicular, angle, equal-angle, length-ratio, arc-length-ratio. Relativamente conservador comparado con planegcs.

**El solver:** Newton-Raphson puro, hasta 50 iteraciones, convergencia por tolerancia. El Jacobiano se descompone con `Eigen::SparseQR`. DoF = `mat.n - jacobianRank`. Para detectar redundancias usa `FindWhichToRemoveToFixJacobian()` — prueba eliminar cada restricción y ve si restaura el rango completo.

**Durante drag:** El código en `mouse.cpp` confirma: el solver se llama **en cada frame de drag** vía `SS.MarkGroupDirtyByEntity()`. El estado pending mantiene `DRAGGING_NEW_LINE_POINT` mientras el usuario mueve el ratón; `UpdateDraggedPoint()` actualiza la posición y dispara la resolución.

### 3.2 Flujo de dibujo ("pending")

`mouse.cpp` revela el estado pending como struct con `operation` enum:
- `Pending::NONE`: navegación normal
- `Pending::COMMAND`: herramienta activa
- `Pending::DRAGGING_NEW_LINE_POINT`: dibujando un segmento

Flujo de línea:
1. **Click inicial:** `AddRequest(Request::Type::LINE_SEGMENT)` → fuerza endpoint al cursor → `ConstrainPointByHovered()` si hay geometría → `pending.operation = DRAGGING_NEW_LINE_POINT`
2. **Movimiento:** `UpdateDraggedPoint()` + solver cada frame
3. **Click final:** `ConstrainPointByHovered()` confirma; si hay geometría enganchada se añade `ConstraintCoincident`; de lo contrario crea un nuevo segmento encadenado por `Constraint::ConstrainCoincident()` entre los extremos adyacentes

**Cierre de contorno:** `if((e->PointGetNum()).Equals(sp->PointGetNum()))` — si el nuevo extremo coincide con el punto inicial, detiene el dibujo en lugar de crear un segmento de longitud cero.

**Geometría de construcción:** Se marca en la request: `SK.GetRequest(hr)->construction = (pending.command == Command::CONSTR_SEGMENT)`. Sin flag separado de "capas" — es propiedad de la request.

### 3.3 Regiones para extrusión

SolveSpace no usa WeldedGraph ni Clipper — genera `SEdge`/`SBezier` lists por entidad y construye shells en `GenerateShellAndMesh()`. El bucle de detección de caras trabaja directamente sobre la geometría paramétrica evaluada.

---

## 4. Dune3D — Decisiones modernas (2023+)

### 4.1 Solver: libslvs con parches propios

Dune3D usa el solver de SolveSpace como biblioteca (`libslvs`), con parches de rendimiento del propio autor (Lukas Kunz): "had to patch the solver to make it sufficiently fast for the kinds of equations I was generating." Confirma que libslvs es lo suficientemente bueno para un CAD moderno pero requiere ajustes finos para conjuntos de ecuaciones grandes.

### 4.2 Entidades: UUID, no handles de 32 bits

A diferencia de SolveSpace (handles enteros) y FreeCAD (enteros + índice negativo para externos), Dune3D usa **UUID** para cada entidad y restricción. La referencia cruzada en restricciones es `EntityAndPoint { UUID, pointIndex }`. Esto simplifica radicalmente la serialización y el undo/redo (no hay reindexación).

**Tipos de entidad:** `LINE_3D`, `LINE_2D`, `ARC_2D`, `ARC_3D`, `CIRCLE_2D`, `CIRCLE_3D`, `STEP`, `POINT_2D`, `BEZIER_2D`, `BEZIER_3D`, `CLUSTER`, `TEXT`, `PICTURE`, `WORKPLANE`, `DOCUMENT`. Notable: Bezier 2D/3D de primera clase (no derivado de B-spline).

**36 tipos de restricción:** incluye `BEZIER_BEZIER_SAME_CURVATURE` (continuidad G2 entre Beziers), `ARC_LINE_TANGENT`, `BEZIER_LINE_TANGENT`. La curvatura continua como restricción explícita es una capacidad que ni FreeCAD ni SolveSpace tienen en el mismo nivel.

### 4.3 Flujo de dibujo: constraints explícitas al dibujar

`tool_draw_contour.cpp` y `tool_draw_line_3d.cpp` muestran el patrón Dune3D:
- Al primer click: crea entidad, `m_selection_invisible = true` para ocultarla como "draft"
- En cada MOVE: actualiza `m_temp_line->m_p2 = cursor` (sin solver por frame — posición libre)
- Al segundo click: añade `ConstraintPointsCoincident` explícita entre el extremo anterior y el inicio del nuevo segmento → solver resuelve
- Para snap: `constrain_point()` en `tool_helper_constrain.cpp` detecta qué hay bajo el hover y aplica `POINTS_COINCIDENT`, `MIDPOINT`, `POINT_ON_LINE`, `POINT_ON_CIRCLE`, o `POINT_ON_BEZIER` según distancia

**Tangencias guiadas:** Cuando hay un segmento tangente previo, proyecta el cursor sobre la dirección tangente: `m_temp_line->m_p2 = m_temp_line->m_p1 + last_tangent * d`. Esto es una guía de inferencia convertida en restricción temporal.

**H/V automático:** `get_auto_constraint()` en `tool_draw_contour.cpp` detecta líneas casi-horizontales/verticales (dentro de 10°) y aplica `ConstraintHorizontal`/`ConstraintVertical` automáticamente. Umbral exacto: `if (std::abs(angle) < 10° || std::abs(angle - 90°) < 10°)`.

### 4.4 Regiones: Clipper2 + OCCT

`FaceBuilder` en `solid_model_util.hpp/cpp` usa **Clipper2Lib** para detectar contornos cerrados:
1. Discretiza cada entidad 2D en `PathD` (~64 puntos por curva)
2. `clipper.Execute(ClipType::Union, FillRule::EvenOdd, poly_tree)` — la operación de unión con EvenOdd resuelve intersecciones y ambigüedades automáticamente
3. Recorre el `PolyTreeD` recursivamente: polígonos padre = exteriores, hijos con `IsHole()` = agujeros
4. `path_to_wire()` reconstruye geometría OCCT precisa a partir del árbol Clipper

El `VertexInfo` en la coordenada Z de Clipper permite rastrear qué entidad original contribuyó a cada punto del contorno — preserva el "diseño intencional" para operaciones booleanas posteriores.

---

## 5. Tabla comparativa: mecánica por mecánica

| Mecánica | FreeCAD | SolveSpace | Dune3D | Nuestro SketchKernel | Veredicto |
|----------|---------|------------|--------|---------------------|-----------|
| **Snap a puntos** | Automático via `seekPreselectionAutoConstraint()`, radio escalado al zoom | Hover-based `HitTestMakeSelection()`, selRadius=10px | `constrain_point()` detecta `POINTS_COINCIDENT` por proximidad | SnapEngine con 9 prioridades, radio adaptativo al zoom | PARIDAD — nuestro sistema es el más sofisticado en prioridades |
| **Guías de inferencia (H/V, alineación)** | Sí, via `seekAutoConstraint()` + `seekLineExtensionAutoConstraint()` | NO (solo snap a puntos existentes) | Guía tangencial (`last_tangent`) + H/V auto ≤10° | H/V desde referencia, alineación H/V con puntos y centros, extensión de líneas | PARIDAD con FreeCAD; mejor que SolveSpace |
| **Snap a intersección de guías** | No explícito (el solver lo resuelve implícitamente) | No | No | Sí, cruce de dos guías de inferencia como candidato de prioridad 5 | VENTAJA — única característica que replica exactamente a Shapr3D |
| **Snap a punto medio** | Sí (seekAutoConstraint detecta midpoint) | Sí (ConstraintMidpoint al hover) | Sí (`constrain_point` detecta `abs(d-0.5) < 0.05`) | Sí, CurveGeometry.midpoint, prioridad 2 | PARIDAD |
| **Snap a cuadrantes** | No encontrado en código revisado | No | No | Sí (N/E/S/O de círculos y arcos, prioridad 4) | VENTAJA |
| **Topología compartida** | NO — puntos duplicados + ConstraintCoincident | NO — igual, puntos per-entidad | NO — UUID + ConstraintCoincident | SÍ — PointID compartido, addOrMergePoint() | VENTAJA ARQUITECTURAL NUESTRA |
| **Solver de restricciones** | planegcs: BFGS/LM/DogLeg, 40+ tipos de restricción | Newton-Raphson, ~20 tipos | libslvs (SolveSpace parchado) | NO EXISTE — snap-first | BRECHA ESTRATÉGICA — ver §6 |
| **Solver durante drag** | Sí, en cada frame (usando setReference snapshot) | Sí, en cada frame | Sí, en cada frame (markGroupSolvePending) | No aplica — movePoint() inmediato sin solver | N/A — nuestro drag es más simple y más rápido |
| **Dimensiones numéricas (input)** | Sí — EditableDatumLabel en viewport, hasta 10 parámetros | Sí — diálogos en viewport | Sí — constraints de distancia/ángulo | NO | BRECHA |
| **Input numérico al dibujar** | Sí — SketcherToolDefaultWidget, Tab entre parámetros | Sí | Sí | NO | BRECHA |
| **Geometría de construcción** | Sí — GeometryMode::Construction (bitset), participa en solver | Sí — flag en Request | No explorado explícitamente | NO | BRECHA |
| **Geometría externa** | Sí — ExternalGeo, IDs negativos, read-only | No directamente | No directamente | NO | Brecha (fase 2) |
| **Hit-testing** | PreselectionAutoConstraint + ViewProviderSketch, prioridad punto > curva | ObjectPicker(selRadius=10px), z-index + distancia | Hover-selection integrado con constraint system | HitTester: punto > curva > región, radio dual adaptativo al zoom | PARIDAD — nuestro sistema tiene .region() que ellos no |
| **Selección de región** | No (FreeCAD selecciona caras del sólido, no regions 2D) | No | No | Sí — RegionFinder WeldedGraph + half-edge | VENTAJA |
| **Cadena de líneas (polilinea)** | Handler separado DrawSketchHandlerPolyline; auto-ConstraintCoincident | Pending::DRAGGING_NEW_LINE_POINT + ConstrainCoincident | m_entities chain + ConstraintPointsCoincident | chainLast/chainStart/chainCount, fusión topológica directa | PARIDAD funcional; nuestra impl más simple |
| **Cerrar contorno** | Snap al primer punto + autoconstraint | `if endpoint.Equals(startpoint)` → stop | `check_close_path()` vía paths::Paths::from_document() | Dual: snap al PointID inicial O distancia < snapRadiusPlane (beta 2026-07-16b) | PARIDAD |
| **Detección de regiones para extruir** | Shell generado por OCCT desde geometría resuelta | GenerateShellAndMesh() sobre SEdge/SBezier | Clipper2 EvenOdd Union → PolyTreeD → OCCT wires | WeldedGraph + half-edge traversal → OCCT Wire | PARIDAD; Dune3D usa Clipper2 que maneja mejor intersecciones complejas |
| **Trim / split curva** | Comando separado (`CommandGeoTrim.cpp`), transfiere constraints | No investigado | No investigado | NO | BRECHA |
| **Offset 2D** | Sí (herramienta dedicada) | No | No | NO | Brecha (baja prioridad para v1) |
| **Fillet 2D** | Sí — ConstraintTangent arc entre los dos segmentos | No | No | NO | Brecha |
| **Splines** | B-spline con ConstraintPointOnBSpline + ConstraintSlopeAtBSplineKnot | Cubic (Bezier cúbico) por segmentos | BEZIER_2D/3D de primera clase + BEZIER_BEZIER_SAME_CURVATURE (G2) | Catmull-Rom centrípeto (throughPoints) + B-spline clamped (controlPoints) | PARIDAD funcional; Dune3D tiene G2 que ninguno tiene |
| **Conics (elipse, hipérbola)** | Sí — DrawSketchHandlerArcOfEllipse.h, ConstraintPointOnEllipse | No | No | NO | Brecha (futura) |
| **Undo/Redo** | Operaciones transaccionales sobre modelo de constraints | Undo stack de parámetros | UUID + historial de documento | Pila de copias de SketchModel (value type, 64 deep) | PARIDAD — nuestra impl más limpia por value semantics |

---

## 6. La pregunta estratégica: ¿snap-first puede llegar a sensación Shapr3D sin solver?

### Lo que el código revela

**SolveSpace** prueba que con Newton-Raphson puro (50 iteraciones, Eigen SparseQR) un sketcher puede funcionar bien. Su snap es rudimentario (sin guías de inferencia), pero sus constraints explícitas dan al usuario feedback claro de qué está fijo y qué no.

**FreeCAD** prueba que el solver puede correr en cada frame de drag sin lag perceptible en sketches de tamaño moderado (planegcs parte en subsistemas desacoplados, solo resuelve el subsistema afectado). El autoconstraint batch post-commit (`SketchAnalysis`) funciona bien como alternativa al snap-first.

**Dune3D** es la prueba más interesante: usa libslvs (SolveSpace) con parches de rendimiento propios, lo que sugiere que libslvs sin parches puede ser demasiado lento para sketches complejos. El autor lo confirma explícitamente: "had to patch the solver."

### La frontera real de snap-first

Lo que snap-first PUEDE hacer bien (y nuestro kernel ya hace):
- Topología conectada desde el inicio (ventaja vs todos)
- Guías de inferencia visuales fluidas en tiempo real
- Sensación de "lo que ves es lo que obtienes" durante el dibujo
- Regiones automáticas sin solver

Lo que snap-first NO puede hacer sin solver:
1. **Dimensiones exactas:** "la línea mide exactamente 47.3 mm" requiere mover el endpoint a la posición correcta dada una longitud. Sin solver, el usuario tendría que calcular la coordenada final manualmente.
2. **Igualdad de longitudes:** "estos dos lados del rectángulo deben ser iguales" — sin solver, editar uno no mueve el otro.
3. **Paralelas a geometría existente:** "esta línea debe quedar paralela a aquella" — el snap puede sugerir la dirección, pero al editar los extremos puede romperse.
4. **Arco tangente a dos líneas:** sin solver es imposible posicionar exactamente el radio del fillet.
5. **Constraintsd dependientes en cadena:** "este rectángulo mide 2× el ancho de aquel" requiere propagación.

### Comparación con Shapr3D

Shapr3D usa D-Cubed de Siemens (solver profesional NURBS). Su ventaja sobre snapfirst es exactamente la lista de arriba. Pero Shapr3D también funciona en modo snap-first: dibuja, snap, y el contorno queda bien sin restricciones explícitas. Las restricciones en Shapr3D son una capa adicional para sketches paramétricos, no el flujo principal para el usuario casual.

**Conclusión del código:** Para flujos de diseño "dibujar → snap → extruir" (el caso de uso central de AppForge v1), snap-first es suficiente y superior en fluidez. La brecha aparece en dos casos concretos de iOS CAD:
1. El usuario quiere exactitud dimensional (L=50mm). Hoy tenemos que abrir un diálogo de edición post-hoc; un solver permitiría escribirlo mientras se dibuja.
2. El usuario quiere modificar un sketch existente de forma paramétrica (cambiar el radio del círculo y que el rectángulo que lo rodea se actualice). Sin solver, cada edit es manual.

---

## 7. Licencias y viabilidad de embedding en iOS

| Solver | Licencia | ¿Embebible en app closed-source? |
|--------|----------|----------------------------------|
| **planegcs** (FreeCAD) | LGPL-2.1-or-later | **Sí, con condiciones**: LGPL permite linking dinámico sin infectar el resto del código. En iOS el linking estático es obligatorio (no hay dylibs de usuario). Hay interpretaciones que permiten LGPL estático si se publican los object files para relinking — práctico pero engorroso. |
| **libslvs** (SolveSpace) | **GPL-3.0-or-later** | **NO** directamente. GPL requiere que toda la app sea GPL. Se podría usar como proceso separado vía IPC, pero en iOS los procesos de usuario no existen. Alternativamente: pagar por una licencia comercial (SolveSpace es small open-source, ¿hay licencia comercial? No consta). |
| **libslvs con parches Dune3D** | GPL-3.0 (hereda del original) | **NO**, misma restricción. Los parches de Lukas Kunz no cambian la licencia. |
| **Solver propio** | Nuestro | Sin restricciones | 

### Veredicto de licencias

**planegcs (LGPL)** es el único solver maduro con licencia compatible en principio, aunque embedding estático en iOS requiere publicar object files o negociar una excepción. La alternativa más limpia para iOS: **implementar un solver propio mínimo** (Newton-Raphson o Dogleg) cubriendo las 8-10 restricciones más usadas (coincidente, H, V, igual longitud, paralela, ángulo fijo, radio fijo, tangente). Dune3D demuestra que SolveSpace-solver-style Newton-Raphson es suficiente para CAD moderno; implementar el núcleo no es una empresa de seis meses.

---

## 8. Qué mecánicas concretas debemos COPIAR (con referencia al código fuente)

### Prioridad ALTA (bloquea UX premium)

**A. Input numérico al dibujar — inspirado en FreeCAD**  
Referencia: `src/Mod/Sketcher/Gui/DrawSketchController.h` → `adaptDrawingToOnViewParameterChange()` y `src/Mod/Sketcher/Gui/SketcherToolDefaultWidget.cpp`  
Mecánica: mientras el usuario dibuja un segmento, un campo numérico overlay muestra longitud y ángulo. El usuario puede escribir "50" → Tab → "45" y el segmento se posiciona exactamente. En nuestra arquitectura: SketchController puede aceptar un `SnapContext` con coordenada forzada derivada del input numérico. No requiere solver si las herramientas son de un solo segmento (el endpoint se calcula directamente desde longitud+ángulo+punto de inicio).

**B. Autoconstraint H/V automático de Dune3D**  
Referencia: `src/core/tools/tool_draw_contour.cpp` → `get_auto_constraint()`  
Mecánica: si la línea recién dibujada está a menos de 10° de horizontal/vertical, aplicar ConstraintH/V automáticamente (en nuestro caso: ajustar el endpoint al valor exacto). Se implementa en `SketchController.tapLine()` comparando el ángulo de `chainLast → p` y snapeando a la guía H/V si el ángulo es < umbral. YA tenemos la guía H/V en SnapEngine; falta el "commit definitivo" al confirmar.

**C. Construcción por referencia (geometría de ayuda)**  
Referencia: `src/Mod/Sketcher/App/SketchGeometryExtension.h` → `GeometryMode::Construction`  
Mecánica: un bit por curva indica que es "helper" (línea de construcción). Participa en snap/guías pero no genera geometría extruible. En nuestro SketchModel: añadir `var isConstruction: Bool = false` a `SketchCurve`. RegionFinder filtra las construction curves. Coste: < 2h.

**D. Selección de cadena conectada (double tap)**  
Referencia: `HitTester.connectedChain()` — ya implementado en nuestro kernel  
Estado: completo.

### Prioridad MEDIA (calidad diferenciadora)

**E. Extensión de línea como snap activo — FreeCAD**  
Referencia: `DrawSketchHandler.cpp` → `seekLineExtensionAutoConstraint()`  
Mecánica: el sistema busca si el cursor está en la prolongación de una línea existente (más allá de sus extremos) y sugiere ese punto con guía visual. YA implementado en nuestro SnapEngine (`guides.lineExtension`). Solo falta asegurarse que la UI dibuje la extensión con línea punteada distinta del color de la alineación.

**F. Trim de curvas**  
Referencia: `src/Mod/Sketcher/App/SketchObject.cpp` → comando `trim()` (en `CommandGeoTrim.cpp`)  
Mecánica: localizar el par de intersecciones más próximas al cursor sobre la curva, dividir en dos curvas más cortas eliminando el segmento central, reasignar las constraints que referenciaban el CurveID original a las nuevas curvas. En nuestra arquitectura: `SketchModel.trimCurve(curveID, at: point) -> (CurveID, CurveID)?` que usa `Intersections.between()` ya existente para hallar los puntos de corte.

**G. Región detectada por Clipper2 para sketches con curvas que no se cierran perfectamente**  
Referencia: `src/document/solid_model/solid_model_util.hpp` → `FaceBuilder`  
Mecánica: Dune3D usa Clipper2's `EvenOdd Union` que es tolerante a gaps pequeños entre curvas. Nuestro `WeldedGraph` requiere que los segmentos se solden dentro de `weldTolerance`. Para sketches dibujados con Pencil donde los extremos pueden quedar a 0.5–1mm: considerar un pase de Clipper2 como backend alternativo cuando WeldedGraph da 0 regiones.

### Prioridad BAJA / Futura

**H. Geometría externa (proyección de aristas 3D)**  
Referencia: `src/Mod/Sketcher/App/SketchObject.cpp` → `rebuildExternalGeometry()`  
En nuestra hoja de ruta de Fase 2 (sketch sobre cara). Cuando dibujemos sobre una cara 3D, proyectar sus aristas al plano de trabajo como `isConstruction = true` + `isExternal = true` (read-only en el solver).

**I. Restricciones paramétricas explícitas (requiere solver)**  
Solo tiene sentido si implementamos un mini-solver. Ver §9.

---

## 9. ¿Necesitamos un solver? — Argumento técnico desde el código

### Casos donde snap-first es suficiente (v1 AppForge)

- Dibujo libre → snap → extruir: el flujo 90% de usuarios
- Rectángulos, polígonos: figuras cerradas por construcción, no por solver
- Arcos y círculos: posicionados por snap, radio exacto por input numérico (A-arriba)
- Simetría visual: el usuario usa las guías H/V/alineación de SnapEngine
- Modificar el sketch: drag de puntos, snap a posiciones notables

### Casos donde snap-first FALLA y necesitamos solver

1. **"Que esta línea mida exactamente igual que aquella"**: sin solver, el usuario mide visualmente. Con solver: `ConstraintEqualLength`.
2. **"Mantener el radio de este fillet al cambiar la geometría circundante"**: sin solver, el fillet se rompe al mover la geometría. Este es el caso más crítico para CAD mecánico.
3. **"Actualizar dimensiones en cascada"**: cambiar el ancho de una pieza que tiene 5 features dependientes. La potencia paramétrica real de D-Cubed/planegcs.

Para v1 de AppForge (iPad CAD personal, flujos básicos), los casos 1-3 son raros. La decisión de snap-first es correcta para v1.

**Para v2, el solver recomendado es un mini Newton-Raphson propio** con 8 tipos de restricción: `Coincident`, `Horizontal`, `Vertical`, `EqualLength`, `FixedLength`, `FixedAngle`, `FixedRadius`, `Parallel`. Estimación: ~1500 líneas de Swift. Inspirado en el solver de SolveSpace (`src/system.cpp`), con la misma descomposición QR (Eigen o Accelerate) pero sin las 40 restricciones avanzadas de planegcs. El Newton-Raphson de SolveSpace (50 iteraciones máx, convergencia en 5-10 normalmente) es suficiente.

**NO usar libslvs directamente**: GPL-3 contaminaría toda la app.  
**NO usar planegcs directamente ahora**: LGPL-static en iOS requiere trabajo legal/operacional. Si en el futuro el solver propio es insuficiente, planegcs es la primera opción (LGPL-2.1).

---

## 10. Hallazgos adicionales notables

### SolveSpace: construcción explícita vs. fusión topológica

La arquitectura de SolveSpace (puntos per-entidad + ConstraintCoincident) muestra por qué la topología compartida de nuestro SketchModel es una ventaja: cuando el usuario mueve un punto en SolveSpace, el solver tiene que satisfacer la ConstraintCoincident para mover el punto vecino. En nuestro kernel, mover el PointID compartido mueve ambas curvas directamente — cero latencia, cero solver, comportamiento exacto. Esto es especialmente valioso en iOS donde queremos 60fps durante el drag.

### FreeCAD: hit-testing en la vista 3D

`ViewProviderSketch.cpp` muestra que FreeCAD usa un sistema de "preselección" separado del sistema de selección. El hover renderiza el elemento candidato en color resaltado antes del click. La prioridad es punto > arista > cara. Nuestro `HitTester.hitTest()` implementa exactamente el mismo orden de prioridad pero además incluye región como cuarto nivel — característica única nuestra.

### Dune3D: el editor de Horizon EDA como base

La "editor infrastructure" de Dune3D es porteada de Horizon EDA (editor de PCBs). Esto explica por qué Dune3D tiene un sistema de herramientas muy modular y extensible, pero también por qué el código de snap/hover está disperso en múltiples archivos de herramienta. AppForge con SketchController centralizado es más mantenible.

### Clipper2 vs WeldedGraph

Dune3D usa Clipper2 (versión moderna del legendario Clipper de Angus Johnson) para detección de regiones. Clipper2 es MIT license, C++, y maneja correctamente: self-intersections, near-misses (gaps < epsilon), polígonos degenerados, y regiones anidadas con EvenOdd. Nuestro WeldedGraph hace lo mismo con código propio pero puede fallar si dos aristas no se intersectan exactamente (el test `Intersections.segmentSegment` tiene epsilon = 1e-9). **Recomendación:** en casos donde RegionFinder devuelve 0 regiones en un sketch que visualmente parece cerrado, añadir una segunda pasada con Clipper2 via una micro-biblioteca Swift wrapper.

---

## Resumen ejecutivo (10 líneas)

Nuestro SketchKernel tiene una arquitectura superior en topología compartida (PointID fusionado vs. ConstraintCoincident explícita de FreeCAD/SolveSpace/Dune3D), guías de inferencia más ricas que cualquiera de los tres referentes, y la única implementación de selección de región 2D directamente en el kernel. La BRECHA principal vs Shapr3D/D-Cubed no es el solver — es el **input numérico durante el dibujo** (longitud, ángulo al escribir) y las **dimensiones paramétricas post-dibujo**. FreeCAD resuelve esto con EditableDatumLabel en viewport + SketcherToolDefaultWidget (código referenciado arriba). Para v1 AppForge, snap-first es la decisión correcta. Para v2, el camino más limpio es un mini-solver Newton-Raphson propio (~1500 líneas Swift) con 8 tipos de restricción básicos, sin usar libslvs (GPL-3) ni planegcs (LGPL-static en iOS requiere trabajo legal). La pieza más valiosa a copiar hoy: el **commit definitivo H/V** de Dune3D (si el segmento dibujado está a <10° de horizontal/vertical, forzar al exacto) y la **geometría de construcción** (bit `isConstruction` en SketchCurve, coste < 2h).
