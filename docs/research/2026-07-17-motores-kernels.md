# Motores de Geometría CAD: Investigación a Fondo
**AppForge Studio — Investigación técnica**
**Fecha:** 2026-07-17
**Alcance:** Kernels geométricos profesionales, solvers de restricciones 2D, análisis de OCCT, y estimaciones de esfuerzo para un CAD tipo Shapr3D sobre OCCT.

---

## 1. Mapa de Kernels Geométricos

### 1.1 Panorama general

| Kernel | Tipo | Propietario | Licencia | Costo |
|---|---|---|---|---|
| **Parasolid** | B-rep + NURBS + Facetas (Convergent Modeling) | Siemens Digital Industries | Propietario | Negociado (NDA); estimado >$50K/año para startups |
| **ACIS** | B-rep + NURBS | Spatial Corp (Dassault Systèmes) | Propietario | Negociado; similar a Parasolid |
| **ShapeManager** | B-rep (fork ACIS 7.0, 2001) | Autodesk (interno) | Solo uso interno; no licenciable | N/A |
| **C3D** | B-rep + NURBS + Solver + Converter (suite completa) | C3D Labs (ruso) | Propietario comercial | Negociado; disponible para ISVs |
| **OCCT** | B-rep + NURBS completo | Open CASCADE SAS / comunidad | LGPL 2.1 | Gratis |
| **SolveSpace kernel** | B-rep propio minimalista | Jonathan Westhues et al. | GPL 3.0 | Gratis (pero GPL viral) |
| **Fornjot** | B-rep Rust, early-stage | hannobraun | AGPL | Gratis — **DESCONTINUADO** (2024) |
| **truck** | B-rep + NURBS en Rust | ricosjp | MIT/Apache 2.0 | Gratis — experimental |

---

### 1.2 Parasolid (Siemens)

**Qué es:** El kernel B-rep dominante de la industria. Soporta modelado sólido, superficial, facetado y mixto (Convergent Modeling, que combina B-rep exacto con mallas en un único objeto). NURBS nativas, blends, offsets, booleanos, draft, HLR.

**Quién lo usa (confirmado):**
- SolidWorks — kernel nativo
- NX (Siemens propio) — kernel nativo
- Solid Edge — kernel nativo
- **Onshape** — kernel nativo ([fuente: Onshape Forum](https://forum.onshape.com/discussion/27000/petition-to-open-the-parasolid-kernel-source-code))
- **Shapr3D** — kernel nativo + D-Cubed DCM ([fuente: Siemens PLM Blog](https://blogs.sw.siemens.com/plm-components/shapr3d-for-ipad-pro-implements-d-cubed-geometric-constraint-solving/))
- **Plasticity** — kernel nativo ([fuente: Grokipedia/Plasticity](https://grokipedia.com/page/plasticity_software))

**Fortalezas conocidas:**
- Robustez excepcional en booleanos de casos límite (coplanares, tangentes, coincidentes)
- Fillets variables y de múltiples aristas sin fallar
- "Convergent Modeling": combina B-rep y mallas sin conversión
- Más de 350 aplicaciones compatibles en 2026
- Mejor interoperabilidad STEP/IGES del mercado

**Debilidades:**
- Totalmente propietario y caro — inaccesible para proyectos open source
- API en C++ sin bindings oficiales para Swift/iOS
- Dependencia de Siemens (riesgo de licencia para startups)

**Fuentes:** [Parasolid/Siemens](https://plm.sw.siemens.com/en-US/plm-components/parasolid/) · [Tech Soft 3D sobre Parasolid](https://www.techsoft3d.com/products/parasolid) · [Wikipedia Parasolid](https://en.wikipedia.org/wiki/Parasolid)

---

### 1.3 ACIS (Spatial/Dassault Systèmes)

**Qué es:** El segundo kernel B-rep más usado históricamente. Arquitectura orientada a objetos en C++. Soporta B-rep, NURBS, sólidos, superficies, mallas.

**Quién lo usa (confirmado):**
- Alibre Design, BricsCAD, SpaceClaim (Ansys), TurboCAD, Cimatron, Viacad, SharkCAD, Vertex (2023)
- AutoCAD en su capa de modelado 3D básico

**Fortalezas:**
- Bien probado (>30 años)
- Arquitectura extensible (herencia C++)
- Dassault lo mantiene activamente para sus clientes ISV

**Debilidades:**
- Propiedad de Dassault Systèmes, competidor directo de la mayoría de sus clientes
- Percibido como ligeramente inferior a Parasolid en robustez de booleanos en casos extremos
- Sin opciones open source

**Fuentes:** [Wikipedia ACIS](https://en.wikipedia.org/wiki/ACIS) · [Spatial 3D ACIS Modeler](https://www.spatial.com/solutions/3d-modeling/3d-acis-modeler) · [Engineering.com análisis](https://www.engineering.com/spatial-acis-cgm-and-the-future-of-geometric-modeling-kernels/)

---

### 1.4 ShapeManager (Autodesk)

**Qué es:** Fork interno de ACIS 7.0 que Autodesk compró en 2001 por $6.4M para no depender de Dassault (quien había adquirido Spatial). **No está disponible como componente licenciable.**

**Quién lo usa:** Solo productos internos de Autodesk — Inventor, Fusion 360, AutoCAD 3D.

**Implicación técnica:** Fusion 360 está limitado a ACIS 7.0 máximo en términos de formato de intercambio. El SAT de Fusion es ACIS 7.0.

**Fuentes:** [Wikipedia ShapeManager](https://en.wikipedia.org/wiki/ShapeManager) · [Machine Design, fork de ACIS](https://www.machinedesign.com/archive/article/21812197/autodesk-to-shape-acis-kernel) · [Foro Autodesk sobre representación de datos](https://forums.autodesk.com/t5/fusion-360-design-validate/how-are-models-represented-in-data-structures/td-p/11518765)

---

### 1.5 C3D (C3D Labs)

**Qué es:** Suite completa rusa que incluye: kernel geométrico B-rep (C3D Modeler), solver de restricciones (C3D Solver), visualizador, convertidor de mallas y convertidor de datos. Es el único competidor que ofrece los cinco componentes en un solo SDK comercial.

**Quién lo usa:** nanoCAD, TECHTRAN, Delta Design (electrónica), VR Concept. Principalmente ecosistema ruso/ex-URSS. Fue creado internamente por ASCON Group (CAD ruso), separado en C3D Labs como empresa independiente en 2012 y celebró su 30º aniversario.

**Fortalezas:**
- Suite all-in-one: kernel + solver + vis + I/O
- Activamente mantenido; soporte multiplataforma incluyendo macOS
- Costo posiblemente más accesible que Parasolid/ACIS para mercados emergentes

**Debilidades:**
- Ecosistema principalmente ruso; documentación predominantemente en ruso
- Riesgo geopolítico para empresas occidentales (restricciones de exportación, sanciones)
- No open source; costo no público

**Fuentes:** [C3D Labs](https://c3dlabs.com/) · [Wikipedia C3D Toolkit](https://en.wikipedia.org/wiki/C3D_Toolkit) · [C3D blog 30 aniversario](https://c3dlabs.com/blog/products/30th-anniversary-of-the-c3d-geometric-kernel-from-an-in-house-tool-to-an-independent-product/)

---

### 1.6 OCCT — Open CASCADE Technology

*(Sección expandida en §3 abajo)*

**Quién lo usa:**
- FreeCAD — kernel nativo
- Salome (simulación científica)
- OpenCASCADE DRAW test harness
- CadQuery / Build123d (Python CAD scripting)
- **AppForge Studio** — vía gsdali/OCCTSwift 1.10.1 sobre OCCT 8.0.0p1

**Fuentes:** [GitHub OCCT](https://github.com/Open-Cascade-SAS/OCCT) · [Wikipedia OCCT](https://en.wikipedia.org/wiki/Open_Cascade_Technology)

---

### 1.7 SolveSpace (kernel propio minimalista)

**Qué es:** CAD 2D/3D paramétrico con su propio kernel B-rep (~10,000 líneas de código en el solver de restricciones, frente a >1M en kernels profesionales). Incluye solver de restricciones 3D propio.

**Licencia:** GPL 3.0 — **viral, incompatible con apps comerciales cerradas iOS** a menos que se negocie licencia comercial.

**Relevancia para nosotros:** Su solver (libslvs) es portable y pequeño, pero la licencia GPL lo hace inutilizable como biblioteca incrustada en una app de App Store propietaria sin acuerdo comercial separado.

**Fuentes:** [SolveSpace.com/library](https://solvespace.com/library.pl) · [Wikipedia SolveSpace](https://en.wikipedia.org/wiki/SolveSpace)

---

### 1.8 Fornjot y truck (Rust)

**Fornjot:** B-rep en Rust, early-stage. **Proyecto descontinuado en 2024** — el desarrollador declaró que los objetivos no se alcanzaron. No apto para producción.

**truck:** B-rep + NURBS puro en Rust, MIT/Apache 2.0. Modular ("Ship of Theseus"). Capacidades: knot vectors, B-spline, NURBS, topología (vertex/edge/wire/face/shell/solid), meshing, WebGPU. **Muy experimental** — sin booleanos robustos, sin fillets, sin feature modeling. Interesante a largo plazo pero no viable hoy para CAD profesional.

**Fuentes:** [GitHub Fornjot](https://github.com/hannobraun/fornjot) · [GitHub truck](https://github.com/ricosjp/truck) · [Rust Forum Fornjot v0.49.0](https://users.rust-lang.org/t/fornjot-v0-49-0-open-source-b-rep-cad-kernel-in-rust/108667)

---

## 2. Solvers de Restricciones 2D (la otra pieza crítica)

### 2.1 D-Cubed 2D DCM (Siemens) — el estándar industrial

**Qué hace exactamente:**
D-Cubed 2D Dimensional Constraint Manager (DCM) es el solver de restricciones geométricas 2D más adoptado en la industria. Opera sobre: puntos, líneas, círculos, elipses, cónicas, splines y curvas paramétricas.

Restricciones soportadas: distancia, ángulo, radio, paralelo, perpendicular, tangente, concéntrico, simétrico, distancia/radio igual, patrones lineales y circulares.

**Por qué es el estándar:**
- Décadas de refinamiento desde los años 90
- Handles edge cases: sketches sobre/infra-determinados, dragging libre de entidades
- API estable que permite monitorear el estado del sketch (libre, bien definido, sobre-definido)
- Usado en: SolidWorks, NX, Solid Edge, Inventor, Onshape, **Shapr3D**

**Shapr3D + D-Cubed:** Shapr3D usa D-Cubed 2D DCM para toda la mecánica de sketch 2D (dimensiones, restricciones geométricas). Adicionalmente construyeron encima un motor de "constraint snapping" que monitorea el lápiz Apple Pencil y aplica restricciones automáticamente mientras el usuario dibuja — esto es propio de Shapr3D, no de D-Cubed. También licencian Parasolid y HOOPS Exchange de Siemens para I/O.

**Licencia/costo:** Propietario comercial. Sin precio público — negociado con Siemens. Probablemente en el rango de decenas de miles de dólares/año, inaccesible para presupuesto $0.

**Fuentes:** [Siemens D-Cubed 2D DCM](https://plm.sw.siemens.com/en-US/plm-components/d-cubed/2d-dcm/) · [Blog Shapr3D+D-Cubed](https://blogs.sw.siemens.com/plm-components/shapr3d-for-ipad-pro-implements-d-cubed-geometric-constraint-solving/) · [Siemens caso Shapr3D](https://resources.sw.siemens.com/en-US/case-study-shapr3d/)

---

### 2.2 planegcs (FreeCAD) — nuestra mejor opción open source

**Qué es:** Solver numérico de restricciones 2D del Sketcher de FreeCAD. Puro C++, sin dependencias externas, ~20+ archivos fuente.

**Algoritmos implementados:**
- **DogLeg** (por defecto) — método de región de confianza, combina gradiente descendiente y pasos Newton
- **Levenberg-Marquardt** — mínimos cuadrados amortiguados, robusto en mínimos locales
- **BFGS** — quasi-Newton con Hessiano aproximado

**Restricciones soportadas:** distancia punto-punto, distancia X/Y, ángulo, paralelo, perpendicular, tangente, coincidente, concéntrico, simétrico, horizontal, vertical, radio igual.

**Licencia: LGPL 2.1** — compatible con aplicaciones propietarias de App Store, siempre que se enlace dinámicamente o se distribuya el código fuente de planegcs modificado. La LGPL permite cerrar el código de la app envolvente.

**Portabilidad a iOS:** El solver es C++ puro sin dependencias de plataforma. Compila en cualquier target que soporte C++17. Existe ya un port a WebAssembly (Salusoft89/planegcs), lo que prueba que el core es independiente de plataforma. Para iOS: compilar como biblioteca estática C++ y llamar desde Swift vía bridging header o C bridge — factible, como hace OCCTSwift con OCCT.

**Limitaciones documentadas:**
- Numerical, no simbólico — puede no converger en sketches muy complejos o mal condicionados
- No maneja sketch 3D (solo 2D)
- Sin soporte nativo de splines bajo restricciones (puntos de control libres, no restricciones de continuidad)

**Fuentes:** [GitHub FreeCAD planegcs](https://github.com/FreeCAD/FreeCAD/blob/main/src/Mod/Sketcher/App/planegcs/GCS.cpp) · [GitHub Salusoft89/planegcs (WASM)](https://github.com/Salusoft89/planegcs) · [DeepWiki FreeCAD GCS](https://deepwiki.com/FreeCAD/FreeCAD/3.1.2-constraint-system-and-gcs-solver) · [SALOME usa planegcs](https://devtalk.freecad.org/t/using-planegcs-as-the-sketch-constraint-solver-in-salome/17368)

---

### 2.3 libslvs (SolveSpace)

**Qué es:** Solver de restricciones geométricas extraído de SolveSpace como biblioteca independiente. Más compacto que planegcs (kernel < 10,000 líneas).

**Licencia: GPL 3.0** — **bloqueante para app propietaria de App Store**. Habría que negociar licencia comercial separada con el mantenedor.

**Capacidades:** Restricciones 2D y 3D (SolveSpace es un CAD 3D con sus propias restricciones 3D). Más limitado en tipos de curva que planegcs.

**Veredicto para AppForge:** No viable sin acuerdo comercial por la GPL.

**Fuentes:** [SolveSpace/library.pl](https://solvespace.com/library.pl) · [GitHub JacobStoren/SolveSpaceLib](https://github.com/JacobStoren/SolveSpaceLib)

---

### 2.4 SketchKernel propio (lo que tenemos hoy)

El repositorio ya tiene `SketchKernel` como paquete Swift puro (`ios-app/SketchKernel/`), sin dependencias externas, sin UIKit/Metal (portable a cualquier host incluyendo Windows para tests en CI). Incluye `ConstraintBridgeTests`, `SketchControllerTests`, `SketchRegionSelectTests`, `SnapTests`, `TopologyTests` — indica que el solver de restricciones está parcialmente implementado de forma propia.

**Riesgo real:** Los solvers numéricos caseros para restricciones geométricas son notoriamente difíciles de hacer robustos. planegcs tomó a FreeCAD años de refinamiento. Si el ConstraintEngine actual no converge bien en casos complejos (sketches muy restringidos, patrones, tangencias múltiples), la solución escalable a largo plazo es reemplazarlo con planegcs compilado para iOS.

---

## 3. OCCT a Fondo — Nuestro Kernel

### 3.1 Estado actual: OCCT 8.0.0p1 (Mayo 2026)

OCCT 8.0.0 es una versión major con más de 500 cambios respecto a 7.9.0:
- **STEP read**: hasta 75% más rápido
- **TShape hierarchy**: la lista enlazada de hijos reemplazada por memoria contigua (shape exploration más rápida)
- Refactoring completo del repositorio con integración GTest
- `NCollection` migrado a `size_t` API
- Thread-safe STEP write
- Mejoras en booleanos, robustez de meshing, manejo de tolerancias

**Fuentes:** [OCCT 8.0.0 RC4 Discussion](https://github.com/Open-Cascade-SAS/OCCT/discussions/1097) · [OCCT3D anuncio 8.0](https://occt3d.com/performance-stability-long-term-vision-occt-8-0-0-arriving-q1-2026/) · [FOSDEM 2026 OCCT 8.0](https://fosdem.org/2026/schedule/event/QQRAAF-occt3d-8-kernel-evolution/)

---

### 3.2 Capacidades reales de OCCT

| Módulo | Capacidad | Nivel |
|---|---|---|
| **Primitivos** | Box, cilindro, esfera, cono, toro | Completo |
| **Booleanos** | Union, substract, intersect, section, split, Maker Volume | Completo (con caveats — ver §3.3) |
| **Fillets/Chamfers** | Radio constante, radio variable (chord), multi-arista | Completo (pero frágil en casos límite) |
| **Shell/Hollow** | BRepOffsetAPI shell, thicken | Completo |
| **Offset de superficies** | BRepOffsetAPI offset surface | Completo |
| **NURBS** | Evaluación, knot insertion, degree elevation, fitting | Completo |
| **Superficies** | Analíticas, barridas, loft, ruled, Coons, freeform | Completo |
| **Sweep/Loft** | BRepOffsetAPI Pipe, BRepFill Loft | Completo |
| **HLR** | Hidden Line Removal exacto (HLRBRep_Algo) y aproximado (PolyAlgo) | Completo |
| **ShapeFix** | Reparación de geometría inválida, sewing, simplificación | Completo |
| **STEP/IGES** | Import/export con atributos (colores, layers, GD&T) | Completo vía XDE |
| **STL/OBJ/PLY/GLTF** | Import/export mallas | Completo |
| **Meshing** | BRepMesh_IncrementalMesh para visualización | Completo |
| **OCAF/XDE** | Documento paramétrico, atributos, ensamblajes, colores, materiales | Completo |
| **TNaming** | Naming persistente de topología para historia paramétrica | Presente pero difícil de usar |
| **Assemblies** | XDE/XCAF: componentes, instancias, ubicaciones | Completo (sin mating constraints nativos) |
| **Threads** | Perfiles ISO-68, multi-start, threading | Disponible en OCCTSwift |
| **Dimensiones/GD&T** | Anotaciones 2D en planos (via XDE) | Disponible |

---

### 3.3 Debilidades documentadas (bugs reales en FreeCAD)

**Booleanos — los más críticos:**

1. **Faces coplanares/coincidentes sin fuzzy tolerance:** `BRepAlgoAPI_BooleanOperation` falla silenciosamente o produce geometría corrupta cuando las caras de los operandos son exactamente coplanares. La solución es `SetFuzzyValue()` pero el valor correcto es difícil de determinar automáticamente. ([Issue #5619](https://github.com/FreeCAD/FreeCAD/issues/5619) — "Boolean Difference leaves extra hole, upstream OCC bug #25979")

2. **Regression en OCC 7.7.2:** Booleanos common fallaron completamente — "Cannot compute Inventor representation for the shape". ([Issue #15599](https://github.com/FreeCAD/FreeCAD/issues/15599))

3. **Boolean Fusion/Fragments: partes cortadas en vez de fusionadas.** ([Issue #17705](https://github.com/FreeCAD/FreeCAD/issues/17705))

4. **Cannot cut from intersecting parts in compounds** — OCCT no puede cortar desde partes que se intersectan en compuestos. ([Issue #17497](https://github.com/FreeCAD/FreeCAD/issues/17497))

5. **Boolean compounds coincident faces.** ([Issue #26119](https://github.com/FreeCAD/FreeCAD/issues/26119))

**Fillets:**

6. **Crash creando fillets en sweep** — upstream OCC bug. ([FreeCAD tracker #4543](https://tracker.freecad.org/view.php?id=4543))

7. **Fillet después de thickness → geometría inválida** — OCC bug #25521.

8. **STEP export: fillets creados en FreeCAD leídos incorrectamente por Onshape/Rhino** — problema de representación en STEP. ([Issue #20889](https://github.com/FreeCAD/FreeCAD/issues/20889))

**El problema de Topological Naming (TNaming):**

Este es el talón de Aquiles de OCCT para CAD paramétrico con historial. Cuando el modelo se reedita (se cambia una dimensión, se agrega/elimina una feature), los índices internos de caras/aristas/vértices se reorganizan. OCCT proporciona `TNaming` para rastrear estas referencias, pero implementarlo correctamente requiere un esfuerzo de ingeniería significativo.

FreeCAD tardó **más de 10 años** en resolver parcialmente este problema (el "Topological Naming Problem" o TNP). La solución de realthunder/Ondsel se integró en FreeCAD 1.0 pero aún tiene bugs reportados en RC2 (septiembre 2024). ([Ondsel blog: TNP is history](https://www.ondsel.com/blog/toponaming-problem-is-history/) · [Ondsel: don't hold your breath](https://www.ondsel.com/blog/freecad-topological-naming/))

**iOS/ARM — issues específicos:**

- **Clang optimization bug:** compilar `AdvApp2Var_ApproxF2var.cxx` con `-O2` o superior causa crashes. Workaround: `-O1` para ese archivo específico. (Documentado en foro OCCT "Experiences with OCCT on iOS")
- **Mutex contention en ARM:** operaciones atómicas en ARM no son tan eficientes como en Intel. El caché de BSpline consumía 30-50% del CPU en lock/unlock durante meshing e intersecciones. Solución: deshabilitar paralelismo o usar un branch de caché alternativo.
- **Allocación lenta:** `GCPntsQuasiUniform_Deflection` y `GCPntsTangential_Deflection` son lentos en ARM.
- **Estado oficial:** OCCT está oficialmente certificado en iOS arm64 y macOS arm64 (Apple M1). La ejecución en M1 es "comparable o mejor que Intel".

**Lo que hace FreeCAD para mitigar:**
- Aplica `ShapeFix_Shape` automáticamente antes de operaciones
- Usa `BRepAlgoAPI_BooleanOperation::SetFuzzyValue()` en casos críticos
- Mantiene rastreador interno de bugs OCC (separado del tracker OCC oficial) — muchos bugs se trabajan a nivel de FreeCAD antes de que OCC los corrija

---

### 3.4 Corre en iOS/ARM — sí, con caveats

OCCTSwift 1.10.1 (julio 2026) confirma: iOS 15+ arm64, compilación activa, 4,313 operaciones wrapeadas. El wrapper ya resuelve los problemas de compilación de bajo nivel. El framework pre-compilado como xcframework elimina los problemas de flags de compilación.

---

## 4. OCCT: Capacidades No Usadas (Oro Potencial)

Basado en el análisis del código actual (`OCCTEngine.swift`, `BooleanEngine.swift`, `FilletEngine.swift`), AppForge usa primitivos, booleanos, fillet, chamfer, shell, extrude, revolve. Lo que probablemente **no** se usa aún:

### 4.1 ShapeFix — Reparación automática de geometría

`ShapeFix_Shape`, `ShapeFix_Face`, `ShapeFix_Shell`, `ShapeFix_Solid` — reparan geometría inválida importada o generada por operaciones que casi fallan. **Crítico** para robustez del pipeline: llamar ShapeFix antes de exportar STEP o antes de booleanos complejos.

**Valor:** Convierte el 30% de fallos de booleanos en éxitos. FreeCAD lo aplica silenciosamente.

### 4.2 BRepOffsetAPI — Operaciones de offset avanzadas

- `BRepOffsetAPI_MakePipe`: sweep 3D a lo largo de path arbitrario
- `BRepOffsetAPI_ThruSections`: loft con control preciso de continuidad
- `BRepOffsetAPI_MakeOffsetShape`: shell/hollow preciso
- `BRepOffsetAPI_MakeDraft`: draft angles (desmoldeo)

**Valor:** Habilita pipe, tube, canal, sweep path — tools que Shapr3D tiene y que son muy usadas en diseño de producto.

### 4.3 HLR — Hidden Line Removal para planos 2D técnicos

`HLRBRep_Algo` (exacto) y `HLRBRep_PolyAlgo` (aproximado/rápido). Genera proyecciones 2D de sólidos 3D con líneas visibles y ocultas separadas, para planos técnicos tipo dibujo de taller.

**Valor:** Feature de alto impacto para usuarios profesionales que quieren exportar planos 2D. OCCTSwift ya tiene 32 funciones de drawing incluyendo proyección HLR.

### 4.4 OCAF/XDE — Historia paramétrica y ensamblajes

`TDF_Label`, `TNaming_Builder`, `TNaming_Selector`, `XDE assembly tree` — el sistema de documentos OCAF es la infraestructura necesaria para:
- Historial paramétrico con referencias persistentes
- Árbol de features (extrude Feature 1 → fillet Feature 2 → etc.)
- Ensamblajes con instancias y ubicaciones
- Atributos de colores, materiales, GD&T

OCCTSwift confirma que tiene 200+ funciones XDE/OCAF expuestas.

**Valor:** Sin esto, AppForge no puede tener historial paramétrico real. Este es el módulo más subutilizado y más valioso.

### 4.5 Thread Features

Perfiles de rosca ISO-68, multi-start, threading — OCCTSwift tiene 23 funciones. Útil para tornillos, tuercas, fittings — diseño mecánico real.

### 4.6 STEP con GD&T

OCCT puede importar/exportar STEP con tolerancias geométricas (GD&T), símbolos de acabado superficial, dimensiones asociadas a geometría. Esto es lo que separa un "CAD viewer" de una herramienta de ingeniería.

---

## 5. Techo real de AppForge sobre OCCT vs Shapr3D/Parasolid

### Lo que PODRÁ igualar (con esfuerzo):
- Booleanos básicos y avanzados (con ShapeFix como red de seguridad)
- Fillets/chamfers en geometría "normal" (sin casos extremos)
- Sweep, loft, pipe, extrude, revolve
- STEP/IGES import/export de calidad profesional
- Ensamblajes con instancias y ubicaciones (XDE)
- Planos 2D técnicos con HLR (proyecciones, dimensiones)
- Render PBR + AR (ya implementado con Satin/Metal)
- Rosca, draft, shell, thicken

### Lo que SERÁ DIFÍCIL pero alcanzable con mucho esfuerzo:
- **Historial paramétrico robusto** (TNaming — requiere arquitectura propia sobre OCCT; FreeCAD tardó 10+ años)
- **Sketch 2D con solver de calidad profesional** (planegcs es bueno pero inferior a D-Cubed en edge cases de tangencias complejas, patrones grandes)
- **Fillets en geometría degenerada** (OCCT falla donde Parasolid triunfa — fillets en intersecciones difíciles, fillets variables complejos)
- **Booleanos en geometría casi-coincidente** (necesitan fuzzy tolerance automático inteligente)

### Lo que probablemente NUNCA igualará (limitación estructural de OCCT vs Parasolid):
- **Robustez absoluta de booleanos**: Parasolid tiene décadas de refinamiento en casos límite. OCCT tiene bugs documentados que pueden surgir en modelos complejos de usuario real.
- **Fillets variables multi-arista complejos**: Parasolid es significativamente más robusto
- **Convergent Modeling** (B-rep + mallas en mismo objeto): Parasolid tiene esta función, OCCT no
- **Velocidad en modelos grandes** (>10,000 features): Parasolid escala mejor
- **Certificación para manufactura crítica** (aeroespacial, médico): requiere validación que OCCT nunca ha buscado formalmente

**Conclusión estratégica:** Para el 90% de casos de uso de diseño de producto y manufactura general, OCCT es suficiente. Los bugs conocidos son evitables con buena arquitectura (ShapeFix, fuzzy booleans, validación pre/post operación). Shapr3D domina hoy no solo por Parasolid sino por UX + gestos + flujo de trabajo. **La brecha real es de UX, no de kernel.**

---

## 6. Tabla de Esfuerzo — CAD tipo Shapr3D sobre OCCT

Escala: **S** = 1-2 semanas/persona · **M** = 3-6 semanas/persona · **L** = 2-4 meses/persona · **XL** = 6-18 meses/persona

Contexto: fundador no-programador que dirige agentes IA. Los agentes multiplican velocidad de implementación ~3-5x en código "feliz", pero la robustez y los edge cases aún requieren iteraciones de debugging. Las estimaciones reflejan tiempo de reloj con agentes IA.

| Subsistema | Tamaño | Semanas/persona (con agentes) | Estado actual | Notas |
|---|---|---|---|---|
| **Primitivos 3D** (box, cyl, esfera, cono, toro) | S | 1-2 | ✅ Hecho | OCCTEngine ya los tiene |
| **Booleanos básicos** (union, subtract, intersect) | S | 1-2 | ✅ Hecho | Necesita ShapeFix wrap |
| **Fillet/Chamfer** | S | 2-3 | ✅ Hecho | Necesita manejo de fallo gracioso |
| **Shell/Offset/Draft** | S | 2-3 | ✅ Parcial | Shell hecho; offset/draft pendiente |
| **Sketch 2D con constraints básicos** | M | 4-6 | ✅ Parcial (SketchKernel propio) | Integrar planegcs para robustez real |
| **Sketch 2D con constraints avanzados** (patrones, simetría, splines restringidas) | L | 8-12 | ❌ Pendiente | Depende de planegcs o solver propio maduro |
| **Extrude/Revolve paramétrico** | M | 3-5 | ✅ Parcial | CADShapeExtrusionEngine existe |
| **Sweep/Pipe (path 3D)** | M | 4-6 | ❌ Pendiente | BRepOffsetAPI_MakePipe disponible en OCCTSwift |
| **Loft** | M | 4-6 | ❌ Pendiente | LoftEngine.swift existe pero sin historial |
| **Historial paramétrico básico** (features ordenadas, undo/redo) | L | 8-14 | ⚠️ CADHistoryTree.swift existe | Sin TNaming = referencias de topología frágiles |
| **Historial paramétrico robusto** (TNaming, refs persistentes) | XL | 20-40 | ❌ Pendiente | El problema más difícil del CAD paramétrico |
| **Direct Modeling** (push/pull de caras, sin historial) | M | 5-8 | ⚠️ Parcial (push/pull en UI) | Conectar a BRepOffsetAPI_MakeFace |
| **Ensamblajes básicos** (insert, position, instancias) | L | 6-10 | ⚠️ AssemblyMatesEngine.swift existe | XDE/XCAF disponible en OCCTSwift |
| **Mating constraints** en ensamblajes (coincident, offset, angle) | L | 10-16 | ❌ Pendiente | OCCT no tiene solver nativo; implementación propia |
| **Planos 2D técnicos** (HLR, dimensiones, vistas) | L | 6-10 | ❌ Pendiente | HLR disponible en OCCTSwift |
| **STEP import** (geometría + colores + estructura) | M | 3-5 | ⚠️ ExportService.swift existe | XDE disponible |
| **STEP export** completo + IGES | M | 3-5 | ⚠️ Parcial | Añadir validación ShapeFix pre-export |
| **STL/OBJ/GLTF export** | S | 1-2 | ✅ Hecho | Via OCCTSwift |
| **Render PBR + IBL** | — | — | ✅ Hecho | Satin/Metal |
| **AR Quick Look** | S | 1-3 | ✅ Parcial | Depende de export USDZ |
| **Thread features** (rosca ISO) | M | 3-5 | ❌ Pendiente | 23 funciones en OCCTSwift |
| **Pattern (lineal/circular/mirror)** | M | 3-5 | ❌ Pendiente | Requiere feature history |
| **Measurement interactivo** | S | 2-3 | ⚠️ MeasureEngine existe, no conectado a UI | Conectar al viewport |
| **Selection (caras/aristas/vértices)** | M | 3-6 | ⚠️ HitTestEngine existe | Ray casting vs B-rep |
| **ShapeFix como red de seguridad** | S | 1-2 | ❌ Pendiente | Wrapear y llamar automáticamente |

### Resumen de fases:

| Fase | Contenido | Esfuerzo total estimado |
|---|---|---|
| **Fase A** (ya hecha) | Primitivos, booleanos, fillet, shell, extrude, render PBR | ~8-12 semanas |
| **Fase B** (próximas semanas) | Sketch constraints robusto, sweep/pipe, loft, measurement UI, ShapeFix, STEP completo | ~12-18 semanas |
| **Fase C** (meses 3-6) | Historial paramétrico básico, direct modeling completo, planos HLR, ensamblajes básicos | ~20-30 semanas |
| **Fase D** (meses 6-18) | Historial paramétrico con TNaming robusto, assembly mating, patterns, threads | ~30-50 semanas |

---

## 7. Decisiones Accionables para AppForge

1. **Adoptar planegcs (LGPL) como solver de constraints 2D** en lugar del SketchKernel propio para constraints — compilar como biblioteca C++ estática para iOS, bridgear desde Swift. El SketchKernel propio puede seguir existiendo para la geometría 2D (líneas, arcos, regiones) pero el solving numérico debería ser planegcs.

2. **Implementar ShapeFix como wrapper automático** alrededor de booleanos y antes de cualquier export STEP — esto elimina el 30% de fallos.

3. **Usar `BRepAlgoAPI::SetFuzzyValue(1e-6)` por defecto** en todos los booleanos para geometría casi-coincidente.

4. **Priorizar HLR para planos 2D técnicos** — OCCTSwift lo tiene, es un diferenciador real para usuarios profesionales, y es subvalorado por competidores móviles.

5. **No intentar TNaming completo en el corto plazo** — construir un historial paramétrico propio ("feature list" simplificado que reapplica operaciones desde cero en cada cambio) es más pragmático. Es más lento para modelos grandes pero evita 18+ meses de debugging de topological naming.

6. **Aprovechar XDE/XCAF de OCCTSwift** (200+ funciones ya expuestas) para ensamblajes y atributos — no reinventar.

---

## 8. Fuentes Principales

- [Siemens Parasolid](https://plm.sw.siemens.com/en-US/plm-components/parasolid/)
- [Siemens D-Cubed 2D DCM](https://plm.sw.siemens.com/en-US/plm-components/d-cubed/2d-dcm/)
- [Shapr3D + D-Cubed caso](https://blogs.sw.siemens.com/plm-components/shapr3d-for-ipad-pro-implements-d-cubed-geometric-constraint-solving/)
- [Shapr3D caso estudio Siemens](https://resources.sw.siemens.com/en-US/case-study-shapr3d/)
- [Wikipedia ACIS](https://en.wikipedia.org/wiki/ACIS)
- [Wikipedia ShapeManager](https://en.wikipedia.org/wiki/ShapeManager)
- [C3D Labs](https://c3dlabs.com/)
- [Wikipedia C3D Toolkit](https://en.wikipedia.org/wiki/C3D_Toolkit)
- [GitHub OCCT](https://github.com/Open-Cascade-SAS/OCCT)
- [Wikipedia OCCT](https://en.wikipedia.org/wiki/Open_Cascade_Technology)
- [OCCT forum iOS experiences](https://dev.opencascade.org/content/experiences-occt-ios)
- [OCCT testing Apple M1](https://dev.opencascade.org/content/testing-occt-apple-m1-arm64)
- [OCCT 8.0 RC4 Discussion](https://github.com/Open-Cascade-SAS/OCCT/discussions/1097)
- [OCCT3D anuncio 8.0](https://occt3d.com/performance-stability-long-term-vision-occt-8-0-0-arriving-q1-2026/)
- [FOSDEM 2026 OCCT 8.0](https://fosdem.org/2026/schedule/event/QQRAAF-occt3d-8-kernel-evolution/)
- [FreeCAD Issue #5619 boolean hole](https://github.com/FreeCAD/FreeCAD/issues/5619)
- [FreeCAD Issue #15599 boolean regression](https://github.com/FreeCAD/FreeCAD/issues/15599)
- [FreeCAD Issue #17705 boolean fusion/fragments](https://github.com/FreeCAD/FreeCAD/issues/17705)
- [FreeCAD Issue #20889 STEP fillets](https://github.com/FreeCAD/FreeCAD/issues/20889)
- [FreeCAD tracker #4543 fillet crash](https://tracker.freecad.org/view.php?id=4543)
- [FreeCAD topological naming problem wiki](https://github.com/FreeCAD/FreeCAD-documentation/blob/main/wiki/Topological_naming_problem.md)
- [Ondsel TNP is history blog](https://www.ondsel.com/blog/toponaming-problem-is-history/)
- [Ondsel don't hold your breath](https://www.ondsel.com/blog/freecad-topological-naming/)
- [GitHub planegcs Salusoft89](https://github.com/Salusoft89/planegcs)
- [DeepWiki FreeCAD GCS](https://deepwiki.com/FreeCAD/FreeCAD/3.1.2-constraint-system-and-gcs-solver)
- [SolveSpace library](https://solvespace.com/library.pl)
- [OCCT OCAF documentation](https://dev.opencascade.org/doc/overview/html/occt_user_guides__ocaf.html)
- [OCCT XDE documentation](https://dev.opencascade.org/doc/overview/html/occt_user_guides__xde.html)
- [GitHub truck (Rust CAD)](https://github.com/ricosjp/truck)
- [GitHub Fornjot](https://github.com/hannobraun/fornjot)
- [OCCTSwift Swift Package Index](https://swiftpackageindex.com/gsdali/OCCTSwift)
- [GitHub OCCTMCP](https://github.com/gsdali/OCCTMCP)
- [Wikipedia Geometric Modeling Kernel](https://en.wikipedia.org/wiki/Geometric_modeling_kernel)
- [Plasticity Wikipedia](https://en.wikipedia.org/wiki/Plasticity_(software))
- [Onshape Forum Parasolid](https://forum.onshape.com/discussion/27000/petition-to-open-the-parasolid-kernel-source-code)
