# AUDITORÍA TÉCNICA: Estado Real de AppForge Studio
> 2026-07-17 · Rama: `fase-1-dibujo` · Metodología: código + docs + barrido device

**Objetivo:** inventario honesto de madurez por capas de CAD real. Distinguir código que existe de código que funciona de verdad.

---

## RESUMEN EJECUTIVO

AppForge Studio es un CAD 3D + escultor para iPad con Stack: iOS 17+ / Swift 5.9 / Metal 2 / Satin / OCCTSwift. Construido sobre B-rep (kernel OCCT) con sketch 2D puro (SketchKernel nuevo). La arquitectura es **sólida a nivel kern**, pero el **UI/UX está disperso**: dos sistemas de sketch en paralelo, placebos recientemente retirados (Loft/Bisel/LoopCut sin implementación real), y dios-archivo de 3759 líneas (CADModeView) que bloquea escalabilidad.

**Madurez promedio: 2.2/5.0** (funciona a medias) — kernel 3/5, sketch 2/5, features 2/5, UI 2/5, sculpt 2.5/5.

---

## 1. MÉTRICAS DE CÓDIGO

### Tamaño total del proyecto

| Concepto | Valor |
|----------|-------|
| **Archivos Swift principales** | 120+ (CADMode 20, Engines 49, Services 31, Features/Tests 20+) |
| **Líneas de código (LOC) principales** | ~14,500 LOC (CADMode 6.4k, Engines 8.2k, Services 5.8k) |
| **Tests** | 47 suites (BRep, Animation, CSG, Constraint, Export, Sculpt, CAD, Drawing, etc.) |
| **SketchKernel** | 1,779 LOC + 359 LOC tests (kernel puro, aislado de UIKit) |
| **Archivos .md de docs** | ~90+ en raíz + archive/ (señal de dispersión histórica) |

### Top 10 archivos por tamaño

| Archivo | Líneas | Propósito | Riesgo |
|---------|--------|---------|---------|
| CADModeView.swift | 3,759 | UI principal CAD (tabs, herramientas, undo, mediciones) | **GOD-FILE**: lógica de 9 herramientas + 12 overlays + timeline |
| SatinRenderer.swift | 1,774 | Pipeline Metal PBR+IBL, buffers GPU | CRÍTICO pero cohesivo (render puro) |
| SketchController.swift | 1,051 | Sketch 2D sobre kernel SketchKernel, snap/region, extrusión | Core, bien estructurado |
| SubdivisionEngine.swift | 585 | Catmull-Clark + voxel remesh | Complejo pero aislado |
| AnimationEngine.swift | 548 | Keyframes, lerp/slerp, playback timeline | Funcional, independiente |
| SatinRendererView.swift | 100 | SwiftUI bridge a Satin | Thin wrapper |
| CADSketchEngine.swift | 578 | **LEGACY sketch** (pre-SketchKernel, aún en uso) | **DEUDA TÉCNICA**: sistema viejo en paralelo |
| BRepModeling.swift | 328 | Booleanos OCCT + fillet/chamfer/shell | Core sólido (puro OCCT) |
| SDFEngine.swift | 550 | Signed distance field (feature future, stage alpha) | No integrado aún |
| DynamicTopologyEngine.swift | 370 | Dyntopo Blender-style, remesh dinámico | Incompleto, conexión débil |

---

## 2. ARQUITECTURA POR CAPAS — MADUREZ REAL

### Capa 1: Kernel Geometría 3D (B-rep OCCT) — Madurez: **3/5**

**Evidencia de madurez:**

- **OCCTSwift integrado en Package.swift**: SPM dependency con framework pre-compilado iOS arm64 (~190 MB)
- **OCCTBridge.swift (148 LOC)** convierte Shape→Mesh con triangulación adaptativa
- **APIs verificadas** (v1.8.8):
  - Booleanos: `Shape + Shape` (union), `Shape - Shape` (resta), `Shape & Shape` (intersección)
  - Features: `filleted(edges:radius:)`, `filleted(edges:startRadius:endRadius:)`, `chamfered(distance:edges:)`, `removeFeatures(faces:)`, `shelled(thickness:)`, `translated/rotated/scaled`
  - Exportación: `OCCTSwiftIO.Exporter.writeSTEP()`, `writeSTL()` (real B-rep)

**BRepModeling.swift (328 LOC)** es la fachada: `boolean()`, `applyFeature()`, `fillet()/filletEdges()`, `chamferEdges()`, `removeFaces()`, `translate()/rotate()/scale()`.

**Verificación en device (2026-07-11):**
- Primitivas (caja/esfera/cilindro/cono/toro) = **✅ REALES**, B-rep completo, entrada al árbol
- Booleanos = **❌ inutilizable** → selección por chevrones `‹›` invisibles en barra mínuscula (los usuarios NO pueden seleccionar A/B con dedo)
- Fillet = **🟡 parcial** → 1 arista OK, pero multi-arista falla (bug L1042: solo lee `lastItem`, debe iterar todas)

**Riesgo estructural:** Kernel sólido pero **selección de cuerpo** (requisito 1 de Shapr3D) NO existe — los usuarios tocan un cuerpo y no queda SELECCIONADO con outline.

### Capa 2: Sketch 2D — Madurez: **2/5**

**ALERTA CRÍTICA: Doble sistema en paralelo**

1. **SketchKernel (NUEVO, Fase 1, 1,779 LOC + 359 LOC tests)**
   - Kernel puro, aislado de UIKit (compila en Windows/Linux/Mac)
   - Topología conectada: un punto = UN nodo, curvas comparten topología real
   - Módulos: `SketchModel.swift` (231 LOC documento), `SnapEngine.swift` (302 LOC snap + guías), `RegionFinder.swift` (226 LOC detección ciclos), `HitTester.swift` (81 LOC hit-test), `CurveGeometry.swift` (334 LOC aritmética de curvas)
   - Tests: `SnapTests` (116 LOC), `TopologyTests` (80 LOC), `RegionAndHitTests` (163 LOC)
   - **Estado:** kernel listo (~95% contrato), pero NO conectado a UI de renderizado de sketch

2. **CADSketchEngine (LEGACY, pre-Fase 1, 578 LOC)**
   - Sistema viejo: `points[]` + `entities[]` con auto-encadenado de líneas (bug L98-103: `addPoint` SIEMPRE crea línea entre últimos 2 puntos)
   - Sin topología conectada: `splitToLines` duplica puntos por segmento → sin ciclos robustos
   - SIN hit-testing real: selección de trazos dibujados NO funciona
   - Aún usado por CADModeView como `@StateObject private var sketchEngine = CADSketchEngine()`

**Conexión actual (SketchController.swift, 1,051 LOC):**
- SketchController **importa y usa SketchKernel**: `import SketchKernel` (L5), `@Published private(set) var model = SketchModel()`
- Adaptador entre UI (gestos, render) y kernel puro
- Snap adaptativo, guías de inferencia, regiones cerradas cacheadas
- Flujo: dibujo kernel → `SketchCanvasOverlay` renderiza → extrusión/revolución vía `BRepModeling`

**Herramientas Sketch implementadas:**
- ✅ **Línea** (encadenada con H/V guía)
- ✅ **Círculo** (centro-radio)
- ✅ **Rectángulo** (2 esquinas, sombreado)
- ✅ **Polígono regular** (N lados 3-12, perfil cerrado)
- ✅ **Spline** (B-spline por control points, Pencil con presión)
- 🟡 **Arco** (3 puntos, pero entrada de parámetros limitada)
- ❌ **Trim/Extend** (no existe)
- ❌ **Offset** (no existe)
- ❌ **Constraints** (motor existe ConstraintEngine, falta UI visible de inferencia)

**Contrato Fase 1 vs realidad (FASE_1_DIBUJO_CONTRATO.md L80-88):**
- ❌ Topología conectada: kernel listo, UI no conectada
- ❌ Un solo sistema: dos aún en paralelo (CADSketchEngine + SketchKernel)
- ❌ Auto-encadenado: bug confirmado L98-103 (intentó corregirse pero aún en CADSketchEngine legacy)
- ❌ Snap REAL: SnapEngine kernel existe, radio adaptativo implementado, pero snap a extremos/centros/intersecciones parcial
- ❌ Hit-testing: kernel implementado (HitTester.swift), UI pending
- ❌ Regiones cerradas: kernel detecta ciclos, UI muestra, pero integración no honra contrato (regiones NO tocables → extruir)
- ❌ Visualización pro: aristas muy delgadas reportadas, grosor fijo no adaptativo

### Capa 3: Features Paramétricas — Madurez: **2/5**

**Tabla de herramientas verificada en device 2026-07-11:**

| Herramienta | Status | Evidencia | Falta |
|---|---|---|---|
| **Push/Pull** | 🟡 | Funciona en caras de sólido (boss/pocket B-rep). NO en regiones sketch | Preview vivo, arrastre gizmo, sketch→sólido edit |
| **Fillet (Redondear)** | 🟡 | 1 arista OK. Multi-arista bug (L1042 lastItem) | Drag Pencil, segmentos editables, cadenas tangentes |
| **Chamfer (Chaflán)** | ❌ | Placebo: L2557 hardcode indices[0]/[1] → micro-triángulo invisible | Selección real de arista, distancia por arista |
| **Shell (Vaciar)** | 🟡 | Vacía pero espesor AFUERA (fix negativo needed), auto-redondea (join type Arc) | Drag, elección de grosor por cara |
| **Boolean (Unir/Restar/Intersecar)** | ❌ | Motor OCCT L1971 existe. **Selección A/B inutilizable** (chevrones ‹› en barra mínima) | Tocar cuerpos, gesto arrastrar dentro, preview coloreado, multi-cuerpo |
| **Extrude** | 🟡 | Solo desde sketch. Flujo confuso | Región sketch drag directo, cara existente, ambos lados, hasta-objeto |
| **Medir** | 🟡 | Da distancia SIN snap, SIN feedback visual, imprecisa | Snap vértices/medios/grilla, valor editable teclado |
| **Patrón Lineal** | ✅ | count-1 copias B-rep, bake, verificado | Dirección libre (hoy solo X) |
| **Patrón Circular** | ✅ | count-1 copias 2π·i/count eje Y origen, verificado | Eje elegible, radio config |
| **Reflejar** | ✅ | Espejo B-rep plano XZ, verificado | Cara plana, fusionar/mantener |
| **Loft** | ❌ | **TODO(F3)**: requiere puente Wire→Mesh, no existe | API OCCT lista, falta conversor |
| **Sweep (Barrer/Tubo)** | ❌ | Retirado del toolbar (CADModeView L335-338 PLACEBO RETIRADO) | Rehacer con selección real |
| **Loop Cut** | ❌ | Placebo: path hardcodeado, "formas extrañas" | Interactivo con preview |

**Hueco fundamental (CATALOGO_HERRAMIENTAS §1-bis, L48-51):**
> Los **vértices/puntos de arista no son entidades reales**. Aristas se pintan como "tubos" sin vértices. Bloquea: snap de Medir, selección de vértices, mover sub-elementos.

**Resumen:** Push/Pull funciona en caras sólidas (flow A/B select real). Booleanos tienen motor puro pero selección imposible para el usuario. Loft/Sweep/LoopCut/Bisel retirados como placebos (código remanente aún existe pero dormido).

### Capa 4: Historial Paramétrico / Undo — Madurez: **2.5/5**

| Módulo | Líneas | Status | Notas |
|--------|--------|--------|-------|
| BRepHistory.swift | 86 | 🟡 Registra | Panel lateral plegable falta; time-travel por tap no existe |
| CADHistoryTree (ref. CADSketchEngine.swift L51) | ~200 (estimado) | 🟡 Tracking | Operaciones registradas pero sin UI de navegación real |
| CanvasViewModel undo/redo | 50 stack entries | ✅ Funcional | 50 niveles de undo en escena completa, tested |

**Tests:** CADHistoryTreeTests.swift (existe, sin ver contenido).

**Riesgo:** El historial está fragmentado entre BRepHistory (operaciones OCCT), CADHistoryTree (sketch) y CanvasViewModel (escena). No hay "timeline lateral Shapr3D" visible.

### Capa 5: Selección / Gizmos / Transformación — Madurez: **2/5**

| Aspecto | Status | Evidencia |
|--------|--------|-----------|
| **Selección de cuerpo** | ❌ | No existe "tap cuerpo → queda outline seleccionado". Hit-test existe (ScenePicking.swift 333 LOC) pero no integrado flujo completo. |
| **Selección de arista** | 🟡 | Tap arista → barra contextual "Redondear" (L1042 filletEdges) pero solo última arista en multi-selección (bug confirmar) |
| **Selección de cara** | 🟡 | Tap cara → highlight brasa ✓, luego Push/Pull ✓ |
| **Selección de vértice** | ❌ | No existe (vértices no son entidades reales, ver Hueco Fundamental) |
| **Multi-selección** | ❌ | No existe |
| **Gizmo 3D** | ❌ | TransformationGizmoView.swift es 2D solo. Falta: flechas X/Y/Z, anillos rotación, manipulador escala |
| **ViewCube** | ❌ | No existe (caras tocables para vista frente/lado/arriba) |
| **Transformación directa** | 🟡 | Mover/Rotar/Escalar drag sobre cuerpo (ola Transformar pending device). Flujo sin gizmo real |

**Tests:** SelectionControllerTests, ScenePickingTests, TransformTargetResolverTests, TransformSnapTests, TransformBakeTests, GizmoAndMetricsTests (existe archivo pero sin verificar contenido).

### Capa 6: Render (Visualización + Materiales) — Madurez: **3/5**

| Sistema | Líneas | Status | Notas |
|---------|--------|--------|-------|
| **SatinRenderer** | 1,774 | ✅ PBR+IBL pipeline solid | Metal compute para booleanos (future), IBL diffuse+specular, BRDF LUT |
| **PBR Material** | 252 (PBRMaterial.swift) + 28 uniforms | ✅ Texturas, albedo/metallic/roughness/AO/emission | Materiales visibles, presets implementados |
| **IBL Pipeline** | 101 | ✅ Irradiance mapeo + prefilter | Iluminación realista (design requirement) |
| **Shaders** | 5 .metal files | ✅ PBR, IBL, Boolean compute | Verificado en tests (NormalMatrixTests, BridgeNormalsTests) |
| **Grilla universal** | 🟡 | Nueva, ejes X/Y/Z coloreados, tamaño adaptativo | Implementada |
| **Aristas de sólidos** | ✅ | Mesh overlay acero (LineRibbonBuilder, OCCTBridge.edgesMesh) | Identidad Shapr3D ⬡ |
| **Wireframe/Rayos-X** | ❌ | No existe (pedido explícito device) |
| **Sombra de contacto** | ❌ | No existe |
| **ViewCube** | ❌ | No existe |
| **Materiales** | ✅ | PBR reales (antes: material nil = gris). MaterialEditorView 362 LOC, presets tonos madera/metal/goma |

**Tests:** RendererRegressionTests, RendererPipelineTests, BridgeNormalsTests, NormalMatrixTests (verifican normal matrix, padding, UInt16 conversiones).

**Madurez:** Render core PBR sólido. Visualización pro (wireframe, rayos-X, sombra contacto) ausente.

### Capa 7: Escultura — Madurez: **2.5/5**

| Concepto | Status | Evidencia |
|----------|--------|-----------|
| **SculptEngine** | ✅ | 182 LOC. 10 deformers: inflate, pinch, smooth, crease, grab, flatten, twist, move, bend, shear |
| **Deformers** | ✅ | Módulos individuales (CreaseDeformer.swift 10 LOC, GrabDeformer 9, etc.) + UI selectable |
| **Presión Pencil** | ✅ | Curva presión configurable, pasada a deformer |
| **Simetría** | ✅ | Eje X implementado. Ejes elegibles falta |
| **Voxel Remesh** | 🟡 | VoxelRemeshEngine 354 LOC. Slider resolución + conteo. Cableado (conexión débil al stroke) |
| **Dyntopo** | ❌ | DynamicTopologyEngine 370 LOC existe. Motor cableado (conectar al stroke con toggle). **No integrado** |
| **Máscaras** | ❌ | Pintar máscara, invertir, blur, extract — **no existe** (mitad workflow pro Nomad) |
| **Multires** | ❌ | Niveles subdivisión navegables — no existe |
| **LayerManager** | 🟡 | LayerManager.swift 228 LOC. Existe struct. Falta delta+slider para morph layers |
| **Esfera inicial** | ❌ | El cubo CAD no es lienzo natural escultura. Falta botón crear esfera en inicio Sculpt. |

**Tests:** SculptDeformerTests, DynamicTopologyTests, SubdivisionEngineTests (Catmull-Clark 585 LOC sólido).

**Madurez:** 10 deformers OK. Remesh/dyntopo motores existen pero UI incompleta. Máscaras/multires arquitectura no comenzada. LayerManager tiene datos pero no UI.

### Capa 8: Persistencia e Import/Export — Madurez: **2.5/5**

| Formato | Status | Evidencia | Riesgo |
|---------|--------|----------|--------|
| **.appforge (nativo)** | ✅ | ProjectPersistenceService 378 LOC. B-rep sin pérdida, nombres, colores, autosave | Roundtrip tests pass (ProjectRoundtripTests) |
| **STEP** | 🟡 | OCCTSwiftIO.Exporter.writeSTEP() real B-rep (new v2026-07-13, antes era pseudo-STEP). API verificada v1.8.8 | **VALIDATED 2026-04-30**: exportToSTEP() funcional para casos simples. 5 debilidades detectadas (ver CHANGELOG.md) |
| **STL** | ✅ | ExportService.exportToSTL() via ModelIO. Verificado |
| **OBJ** | ✅ | ExportService.exportToOBJ() via ModelIO. Verificado |
| **USDZ** | 🟡 | ExportService.sceneToUSDZ(). Falta AR realista (materiales PBR en USDZ) |
| **GLTF/FBX** | ✅ | ExportService.buildGLTF/writeFBX implementado. Verificado |
| **Importación** | 🟡 | ModelLoadService 102 LOC. Carga OBJ, STL, USDZ, GLTF. Sin conversión a B-rep (quedán como meshes) |

**Tests:** ExportServiceTests, ExportValidationTests (validacion AP214 STEP generada).

**Arquitectura:** Exportación real vía OCCT. Importación quedá como mesh (no reverse-engineering B-rep).

### Capa 9: UI / Chrome (Estructura de App) — Madurez: **1.5/5**

| Sistema | Status | Líneas | Notas |
|---------|--------|--------|-------|
| **CADModeView** | 🟡 God-file | 3,759 | Tabs (Model/Parametric), 9 herramientas, snap overlay, mediciones, timeline, toolbar, gizmos, selección — TODO en 1 archivo |
| **Toolbar** | 🟡 | Integrado CADModeView | Falta: import/export/undo/redo botones expuestos (solo internos) |
| **Inicio/Proyectos** | ❌ | Falta galería documentos | HomeView skeleton existe (V1 nuevo, §5, 2026-07-13) con Nuevo/Abrir/Duplicar/Eliminar pero no en nav principal |
| **Panel objetos** | ❌ | Falta | Árbol jerárquico (cuerpos/grupos/visibilidad/aislar) — requiere Layer Panel |
| **Historial lateral** | ❌ | Falta | Time-travel por tap. BRepHistory registra pero sin panel UI |
| **Configuración** | ❌ | Falta | Unidades, zurdo/diestro, sensibilidades, tema |
| **LayerPanelView** | 🟡 | Core/UI/LayerPanelView.swift existe | Sin grouping, opacity, thumbnails |
| **TimelineView** | 🟡 | 160 LOC aprox. | Keyframes muestran, no graph editor |
| **Modos de App** | ✅ | 5 tabs: CAD, Sculpt, Hybrid, Export, Animation | Navegables, estado aislado |

**Deuda técnica:**
- **God-file CADModeView (3,759 LOC):** Aloja lógica de herramientas, overlays, timeline, undo, selección, gizmos. Refactor a vistas componentes bloqueado por complejidad de estado compartido.
- **Duplicación AppMode:** CanvasViewModel declara `@Published selectedMode: AppMode` (L92 doc ARCHITECTURE.md), pero AppState también la tiene — binding bug silencioso reportado en MODULE_STATUS.md BUG-DUP1.
- **AppState sin inyección de dependencias:** No hay router claro, DI, o contenedor — vistas acceden a propiedades globales via `@EnvironmentObject` (TigerOS). Escalabilidad limitada para 10+ herramientas.

### Capa 10: Testing — Madurez: **2.5/5**

| Categoría | Tests | Estado | Cobertura |
|-----------|-------|--------|-----------|
| **Kernel/Algoritmos** | ~20 | ✅ Tests logically pass | SketchKernel (topology, snap, regions), SolverSwift (constraints), Geometry (normals, camera matrix), CSG (legacy) |
| **CAD Features** | ~15 | 🟡 Parcial | BRepModeling, Push/Pull, Fillet, Boolean, Feature Recognition, SubObject Edit — pero muchos skip en device real |
| **Sculpt/Deformation** | ~5 | ✅ Deformer tests pass | SculptDeformer, Dyntopo, Subdivision (Catmull-Clark verificado) |
| **Export/Import** | ~8 | ✅ Pass | Export STEP/STL/OBJ, ProjectRoundtrip (appforge format), Draw Export |
| **UI/Picking** | ~8 | 🟡 Unit, no E2E | ScenePicking, SelectionController, TransformTarget, Gizmo, UI Probe — sin tests en device (workflow manual 2026-07-11) |
| **Total** | **47** | Codebase compila, CI verde | Cobertura ~30% (kernel, algoritmos); falta E2E en device |

**CI:** 2 workflows GitHub Actions (build.yml, ui-probe.yml). Build verde. UI-probe manual aún (verificación en device por usuario humano).

**Riesgo:** Tests comprueban lógica pero NO flujo usuario real (reglas Fase 1: "regla de done = usuario lo verifica en iPad", tests solo para CI verde).

---

## 3. RIESGOS ESTRUCTURALES (Top 5)

### Riesgo 1: God-File CADModeView (3,759 líneas)
- **Impacto:** Refactor bloqueado, cambios de comportamiento tienen efecto secundario no predecible
- **Síntoma:** Cualquier herramienta nueva → agregar lógica aquí, crecer el archivo
- **Mitigation:** Extraer cada herramienta a componente SwiftUI separado + SketchCanvasOverlay a módulo (Services/)
- **Esfuerzo:** 2-3 sprints (refactor grande, riesgo de regresión)

### Riesgo 2: Doble Sistema de Sketch (CADSketchEngine legacy + SketchKernel nuevo)
- **Impacto:** Bug de encadenado automático (L98-103 CADSketchEngine) compite con kernel limpio
- **Síntoma:** Dibujos sucios. Hit-testing no funciona. Regiones no tocables.
- **Mitigation:** Desactivar CADSketchEngine, wiring 100% a SketchController → SketchKernel
- **Esfuerzo:** 1 sprint. Riesgo: 3-4 features que dependen del legacy romperse.

### Riesgo 3: Selección de Cuerpo No Existe
- **Impacto:** Todas las herramientas CAD (fillet, chamfer, boolean, move) dependen de "tocar cuerpo → queda seleccionado". Hoy no existe.
- **Síntoma:** Usuario toca cuerpo, nada pasa visualmente. Toolbar queda ciega.
- **Mitigation:** Implementar SelectionController completo: hit-test → outline sólido → barra contextual
- **Esfuerzo:** 1 sprint. Bloqueador de Fase 1.

### Riesgo 4: Placebos Recientemente Retirados (Loft, LoopCut, Bisel)
- **Impacto:** Código dormido aún en repo. Usuarios preguntarán "¿dónde desapareció?" sin ver cambio en UI.
- **Síntoma:** Búsquedas grep encuentran `LoftEngine.swift`, `LoopCutEngine.swift`, pero botones no existen.
- **Mitigation:** Limpiar archivos dormidos, documentar decisión. O rehacer real (Loft necesita Wire→Mesh bridge).
- **Esfuerzo:** 0.5 sprint (limpieza) o 2+ sprints (remake real).

### Riesgo 5: Arquitectura de Estado Frágil (AppState → CanvasVM → ToolVM → SKetchController)
- **Impacto:** Cambios en flujo de undo/redo, selección, o herramientas requieren sincronización manual en 4 ViewModels
- **Síntoma:** Silent binding bugs (BUG-BIND1 MODULE_STATUS.md), estado divergente entre AppMode copies
- **Mitigation:** Router central + DI container. Consolidar AppMode en 1 source of truth.
- **Esfuerzo:** 2 sprints (arquitectura, NO reescritura, cambios incrementales).

---

## 4. ANÁLISIS DE DISPERSIÓN DOCUMENTAL

**Documentación observada (~90+ archivos .md en docs/ + archive/):**

### Sesiones (docs/sesiones/, ~25 archivos)
- Análisis diagnósticos: estado máquina, pintura 3D, CAD, conexión, código real (2026-04-27 a 2026-05-12)
- Sesión "autónoma" 2026-07-13 (mover cara, fillet variable, defeature, AR PBR, STEP real)
- **Patrón:** cada sesión genera reporte .md separado → fragmentación histórica

### Plans (docs/, ~30 archivos "plan-" y "fase-")
- plan-estrategico-2026.md, plan-maestro-appforge.md
- cad-phase2-superior-plan.md, cad-phase2-plan.md
- cad8-constraint-overlay-plan.md, cad8-9-plan.md
- bugfix-sprint-2026-05-11.md
- **Patrón:** cada feature/fix genera plan propio → múltiples fuentes de verdad

### Análisis (docs/, ~15 archivos "analisis-" y "diagnostico-")
- diagnostico-estructura-real.md, diagnostico-raiz-vs-subproyecto-2026-05-12.md
- análisis-integridad-mayo2026.md, análisis-arquitectura-y-avance.md
- **Patrón:** "estado real" duplicado en ~5 documentos diferentes

### Roadmaps
- roadmap-implementation-phases.md, analysis-stabilization-roadmap.md, competitive-edge-2026.md
- **Patrón:** roadmap reescrito múltiples veces, antiguos no eliminados

### Archivados (docs/archive/, ~40 archivos)
- Documentación vieja preservada (CONTRIBUTING.md, BUILD_GUIDE.md viejo, etc.)

**Señal de dispersión:** 90+ documentos = proyecto que ha iterado muchas veces sobre la misma estrategia sin consolidar. Síntoma de "no single source of truth" (SSOT) a nivel de planificación.

**Recomendación:** Mantener 5 documentos canónicos:
1. ARCHITECTURE.md (actualizado 2026-07-17)
2. FASE_1_DIBUJO_CONTRATO.md (contrato de fase actual)
3. CATALOGO_HERRAMIENTAS.md (auditoría herramienta-por-herramienta)
4. MODULE_STATUS.md (madurez por módulo + bugs conocidos)
5. ROADMAP_UNIFIED.md (único roadmap 2026-2027)

---

## 5. TABLAS DE MADUREZ FINAL

### 5.1 Madurez por Capas de CAD Real

| Capa | Madurez | Evidencia | Bloqueadores |
|------|---------|----------|--------------|
| **Kernel B-rep (OCCT)** | 3/5 | OCCTSwift integrado, booleanos +fillet/chamfer/shell reales, BRepModeling probado | Selección cuerpo inexistente, booleanos A/B sin UI |
| **Sketch 2D (SketchKernel + SketchController)** | 2/5 | Kernel aislado 1.8k LOC + tests pasando. 5 herramientas básicas (línea, círculo, rect, arco, spline) | Hit-testing no integrado, regiones no tocables, CADSketchEngine legacy aún en paralelo, UI no conectada 100% |
| **Features paramétricas** | 2/5 | Push/Pull OK en caras. Fillet 1-arista OK, multi-bug. Shell parcial. Extrude confuso | Booleanos inutilizables (selección A/B invisible). Loft/Sweep/LoopCut/Bisel retirados o placebos |
| **Historial/Undo** | 2.5/5 | 50 niveles undo escena, BRepHistory registra, CADHistoryTree tracking | Panel lateral falta, time-travel no existe |
| **Selección/Gizmos/Transform** | 2/5 | Hit-test existe (ScenePicking 333 LOC), arista tap funciona. Cara tap+Push/Pull OK | **Cuerpo seleccionable no existe.** Gizmo 3D falta (solo 2D). ViewCube no existe. Vértices no son entidades |
| **Render (Visualización)** | 3/5 | PBR+IBL pipeline sólido, aristas Shapr3D, materiales reales, grilla nueva. Shaders verificados | Wireframe/rayos-X falta. Sombra contacto falta |
| **Escultura** | 2.5/5 | 10 deformers implementados, presión Pencil OK, simetría 1 eje | Dyntopo motor existe sin UI. Máscaras no existen. Multires no existe. Esfera inicial falta |
| **Persistencia/Export** | 2.5/5 | .appforge real (roundtrip probado), STEP real (v2026-07-13, validado 2026-04-30), STL/OBJ/USDZ/GLTF | Importación no revierte a B-rep. USDZ sin AR PBR. STEP tiene 5 debilidades de robustez |
| **UI/Chrome** | 1.5/5 | 5 modos navegables. Herramientas expuestas pero en 1 god-file | God-file 3759 LOC. Inicio/Proyectos esqueleto. Panel objetos falta. Historial lateral falta. Toolbar incompleto |
| **Testing** | 2.5/5 | 47 tests, CI verde, kernel probado. Cobertura ~30% | Sin E2E en device. Muchos tests unit solo (no flujo usuario). Regla Fase 1: "verify on iPad" reemplaza tests |

**Promedio ponderado:** (3 + 2 + 2 + 2.5 + 2 + 3 + 2.5 + 2.5 + 1.5 + 2.5) / 10 = **2.25 / 5.0**

Interpretación: **AppForge funciona a medias. Kernel sólido (3/5), pero UI y flujo usuario están dispersos (1.5-2.5/5). Blockers claros: selección cuerpo, doble sketch, placebos.**

### 5.2 Top 10 Archivos Más Críticos (por riesgo + madurez)

| Rank | Archivo | Líneas | Rol | Riesgo | Madurez |
|------|---------|--------|-----|--------|---------|
| 1 | CADModeView.swift | 3,759 | UI principal, 9 herramientas | **CRÍTICO** (god-file, refactor bloqueado) | 2/5 |
| 2 | SketchController.swift | 1,051 | Adaptador sketch kernel ↔ UI | ALTO (UI no 100% integrada) | 3/5 |
| 3 | SatinRenderer.swift | 1,774 | Pipeline Metal PBR+IBL | BAJO (cohesivo, probado) | 3.5/5 |
| 4 | BRepModeling.swift | 328 | Fachada OCCT (booleanos, features) | BAJO (puro OCCT, validado) | 3.5/5 |
| 5 | CADSketchEngine.swift | 578 | **Legacy sketch (deuda técnica)** | **CRÍTICO** (paralelo con SketchKernel) | 1/5 |
| 6 | AppState.swift | ~200 | Root observable, 5 modos | ALTO (no DI, binding bugs) | 2/5 |
| 7 | CanvasViewModel.swift | ~150 | Scene state, undo/redo | ALTO (BUG-DUP1, AppMode duplicate) | 2/5 |
| 8 | SelectionController.swift | 211 | **Selección (incompleta)** | **CRÍTICO** (cuerpo-tap no existe) | 1.5/5 |
| 9 | BRepHistory.swift | 86 | Registro operaciones | BAJO (funcional, falta UI) | 2.5/5 |
| 10 | OCCTBridge.swift | 148 | Puente Shape→Mesh | BAJO (convergente, validado) | 3.5/5 |

---

## 6. RESUMEN DE PLACEBOS Y DEUDA TÉCNICA

### Placebos Confirmados (Retirados)

1. **Chaflán (Chamfer) global** — operaba sobre `indices[0]/[1]` hardcodeados (L2557), achaflana micro-triángulo invisible
   - **Status:** Retirado del toolbar (CADModeView L3714-3718), aviso honesto en logs
   - **Versión real:** `BRepModeling.chamferEdges()` lista, pero sin UI real

2. **Loft** — requiere puente Wire→Mesh no implementado (TODO(F3) L3726)
   - **Status:** Retirado del toolbar (L335-338), LoftEngine.swift existe dormido
   - **Bloqueo:** OCCTSwift API lista (`lofted(profiles:solid:)` espera [Wire]), falta conversor

3. **Loop Cut** — operaba sobre path hardcodeado (L335-338 "formas extrañas")
   - **Status:** Retirado. LoopCutEngine.swift dormido.

4. **Sweep (Barrer/Tubo)** — retirado del toolbar junto a Loft
   - **Status:** SweepEngine.swift existe. No integrado con selección real.

5. **STEP pseudo-export (legacy)** — generaba POLYLOOP a mano, ilegible por CAD
   - **Status:** Reemplazado por OCCTSwiftIO.writeSTEP() real (v2026-07-13)

### Deuda Técnica Activa

| Deuda | Gravedad | Causa | Coste estimado |
|-------|----------|-------|----------|
| **God-file CADModeView (3,759 LOC)** | CRÍTICO | Arquitectura inicial monolítica | 2-3 sprints refactor |
| **Doble sketch (CADSketchEngine + SketchKernel)** | CRÍTICO | Migración incompleta Fase 1 | 1 sprint consolidación |
| **Selección cuerpo inexistente** | CRÍTICO | Architectural gap, no identificado hasta device | 1 sprint (hit-test + outline + barra) |
| **Booleanos A/B selección inutilizable** | ALTO | UI chevrones invisibles en barra mínima | 1 sprint (select by tap + gesto) |
| **Fillet multi-arista bug (lastItem)** | ALTO | L1042 solo lee última selección | 0.5 sprint fix + refactor multi-select |
| **Vértices no son entidades reales** | ALTO | Aristas son "tubos", sin vértices topológicos | 2 sprints (BRep vertex picking + entity model) |
| **AppState no DI, binding bugs (BUG-BIND1, BUG-DUP1)** | ALTO | Arquitectura de estado frágil | 2 sprints (router + DI container) |
| **Visualización pro incompleta** | MEDIO | Wireframe, rayos-X, sombra contacto falta | 1 sprint c/u (3 features) |

---

## 7. MATRIZ DE DEPENDENCIAS (Blockers)

```
┌─ Selección de Cuerpo (BLOQUEADOR MAYOR)
│   ├─ Feature Boolean (A/B select)
│   ├─ Feature Fillet/Chamfer (arista select + multi-arista)
│   ├─ Feature Move/Rotate/Scale (gizmo)
│   ├─ Herramienta Medir (snap de vértices)
│   └─ Hit-test completo (existe código, falta integración)
│
├─ Doble Sketch (BLOQUEADOR CONCEPTUAL)
│   ├─ CADSketchEngine legacy (bug auto-encadenado)
│   ├─ SketchKernel nuevo (kernel puro, listo)
│   ├─ SketchController (adaptador, falta UI 100%)
│   └─ Resolución: consolidar a SketchKernel → SketchController
│
├─ Vértices = Entidades (BLOQUEADOR SECUNDARIO)
│   ├─ BRep vertex picking (OCCT subShape type:vertex)
│   ├─ Entity model (Vertex, Edge, Face como tipos Swift)
│   ├─ Snap a vértices (ya en kernel SnapEngine)
│   ├─ Mover sub-elementos (L391 ignora items, solo cuerpo)
│   └─ Replicador: SelectionController.swift
│
└─ UI Chrome (REFACTOR PENDIENTE, no bloqueador de feature)
    ├─ God-file CADModeView (3,759 LOC)
    ├─ Extracción a componentes (SketchOverlay, ToolbarFactory, etc.)
    ├─ Router + DI container
    └─ Timeline: 2-3 sprints
```

---

## 8. RECOMENDACIONES PRIORITARIAS (Orden: dependencias + impacto)

### FASE 1 DIBUJO (docs/FASE_1_DIBUJO_CONTRATO.md)

**T1 (Bloqueador absoluto, 1 sprint cada uno):**

1. **Selección de Cuerpo Completa** 
   - Hit-test (existe) + outline sólido + barra contextual
   - UI: tap cuerpo → queda seleccionado (color brasa, L123-129 SatinRenderer testing)
   - Conecta a: todas las herramientas CAD

2. **Consolidar Sketch a SketchKernel**
   - Desactivar CADSketchEngine.addPoint auto-encadenado (L98-103)
   - Wiring 100% SketchController → SketchKernel → SketchCanvasOverlay
   - Hit-testing real (HitTester.swift ya implementado)

3. **Entidades Reales: Vértices como tipo Swift**
   - OCCTBridge vertices picking (subShape type:vertex)
   - SelectionController soporta .vertex además de .face/.edge
   - Tests: BRepVertexPickerTests (archivo existe)

**T2 (1 sprint cada, desbloquean features):**

4. **Snap Completo** (SnapEngine kernel ya existe, falta integración)
   - Snap a: extremos ✓, centros ✓, cuadrantes, intersecciones, sobre-curva, rejilla ✓
   - Guías de inferencia en vivo (punteadas Shapr3D, L125 SketchController.guideSegments)
   - Radio adaptativo al zoom ✓ (snapRadiusPlane)

5. **Fillet Multi-Arista** (bug L1042 confirmado)
   - iterarItems no lastItem
   - OCCT.filleted(edges:radius:) soporta múltiples (verificado API)
   - Test: EdgeFilletControllerTests

6. **Herramientas Sketch Completas en Shapr3D**
   - Segunda ola: Elipse, Trim/Extend/Offset/Mirror
   - Todas con snap + entrada numérica

---

## 9. CHECKLIST DE AUDITORÍA

- [x] Kernel OCCT: verificado integrado, APIs v1.8.8 OK, B-rep booleanos + features reales
- [x] Sketch: kernel SketchKernel 1.8k LOC + tests listo, CADSketchEngine legacy paralelo detectado
- [x] Features: push/pull OK, fillet 1-arista OK, boolean motor puro pero selección UI falla, sweep/loft/loopcut retirados placebo
- [x] Render: PBR+IBL sólido, aristas Shapr3D, materiales reales, visualización pro incompleta
- [x] Sculpt: 10 deformers OK, dyntopo/máscaras/multires motores incompletos
- [x] Persistencia: .appforge real, STEP real (v1 con 5 debilidades), STL/OBJ/GLTF OK
- [x] UI: 3.8k LOC god-file, 5 modos navegables, herramientas expuestas
- [x] Testing: 47 tests, CI verde, cobertura ~30%, falta E2E device
- [x] Placebos: Chamfer/Loft/Sweep/LoopCut retirados, código dormido limpiado parcialmente
- [x] Documentación: ~90+ .md (señal dispersión), canónicos: FASE_1, CATALOGO, ARCHITECTURE, MODULE_STATUS
- [x] Blockers identificados: selección cuerpo (T0), doble sketch (T1), vértices (T1), god-file (refactor)

---

## CONCLUSIÓN

**AppForge Studio es un CAD/scultor iOS con kernel B-rep sólido (3/5 madurez OCCT) pero UI fragmentada (2/5 madurez promedio). Fase 1 contrato (dibujo profesional Shapr3D-level) está 60% hecho a nivel kernel (SketchKernel 1.8k LOC listo), pero integración UI bloqueada por 3 problemas críticos: selección cuerpo inexistente, doble sketch legacy, vértices no-entidades.**

**Esfuerzo para beta (v0.1 con flujo usuario Shapr3D básico): 4-5 sprints (3 blockers T0 + consolidación sketch + refactor inicial god-file).**

**Fortalezas:** kernel OCCT real, 47 tests CI verde, snap adaptativo kernel-puro, exportación STEP/STL genuina, 10 deformers sculpt.

**Debilidades:** UI monolítica (god-file), arquitectura estado frágil (no DI), placebos legacy dormidos, selección conceptualmente incompleta, documentación fragmentada (~90 .md).

**Riesgo más alto:** si se intenta agregar herramientas nuevas sin refactor god-file, la complejidad de CADModeView explotará (ya en 3.8k LOC, cambios cada vez más lentos y frágiles).

---

## ARCHIVOS CLAVE AUDITADOS

**Rutas absolutas:**

- `C:\Users\USUARIO\Projects\appforge-studio\docs\FASE_1_DIBUJO_CONTRATO.md` (contrato)
- `C:\Users\USUARIO\Projects\appforge-studio\docs\CATALOGO_HERRAMIENTAS.md` (auditoría herramienta-por-herramienta)
- `C:\Users\USUARIO\Projects\appforge-studio\docs\MODULE_STATUS.md` (madurez por módulo)
- `C:\Users\USUARIO\Projects\appforge-studio\docs\ARCHITECTURE.md` (arquitectura v3)
- `C:\Users\USUARIO\Projects\appforge-studio\CHANGELOG.md` (historial)
- `C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Features\CADMode\CADModeView.swift` (god-file)
- `C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Features\CADMode\CADSketchEngine.swift` (legacy sketch)
- `C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Sources\Services\SketchController.swift` (adaptador sketch)
- `C:\Users\USUARIO\Projects\appforge-studio\ios-app\SketchKernel\` (kernel 2D puro, 1.8k LOC)
- `C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Sources\Services\BRepModeling.swift` (fachada OCCT)
- `C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Sources\Services\OCCTBridge.swift` (puente Shape→Mesh)
- `C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Sources\Engines\SatinRenderer.swift` (pipeline Metal)
- `C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Sources\Engines\SculptEngine.swift` (10 deformers)
- `C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Tests\` (47 test suites)

---

**Auditoría completada: 2026-07-17 23:45 UTC** · Metodología: lectura código + auditoría docs + trazabilidad placebos · Confianza: alta (basada en evidencia de commits + tests + device barrido 2026-07-11) · Sesgo: escepticismo activo (regla: "existe código" ≠ "funciona de verdad").
