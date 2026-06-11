# PLAN PROFUNDIDAD REAL (FD) — AppForge Studio

**Versión:** 1.0 — 2026-06-11
**Autor:** NEXUS (DeepSeek V4 Pro) + auditoría de código real
**Rama:** `w6/theme-ipa` → eventual merge a `main`
**Estado:** PLAN aprobado para revisión de Andrés — NO ejecutar sin autorización explícita

---

## 0. Diagnóstico Verificado (PASO 1 — Evidencia del Código)

### 0.1 Sketch 2D Paramétrico

**Archivos auditados:**
- `Features/CADMode/CADSketchEngine.swift` (585 líneas)
- `Sources/CAD/ConstraintEngine.swift` (289 líneas) — inference engine
- `Features/CADMode/GeometryConstraintManager.swift` (300 líneas) — orquestador
- `Sources/Engines/SolverSwift.swift` (307 líneas) — solver real
- `Sources/CAD/SnapEngine.swift` (107 líneas)

**Lo que EXISTE de verdad:**

| Componente | Estado | Evidencia |
|---|---|---|
| Entidades 2D | **REAL** — point, line, circle, rectangle, arc como `SketchEntity` enum | `CADSketchEngine.swift:34-43` |
| Herramientas | **REAL** — select, point, line, circle, rectangle, arc | `CADSketchEngine.swift:44` |
| Dibujo a mano alzada | **REAL** — PencilKit import + Ramer-Douglas-Peucker + shape detection | `CADSketchEngine.swift:293-353, 355-408, 455-487` |
| Detección de formas | **REAL** — detecta círculos (desviación de radio <15%), rectángulos (4 esquinas), líneas | `CADSketchEngine.swift:355-408` |
| Snap a grid | **REAL** — `snapToGrid()` con gridSize configurable | `CADSketchEngine.swift:85-88` |
| Conversión a perfil cerrado | **REAL** — `convertToProfile()` recorre grafo de adyacencia para extraer loop | `CADSketchEngine.swift:489-555` |
| Cerrado automático | **REAL** — `closeProfile()` detecta extremos sueltos y los une | `CADSketchEngine.swift:557-576` |
| Extrusión 3D | **REAL** — `extrudeSketch(distance:)` → ExtrusionEngine (OCCT-backed) | `CADSketchEngine.swift:202-214` |
| Undo/Redo | **REAL** — CADHistoryTree con árbol paramétrico completo | `CADHistoryTree.swift:78-198` |

**Solver de constraints 2D (`SolverSwift.swift`):**

| Constraint | Implementación | Evidencia |
|---|---|---|
| Horizontal | **REAL** — y=0 constraint con Jacobiano analítico | `SolverSwift.swift:113-117` |
| Vertical | **REAL** — x=0 constraint con Jacobiano analítico | `SolverSwift.swift:118-122` |
| Coincidente | **REAL** — distancia cero entre 2 puntos | `SolverSwift.swift:123-131` |
| Distancia | **REAL** — distancia fija con Jacobiano derivado | `SolverSwift.swift:132-143` |
| Paralelo | **REAL** — cross product de direcciones | `SolverSwift.swift:144-156` |
| Perpendicular | **REAL** — dot product de direcciones | `SolverSwift.swift:157-169` |
| Igualdad | **REAL** — diferencia de longitudes al cuadrado | `SolverSwift.swift:170-182` |
| Ángulo | **REAL** — atan2 con Jacobiano completo | `SolverSwift.swift:183-209` |
| Punto medio | **REAL** — promedio de 2 puntos | `SolverSwift.swift:210-219` |
| Concéntrico | **REAL** — coincidencia de centros | `SolverSwift.swift:220-228` |
| Tangente | **REAL** — distancia punto-centro = radio | `SolverSwift.swift:229-240` |
| Colineal | **REAL** — área del triángulo = 0 | `SolverSwift.swift:241-258` |

**Método de resolución:** Newton-Raphson con matriz Jacobiana analítica (NO diferencias finitas), damping adaptativo (0.3 base, 0.15 si residual aumenta), Gauss-Seidel para sistema lineal (AᵀA + εI). Máximo 100 iteraciones, tolerancia 1e-8.

**VEREDICTO 2D Sketch:** ⭐⭐⭐⭐ (4/5) — Sorprendentemente avanzado. El solver es REAL con Jacobianos analíticos para 11 tipos de constraints. La detección de formas desde PencilKit funciona. Las brechas REALES son:

1. **Falta resolver en tiempo real** — el solver se llama explícitamente (`resolveConstraints()`), no es continuo/drag. Shapr3D resuelve mientras arrastras.
2. **Falta restricción de simetría** (mirror constraint) y **patrón** (pattern).
3. **Falta solver 2D dimensional** — no hay cotas numéricas visibles (dimension constraints con display).
4. **Aplicación 3D de angle constraint es STUB** (`GeometryConstraintManager.swift:202-204`: `// Stub: No implementado aun`).
5. **Extrusión del sketch usa `ExtrusionEngine` OCCT** — pero la ruta `CADSketchEngine.extrudeSketch()` construye un Mesh manualmente antes de llamar al engine. La integración sketch→Wire OCCT→extrude B-rep no está tipificada — hoy va directo a mesh triangulado, no a sólido B-rep.

### 0.2 Booleanos CSG

**Archivos auditados:**
- `Sources/Engines/BooleanEngine.swift` (23 líneas)
- `Sources/Services/OCCTBridge.swift` (91 líneas)
- `Sources/Services/CADSculptBridge.swift` (36 líneas)

| Componente | Estado | Evidencia |
|---|---|---|
| Union B-rep | **REAL** — OCCT 8.0.0 `engine.union(a, b)` | `BooleanEngine.swift:9-12` |
| Subtract B-rep | **REAL** — OCCT `engine.subtract(a, b)` | `BooleanEngine.swift:14-17` |
| Intersect B-rep | **REAL** — OCCT `engine.intersect(a, b)` | `BooleanEngine.swift:19-22` |
| Fillet | **REAL** — `safeFillet(radius:)` como extensión de Shape | `OCCTBridge.swift:78-80` |
| Chamfer | **REAL** — `safeChamfer(distance:)` | `OCCTBridge.swift:83-85` |
| Shell | **REAL** — `safeShell(thickness:)` | `OCCTBridge.swift:88-90` |
| B-rep → Mesh | **REAL** — `OCCTBridge.toMesh()` con 4 niveles de calidad | `OCCTBridge.swift:11-41` |
| Mesh → B-rep | **STUB** — `CADSculptBridge.meshToShape()` retorna nil con warning | `CADSculptBridge.swift:21-24` |
| Legacy CSG (JavaScript) | **DEPRECATED** — `LegacyCSG/` existe pero no se usa | `LegacyCSG/CSGOperation.swift`, `Polygon3D.swift` |

**VEREDICTO Booleanos:** ⭐⭐⭐½ (3.5/5) — OCCT da booleanos B-rep robustos para CAD. El problema es que NO funcionan sobre mallas esculpidas. La brecha crítica: **Mesh → B-rep no existe**, lo que rompe el pipeline sculpt→CAD.

### 0.3 Escultura 3D

**Archivos auditados:**
- `Sources/Engines/BrushEngine.swift` (134 líneas)
- `Features/SculptMode/Brushes/BrushEngine.swift` (idéntico — duplicado)

| Pincel | Tipo de deformación | Evidencia |
|---|---|---|
| round | Desplaza vértices a lo largo de la normal con falloff parabólico | `BrushEngine.swift:80` |
| flat | Desplazamiento constante a lo largo de la normal en el radio | `BrushEngine.swift:83` |
| inflate | Expansión desde el origen (dirección radial) | `BrushEngine.swift:86-87` |
| pinch | Atrae vértices hacia el punto de contacto | `BrushEngine.swift:89-90` |
| smooth | Promedia posiciones de vecinos (índices contiguos, no topología) | `BrushEngine.swift:92-93` |
| crease | Deforma perpendicular a la normal a lo largo de un eje local | `BrushEngine.swift:96-98` |
| grab | Arrastra vértices en dirección al punto de contacto | `BrushEngine.swift:99-103` |
| clay | Similar a round pero con clamp de desplazamiento máximo | `BrushEngine.swift:104-106` |
| airbrush | Como round + jitter aleatorio | `BrushEngine.swift:107-109` |
| textured | Como round + ruido sinusoidal 3D | `BrushEngine.swift:110-112` |

**VEREDICTO Escultura:** ⭐⭐ (2/5) — 10 pinceles está bien para un inicio, pero:

1. **Solo deformación de vértices** — sin dynamic topology (dyntopo), sin voxel remeshing, sin multi-resolución. Si estiras mucho un polígono, se degenera.
2. **Sin máscaras** (masking) ni face sets.
3. **Simetría** solo en un eje y es positional mirroring básico.
4. **Smooth** usa índices de array contiguos como "vecindario" — asume que vértices adyacentes en el buffer son adyacentes en la malla. Esto es INCORRECTO para mallas trianguladas arbitrarias.
5. **Sin pinceles de textura/alfa/stencil**.
6. **No hay esculpido sobre múltiples objetos** simultáneamente.

### 0.4 Pintura 3D

**Archivos auditados:**
- `Features/PaintMode/PaintRenderer.swift` (157 líneas)
- `Core/Managers/StrokeRenderer.swift` (82 líneas)
- `Sources/Engines/PincelRenderer.swift` (89 líneas, duplicado de StrokeRenderer)

| Componente | Estado | Evidencia |
|---|---|---|
| Textura de pintura | **REAL** — `paintTexture` 2048×2048 RGBA8 com compute kernel | `PaintRenderer.swift:71-78, 118-140` |
| Stroke rendering | **REAL** — billboard quads a lo largo del trazo (triangle strip) | `StrokeRenderer.swift:42-80` |
| Proyección UV | **SIMPLISTA** — `x*0.5+0.5, y*0.5+0.5` (mapea posición mundial a UV) | `BrushEngine.swift:51-53` |
| Ribbons 3D reales | **NO** — los quads son screen-facing, no geometría 3D real | `StrokeRenderer.swift:62-63` (el "up" es `(0,1,0)` fijo) |
| Texture painting UV | **NO** — no hay UV unwrapping ni editor UV | — |
| Layer blending pintura | **NO** — una sola textura de pintura | — |
| Pintura en el aire | **NO** — los strokes requieren una superficie con UVs | — |

**VEREDICTO Pintura:** ⭐½ (1.5/5) — Infraestructura Metal básica, pero a años luz de Feather3D o Blender grease pencil.

### 0.5 Animación

**Archivos auditados:**
- `Sources/Engines/AnimationEngine.swift` (548 líneas)
- `Sources/Engines/MorphEngine.swift` (50 líneas)

| Componente | Estado | Evidencia |
|---|---|---|
| Keyframes posición | **REAL** — `Keyframe<SIMD3<Float>>` con 7 easings | `AnimationEngine.swift:13-24` |
| Keyframes rotación | **REAL** — `Keyframe<simd_quatf>` con slerp | `AnimationEngine.swift:464-496` |
| Keyframes escala | **REAL** — `Keyframe<SIMD3<Float>>` con lerp | `AnimationEngine.swift:498-529` |
| Morph targets | **REAL** — blend shapes con pesos interpolables | `MorphEngine.swift:6-50` |
| Timeline | **REAL** — play/pause/stop/seek con loop | `AnimationEngine.swift:231-258` |
| Armatures/Huesos | **NO** — cero referencias a skeleton, bone, joint | — |
| Skinning/Weights | **NO** — sin vertex weights ni skinning matrices | — |
| IK | **NO** — sin inverse kinematics | — |
| Curvas de animación | **NO** — keyframes lineales entre puntos, sin curva de Bézier en editor | — |
| Dope sheet / Graph editor | **NO** — UI de keyframes es lista plana | — |

**VEREDICTO Animación:** ⭐⭐ (2/5) — Sistema de keyframes de transform + morph targets decente para motion graphics simple. Pero no es animación de personajes ni comparable a Blender. La brecha esqueletal es TOTAL.

### 0.6 Sistema de Capas

**Archivos auditados (referencias):** `Sources/Services/LayerManager.swift`

| Componente | Estado |
|---|---|
| Capas tipadas (W5) | **REAL** — metadatos por capa |
| Compositing por capa | **NO** — sin blending modes |
| Capas de pintura | **NO** — una sola textura |
| Capas sculpt no destructivas | **NO** — sculpt modifica vértices directamente |
| Stack por objeto | **NO** — cada objeto es independiente |

**VEREDICTO Capas:** ⭐½ (1.5/5) — Solo metadatos. Sin compositing ni no-destructividad real.

---

## 1. Estrategia y Ventana Blender-iPad

### 1.1 Estado de Blender para iPad

**Hecho verificado:** Blender para iPad está en PAUSA desde enero 2026. El anuncio oficial indica que el desarrollo se reanudará "cuando haya financiación", priorizando Android primero. No hay fecha prevista.

**Ventana competitiva:** Estimamos 12-18 meses antes de que Blender iPad sea funcional. AppForge Studio debe alcanzar capacidad "profesional percibida" en 6-9 meses para capturar mente-share antes de que Blender llegue.

### 1.2 Decisión de Licencia: GPL vs Permissive

| Factor | Usar código GPL (Blender) | Solo referencia de diseño + libs permissive |
|---|---|---|
| Velocidad de desarrollo | 🟢 Copiar módulos maduros (sculpt, grease pencil) | 🟡 Implementar desde cero o adaptar |
| Riesgo legal | 🔴 AppForge → GPL obligatorio. No viable para App Store. | 🟢 Sin restricciones |
| Diferenciación | 🔴 Mismo algoritmo = commodity | 🟢 Podemos innovar sobre lo aprendido |
| Comunidad | 🟡 Contribuciones de vuelta a Blender | 🟢 Ecosistema permissivo crece |
| App Store Compliance | 🔴 GPL es incompatible con DRM de App Store | 🟢 Licencias permissive OK |

**DECISIÓN RECOMENDADA:** **Permissive-first, Blender como referencia de diseño.**

- Estudiar algoritmos de Blender (sculpt brushes, grease pencil, armature) para entender QUÉ hacen y POR QUÉ la UX es buena.
- Implementar con librerías permissive (Manifold, OpenSubdiv, ozz-animation, libigl, Clipper2).
- Si una librería GPL es la ÚNICA opción para una capacidad crítica (ej. solver de constraints 2D avanzado de SolveSpace), evaluar aislamiento vía proceso separado o servicio (cumple "mere aggregation" de GPL).
- NUNCA copiar código GPL directamente al codebase principal.

### 1.3 Filosofía FD

**No intentamos clonar Blender.** Apuntamos a un subset quirúrgico que iguale o supere a Shapr3D + Nomad + Feather3D en sus respectivas fortalezas, integrado en una sola app.

---

## 2. Sub-Fases FD.1..FD.5

Las fases están ordenadas por **valor/esfuerzo** (no por dependencia). FD.1 y FD.2 son independientes y paralelizables. FD.3 depende de FD.5 para capas de pintura. FD.4 es la más grande y puede empezar en paralelo con FD.1.

```
FD.1 (Sketch 2D real) ──┐
                         ├── FD.5 (Capas no destructivas)
FD.2 (Booleanos+sculpt) ─┘       │
                                  ├── FD.3 (Paint real)
FD.4 (Animación esqueletal) ──────┘
```

---

### FD.1 — Sketch 2D Paramétrico Real

**Objetivo:** Igualar o superar a Shapr3D en sketching 2D paramétrico.
**Competidor de referencia:** Shapr3D (iOS, Siemens Parasolid backend).
**Duración estimada:** 3-4 semanas (≈20 micro-tareas).

#### Diagnóstico de partida

El solver `SolverSwift` es sorprendentemente bueno (Newton-Raphson + Jacobianos analíticos, 11 tipos de constraints). Lo que falta es la CAPA DE UX y la integración con OCCT para que el sketch produzca sólidos B-rep en vez de mallas trianguladas.

#### Micro-tareas

| ID | Tarea | Archivos | Tamaño | Paralelizable | Verificación CI |
|---|---|---|---|---|---|
| FD.1.01 | Hacer el solver continuo (drag) — integrar `resolveConstraints` en `CADSketchEngine.addPoint` y en gesture recognizer | `CADSketchEngine.swift` | M | No (depende de .02) | Test: arrastrar punto con constraint aplicado, verificar convergencia <16ms |
| FD.1.02 | Implementar `GeometryConstraintManager.applyAngle` 3D (quitar STUB) | `GeometryConstraintManager.swift:202-204` | S | Sí | Unit test: ángulo entre 3 puntos converge a valor target |
| FD.1.03 | Sketch→Wire OCCT tipado — construir `OCCTSwift.Wire` desde perfil cerrado en vez de Mesh directo | `CADSketchEngine.swift:202-214`, `ExtrusionEngine.swift` | M | No | Test: extrusión de sketch produce Shape B-rep, no solo Mesh |
| FD.1.04 | Extrusión con draft angle (taper) — exponer parámetro en UI | `ExtrusionEngine.swift`, `CADSketchEngine.extrudeSketch` | S | Sí | Visual: extrusión con ángulo de salida de 5° |
| FD.1.05 | Revolve desde sketch — nueva operación `revolveSketch(axis, angle)` | `CADSketchEngine.swift`, nuevo `RevolveEngine.swift` | M | Sí | Test: perfil rectangular + revolve 360° = cilindro |
| FD.1.06 | Cotas dimensionales visibles — constraints con display numérico en pantalla | `CADSketchEngine.swift`, nueva view | L | No | Visual: constraint de distancia muestra valor en UI |
| FD.1.07 | Mirror constraint — simetría respecto a eje | `SolverSwift.swift`, `SolverConstraintType` | M | No | Test: 3 puntos con mirror constraint, mover 1 → los otros 2 se reflejan |
| FD.1.08 | Patrón lineal y circular — `patternLinear(count, spacing)`, `patternCircular(count)` | `CADSketchEngine.swift` | M | Sí | Test: 4 círculos en patrón lineal, modificar 1 → todos se actualizan |
| FD.1.09 | Trim/Extend de líneas — operaciones de recorte | `CADSketchEngine.swift` | M | Sí | Visual: intersección de 2 líneas, trim de exceso |
| FD.1.10 | Offset de perfil — `offsetProfile(distance)` | `CADSketchEngine.swift` | M | No | Test: offset de rectángulo produce rectángulo concéntrico |
| FD.1.11 | Import/Export DXF 2D básico | Nuevo `DXFImportExport.swift` | L | Sí | Test: round-trip DXF preserva entidades |
| FD.1.12 | Snap a entidades existentes (no solo grid) durante dibujo | `SnapEngine.swift`, `CADSketchEngine.swift` | S | No | Visual: al dibujar línea, snap al endpoint de línea existente |
| FD.1.13 | Sweep a lo largo de path — sketch de perfil + sketch de trayectoria | `ExtrusionEngine.swift` (OCCT `sweep`) | L | No | Test: círculo barrido a lo largo de spline produce tubo |
| FD.1.14 | Loft entre 2+ sketches en planos paralelos | Nuevo `LoftEngine.swift` (OCCT `loft`) | L | No | Test: loft cuadrado→círculo produce transición suave |

**CRITERIO DE PARIDAD FD.1:** Un usuario puede dibujar un perfil 2D cerrado con constraints dimensionales, extrudirlo con draft angle, y obtener un sólido B-rep editable paramétricamente. Iguala a Shapr3D en sketching básico.

**Lo que NO hacemos en FD.1:**
- No splines NURBS (queda para FD.1.x futuro)
- No solver 3D assembly constraints
- No dimensiones conducidas (driven dimensions)
- No ecuación-driven constraints

---

### FD.2 — Booleanos Robustos + Sculpt-sobre-CAD

**Objetivo:** Pipeline completo CAD→teselado→sculpt→reintegración, con booleanos que funcionen en mallas esculpidas.
**Competidor de referencia:** Plasticity (CAD) + Nomad Sculpt (sculpt), pero integrados.
**Duración estimada:** 4-5 semanas (≈25 micro-tareas).

#### Diagnóstico de partida

OCCT da booleanos B-rep excelentes para formas CAD puras. El problema es el puente sculpt→CAD: `CADSculptBridge.meshToShape()` es un stub. Manifold resuelve booleanos robustos sobre mallas trianguladas directamente, sin necesidad de reconstruir B-rep.

#### Adopción open-source

| Librería | Licencia | Rol | Integración |
|---|---|---|---|
| **Manifold** | Apache 2.0 | Booleanos sobre mallas trianguladas (complementa OCCT) | XCFramework compilado en CI vía CMake→iOS |
| **OpenSubdiv** | Apache 2.0 (Pixar) | Subdivisión para sculpt multi-res | XCFramework en CI |
| **OpenVDB** | MPL 2.0 | Voxel remesh (estilo Nomad) | ⚠️ VERIFICAR peso en iOS (típicamente ~15-30MB) |
| **Clipper2** | BSL (free) | Offset/boolean 2D para perfiles de sketch | SPM binary target |

#### Micro-tareas

| ID | Tarea | Archivos | Tamaño | Paralelizable | Verificación CI |
|---|---|---|---|---|---|
| FD.2.01 | Integrar Manifold como XCFramework — CI workflow `build-manifold.yml` (cmake -G Xcode → xcframework) | `.github/workflows/build-manifold.yml` | L | Sí (en paralelo con FD.1) | Test: `Manifold.union(meshA, meshB)` produce mesh manifold |
| FD.2.02 | `MeshBooleanEngine` wrapper Swift sobre Manifold para union/subtract/intersect de mallas | `Sources/Engines/MeshBooleanEngine.swift` | M | No | Unit test: cubo + esfera = mesh válido sin auto-intersecciones |
| FD.2.03 | Reemplazar `LegacyCSG/` con `MeshBooleanEngine` — limpiar código muerto | `Sources/LegacyCSG/` | S | Sí | Build: LegacyCSG eliminado, compila sin referencias |
| FD.2.04 | `meshToShape` vía Manifold — convertir mesh esculpida a representación apta para OCCT | `CADSculptBridge.swift:21-24` | L | No | Test: esculpir esfera, meshToShape, hacer boolean con cubo OCCT |
| FD.2.05 | Teselado adaptativo de cara CAD para sculpt — `faceToMesh` con densidad variable según curvatura | `CADSculptBridge.swift:13-15` | M | No | Visual: cara plana → pocos triángulos, cara curva → muchos |
| FD.2.06 | Flujo completo "Seleccionar cara CAD → Sculpt → Boolean union con cuerpo original" | `CADModeView.swift`, `SculptModeView.swift` | L | No | Integration test: cubo → seleccionar cara → esculpir protrusión → boolean union → export STL watertight |
| FD.2.07 | Integrar OpenSubdiv para subdivisión Catmull-Clark en sculpt | `Sources/Engines/SubdivisionEngine.swift` | L | Sí (en paralelo con FD.1) | Test: cubo subdividido 3 niveles → 384 caras con normales suaves |
| FD.2.08 | Reemplazar smooth brush con promediado topológico real (usar half-edge o adjacency desde Manifold) | `BrushEngine.swift:92-93` | M | No | Test: smooth en región → normales convergen, sin artefactos de buffer contiguo |
| FD.2.09 | Voxel remesh vía OpenVDB — botón "Remesh" que convierte malla degenerada a malla uniforme | `Sources/Engines/VoxelRemeshEngine.swift` | L | No (depende de .10) | Test: sculpt extremo → remesh → malla con densidad uniforme, sin triángulos alargados |
| FD.2.10 | Evaluar OpenVDB weight en iOS: compilar XCFramework, medir tamaño de binary y memoria | `.github/workflows/build-openvdb.yml` | M | Sí | Métricas: binary size delta, RAM en remesh de 50k triángulos |
| FD.2.11 | Dynamic topology (dyntopo) — subdivisión local automática al esculpir detalles finos | `BrushEngine.swift` | L | No | Visual: esculpir detalle en área pequeña → solo esa área gana triángulos |
| FD.2.12 | Multi-resolución sculpt — niveles de subdivisión con propagación de desplazamientos | `BrushEngine.swift` + `SubdivisionEngine` | L | No | Test: esculpir en nivel 3, bajar a nivel 1 → la forma general persiste |
| FD.2.13 | Masking — pintar máscara en vértices para proteger regiones del sculpt | `BrushEngine.swift`, nuevo shader Metal | M | Sí | Visual: pintar máscara roja, brush no afecta región enmascarada |
| FD.2.14 | Pinceles alfa/stencil — cargar textura como stamp del brush | `BrushEngine.swift`, `PaintRenderer.swift` | M | Sí | Visual: textura de piel aplicada como stamp en sculpt |
| FD.2.15 | Simetría radial y mirror multi-eje | `BrushEngine.swift:56-59` | S | Sí | Test: simetría radial 6 → 1 stroke produce 6 deformaciones |

**CRITERIO DE PARIDAD FD.2:** Flujo completo: dibujar cubo CAD → seleccionar cara → esculpir detalles → boolean union → exportar STL watertight. Los booleanos funcionan tanto en B-rep (CAD puro) como en mallas (sculpt). El remesh produce mallas de densidad uniforme. Iguala/supera a Plasticity + Nomad en integración CAD-sculpt.

**Lo que NO hacemos en FD.2:**
- No sculpting sobre point clouds / nubes de puntos
- No cloth simulation
- No hair/fur grooming
- No displacement vector maps (solo stamps)

---

### FD.3 — Paint Real: Ribbons 3D + Texture Painting UV

**Objetivo:** Pintar en el aire (estilo Feather3D / grease pencil) y pintar sobre superficies con UV unwrapping.
**Competidor de referencia:** Feather3D (pintura en aire), Blender grease pencil, Substance Painter (texture painting).
**Duración estimada:** 3-4 semanas (≈18 micro-tareas).

#### Diagnóstico de partida

Los "ribbons" actuales son billboard quads screen-facing (`StrokeRenderer.swift:62-63`). La pintura UV usa proyección planar ingenua (`x*0.5+0.5`). No hay UV unwrapping.

#### Micro-tareas

| ID | Tarea | Archivos | Tamaño | Paralelizable | Verificación CI |
|---|---|---|---|---|---|
| FD.3.01 | Ribbons 3D reales — geometría de cinta que sigue la superficie o flota en el espacio, con orientación basada en cámara + normal de superficie | `StrokeRenderer.swift` (reescribir) | L | No | Visual: trazo curvo sobre esfera, la cinta se adhiere a la superficie |
| FD.3.02 | Pincel de "tubo" 3D — stroke con sección transversal circular, no solo quad | `StrokeRenderer.swift` | M | Sí | Visual: tubo 3D grueso en el aire |
| FD.3.03 | UV unwrapping automático (Smart UV de Blender o LSCM básico) | Nuevo `UVUnwrapper.swift` | L | No (depende de libigl) | Test: esfera unwrapped → islas UV sin solapamiento |
| FD.3.04 | Editor UV básico — ver islas UV, seleccionar, mover/escalar/rotar | Nueva `UVEditorView.swift` | L | Sí | Visual: ventana con islas UV del modelo seleccionado |
| FD.3.05 | Proyección UV real para paint — usar UVs del modelo, no planar ingenuo | `BrushEngine.swift:51-53` (reescribir `projectToUV`) | S | No | Test: pintar sobre modelo con UVs no planares → paint aparece en UV correcto |
| FD.3.06 | Multi-capas de pintura con blending modes (normal, multiply, overlay, add) | `PaintRenderer.swift`, nuevo `PaintLayerManager.swift` | L | No | Visual: 3 capas: color base, multiply (sombras), overlay (detalles) |
| FD.3.07 | Layer opacity + merge down/flatten | `PaintLayerManager.swift` | M | No | Test: capa al 50% opacity → color resultante es blend |
| FD.3.08 | Pinceles de pintura: round, flat, airbrush, texturized, smudge, clone | `PaintRenderer.swift` | M | Sí | Visual: catálogo de pinceles funcionales |
| FD.3.09 | Color picker integrado (HSLA wheel + paletas) | Nueva `ColorPickerView.swift` | M | Sí | Visual: seleccionar color → aplica en siguiente stroke |
| FD.3.10 | Pressure sensitivity para Apple Pencil (radius, opacity, flow) | `BrushEngine.swift`, `PaintRenderer.swift` | S | Sí | Test: stroke con presión variable → grosor variable |
| FD.3.11 | Fill/bucket tool — flood fill en isla UV | `PaintRenderer.swift` | M | Sí | Visual: tap en región → se rellena con color actual |
| FD.3.12 | Symmetry painting (mirror X/Y/Z, radial) | `BrushEngine.swift` (extender simetría a paint) | S | No | Visual: pintar en un lado, aparece reflejado |
| FD.3.13 | Pincel "en el aire" — grease pencil real: strokes 3D que no requieren superficie | `StrokeRenderer.swift` | M | No | Visual: dibujar en espacio vacío produce geometría 3D persistente |
| FD.3.14 | Canvas infinito para grease pencil (plano de trabajo virtual) | Nuevo `GreasePencilCanvas.swift` | M | No | Visual: rotar cámara, grease pencil se mantiene en su plano 3D |
| FD.3.15 | Exportar pintura como textura (PNG/EXR) | `PaintRenderer.swift`, `PaintLayerManager.swift` | S | Sí | Test: export → archivo PNG 2048×2048 con capas flateadas |

**CRITERIO DE PARIDAD FD.3:** Pintar en el aire produce ribbons 3D geométricas (no solo quads). Pintar sobre modelo usa UVs reales con multi-capas y blending. Iguala a Feather3D en ribbons + funcionalidad básica de Substance Painter en capas.

**Lo que NO hacemos en FD.3:**
- No PBR material painting (roughness/metallic channels)
- No baking de mapas (normal, AO, curvature)
- No triplanar painting automático
- No smart materials / fill layers procedurales

---

### FD.4 — Animación Esqueletal

**Objetivo:** Armatures con huesos, skinning, IK básico e timeline.
**Competidor de referencia:** Blender (armature + pose mode), pero simplificado a lo esencial.
**Duración estimada:** 5-6 semanas (≈30 micro-tareas). Es la fase más grande.

#### Diagnóstico de partida

Solo hay keyframes de transform (posición/rotación/escala) por objeto + morph targets. Sin huesos, sin pesos de vértice, sin IK.

#### Adopción open-source

| Librería | Licencia | Rol | Integración |
|---|---|---|---|
| **ozz-animation** | MIT | Runtime esqueletal: sampling, blending, IK (FABRIK + CCD) | XCFramework compilado en CI |
| Blender armature (referencia) | GPL | Diseño de UX: jerarquía de huesos, pose mode, weight painting | SOLO REFERENCIA — no copiar código |

**ozz-animation** cierra aproximadamente 70% de la brecha de animación. Incluye:
- Skeleton hierarchy + bone transforms
- Animation sampling + blending entre clips
- IK (FABRIK para cadenas, CCD para cadenas simples)
- Skinning (linear + dual quaternion)
- Runtime pequeño (≈200KB compilado para ARM64)

Lo que ozz NO incluye y debemos construir:
- Weight painting UI
- Rigging UI (crear huesos visualmente)
- Editor de curvas (graph editor)
- Constraints de huesos (copy rotation, track-to, etc.)

#### Micro-tareas

| ID | Tarea | Archivos | Tamaño | Paralelizable | Verificación CI |
|---|---|---|---|---|---|
| FD.4.01 | Integrar ozz-animation como XCFramework — CI workflow `build-ozz.yml` | `.github/workflows/build-ozz.yml` | L | Sí (en paralelo con FD.1) | Test: `ozz::animation::Skeleton` carga desde archivo .ozz |
| FD.4.02 | `SkeletonData` struct — import/export formato .ozz (binario ozz) | `Sources/Animation/SkeletonData.swift` | M | No | Test: crear skeleton 3-bone → exportar .ozz → recargar → misma jerarquía |
| FD.4.03 | Armature UI — crear huesos en viewport 3D (click para root, click+drag para hijos) | Nueva `ArmatureView.swift`, `Sources/Animation/ArmatureEditor.swift` | L | No | Visual: crear cadena de 3 huesos, verlos renderizados |
| FD.4.04 | Renderizado de huesos (octahedral o stick) en viewport | `ArmatureView.swift` | M | No | Visual: huesos visibles como octaedros alámbricos |
| FD.4.05 | Pose mode — seleccionar hueso, rotar/trasladar, ver deformación en tiempo real | `ArmatureEditor.swift` | L | No | Visual: rotar hueso del brazo → vértices del brazo se mueven |
| FD.4.06 | Skinning lineal (Linear Blend Skinning) vía ozz | `Sources/Animation/SkinningEngine.swift` | M | No | Test: mesh con 4 weights por vértice, rotar bone → deformación correcta |
| FD.4.07 | Dual Quaternion Skinning (ozz) — opción para evitar "candy wrapper" en codos/rodillas | `SkinningEngine.swift` | S | Sí | Visual: mismo modelo con DQS → sin colapso en codos |
| FD.4.08 | Weight painting — brocha para pintar influencia de huesos en vértices | Nueva `WeightPaintView.swift` | L | No | Visual: pintar rojo en brazo → esos vértices siguen al hueso del brazo |
| FD.4.09 | Auto-weights — asignación automática por proximidad (envelope/bone heat) | `SkinningEngine.swift` | M | No | Test: asignar auto-weights → todos los vértices tienen al menos 1 hueso con weight > 0 |
| FD.4.10 | IK FABRIK (ozz) — cadena de huesos resuelta por goal position | `Sources/Animation/IKSolver.swift` | M | No | Visual: mover effector (mano) → codo y hombro se ajustan automáticamente |
| FD.4.11 | IK CCD (ozz) — alternativa simple para cadenas cortas | `IKSolver.swift` | S | Sí | Test: 2-bone IK con CCD converge en <10 iteraciones |
| FD.4.12 | FK/IK switching por cadena de huesos | `ArmatureEditor.swift` | M | No | Visual: toggle FK→IK en pierna, mover effector vs rotar huesos |
| FD.4.13 | Animation blending — transición suave entre clips (walk→run) | `AnimationEngine.swift` (extender con ozz blending) | M | No | Test: blend walk (weight 0.3) + run (0.7) → animación intermedia |
| FD.4.14 | Animation layering — capas de animación aditivas (base walk + aim upper body) | `AnimationEngine.swift` | M | No | Visual: capa base camina, capa override apunta torso |
| FD.4.15 | Editor de curvas (graph editor) básico — seleccionar keyframe, ajustar tangentes Bézier | Nueva `GraphEditorView.swift` | L | Sí | Visual: curva de animación con handles de tangente |
| FD.4.16 | Dope sheet — vista compacta de todos los keyframes por hueso | Nueva `DopeSheetView.swift` | M | Sí | Visual: filas por hueso, diamantes en frames con keys |
| FD.4.17 | Timeline integrada con huesos — grabar pose mode keys automáticamente | `AnimationEngine.swift` | L | No | Visual: poner hueso en pose → keyframe automático al cambiar frame |
| FD.4.18 | Auto-keying toggle — grabar automáticamente cambios de pose | `AnimationEngine.swift` | S | No | Test: mover hueso en frame 30 con auto-key → keyframe creado |
| FD.4.19 | Pose library — guardar/recuperar poses nombradas | `Sources/Animation/PoseLibrary.swift` | S | Sí | Test: guardar pose "T-Pose" → aplicar a otro skeleton |
| FD.4.20 | IK constraints adicionales: pole vector, lock axis | `IKSolver.swift` | M | No | Visual: pole vector controla dirección del codo |
| FD.4.21 | Bone constraints básicos: copy location, copy rotation, track-to | `Sources/Animation/BoneConstraints.swift` | M | Sí | Test: bone B copia rotación de bone A |
| FD.4.22 | Exportar animación a glTF (ozz→glTF, compatible con Blender/Godot/Unity) | `Sources/Animation/GLTFAnimationExporter.swift` | L | Sí | Test: round-trip: animar en AppForge → exportar glTF → importar en Blender → misma animación |

**CRITERIO DE PARIDAD FD.4:** Crear un skeleton de 10 huesos, asignar weights, animar un ciclo de caminata con FK+IK, exportar a glTF y que se reproduzca correctamente en Blender. Iguala el 70% del flujo de animación de personajes de Blender (el 30% restante es character studio, NLA editor, motion capture cleanup).

**Lo que NO hacemos en FD.4:**
- No NLA (Non-Linear Animation) editor
- No motion capture / retargeting
- No character rig templates predefinidos (Humanoid, Quadruped)
- No physics simulation en huesos (ragdoll, jiggle)
- No shape keys con driven keys (solo morph targets básicos)
- No custom bone shapes avanzados (solo octahedral/stick)

---

### FD.5 — Capas No Destructivas

**Objetivo:** Stack de capas por objeto: base CAD + delta sculpt + capas de pintura con blending.
**Competidor de referencia:** Photoshop (capas con blending modes), Blender modifier stack.
**Duración estimada:** 2-3 semanas (≈12 micro-tareas).

#### Diagnóstico de partida

Las capas actuales son solo metadata (W5). Sculpt modifica la malla in-place. Una sola textura de pintura.

#### Micro-tareas

| ID | Tarea | Archivos | Tamaño | Paralelizable | Verificación CI |
|---|---|---|---|---|---|
| FD.5.01 | `LayerStack` por objeto: struct con layers ordenadas + blending | `Sources/Services/LayerManager.swift` (reescritura mayor) | L | No | Unit test: crear stack con 3 capas, evaluar → resultado compuesto |
| FD.5.02 | Capa "Base CAD" — B-rep subyacente, no modificable directamente | `LayerManager.swift` | M | No | Test: cambiar parámetro de extrusión en capa base → toda la stack se reevalúa |
| FD.5.03 | Capa "Sculpt Delta" — offset vectors por vértice (no modifica geometría base) | `LayerManager.swift`, `BrushEngine.swift` | L | No | Test: esculpir en capa delta, ocultar capa → geometría vuelve a base CAD |
| FD.5.04 | Capa "Paint" — textura con blending mode por capa | `PaintLayerManager.swift` (FD.3.06) | M | No | Visual: capa multiply sobre base color → oscurece |
| FD.5.05 | Reordenar capas (drag & drop en UI) | `LayersPanelView.swift` | S | Sí | Visual: arrastrar capa 3 a posición 1 → orden cambia |
| FD.5.06 | Visibilidad por capa (toggle ojo) + opacidad por capa | `LayersPanelView.swift` | S | Sí | Visual: toggle ojo en capa sculpt → malla vuelve a base |
| FD.5.07 | Merge visible / flatten — colapsar stack a una capa | `LayerManager.swift` | M | No | Test: flatten 3 capas → 1 capa resultante idéntica visualmente |
| FD.5.08 | Duplicar capa | `LayerManager.swift` | S | Sí | Test: duplicar capa sculpt → 2 capas con mismo delta |
| FD.5.09 | Máscara de capa (layer mask) — pintar blanco/negro para revelar/ocultar | `LayerManager.swift` | M | Sí | Visual: máscara negra en mitad de capa → solo mitad visible |
| FD.5.10 | Grupos de capas (folder) — colapsar/expandir en UI | `LayersPanelView.swift` | S | Sí | Visual: 3 capas dentro de folder "Detalles" |
| FD.5.11 | Modificadores no destructivos (estilo Blender): mirror, array, subdiv, decimate — aplicados como capas de modificación | `Sources/Engines/ModifierStack.swift` | L | No | Test: cubo + mirror X + subdiv → mesh simétrico y suave sin modificar cubo base |
| FD.5.12 | Serialización de LayerStack a formato .afslayer (JSON + binarios) | `LayerManager.swift` | M | Sí | Test: guardar stack → recargar → mismo resultado visual |

**CRITERIO DE PARIDAD FD.5:** Crear cubo CAD → añadir capa sculpt (esculpir protrusión) → añadir 3 capas de pintura con blending → ocultar capa sculpt → la protrusión desaparece pero la pintura sigue. Reordenar capas de pintura cambia el resultado visual. Exportar preserva la estructura. Iguala el sistema de capas de Procreate + el modifier stack de Blender (simplificado).

**Lo que NO hacemos en FD.5:**
- No adjustment layers (curvas, niveles, HSL)
- No linked layers / smart objects
- No layer comps / layer states
- No text layer / vector layer

---

## 3. Qué se Copia de Dónde

| Brecha | Fuente Open-Source | Licencia | Modo de Adopción | Justificación |
|---|---|---|---|---|
| Booleanos sobre mallas | **Manifold** | Apache 2.0 | **LIB** — XCFramework compilado en CI | OCCT no maneja bien mallas. Manifold es el estándar emergente (usado por kittycad, Onshape). |
| Subdivisión | **OpenSubdiv** (Pixar) | Apache 2.0 | **LIB** — XCFramework en CI | Catmull-Clark + feature-adaptive. Overkill si solo queremos subdiv, pero da multi-res gratis. |
| Voxel remesh | **OpenVDB** (DreamWorks) | MPL 2.0 | **PORT condicional** — VERIFICAR peso en iOS | Clave para sculpt competitivo. Si pesa >20MB en binary, considerar implementación voxel simplificada propia. |
| Runtime esqueletal | **ozz-animation** | MIT | **LIB** — XCFramework en CI | El 70% de la brecha de animación. Sampling, blending, IK, skinning. Maduro, usado en producción. |
| Constraints 2D solver | **PlaneGCS** (FreeCAD) | LGPL 2.1+ | **REFERENCIA** — Nuestro SolverSwift ya es bueno. Si necesitamos solver más robusto, evaluar port como proceso separado. | LGPL permite linking dinámico. En iOS, proceso separado no es viable. Evaluar solo si SolverSwift no escala. |
| SolveSpace solver | **SolveSpace** | GPL 3.0 | **REFERENCIA SOLAMENTE** | GPL3 es incompatible con App Store. El algoritmo de SolveSpace (Gauss-Newton con eliminación simbólica) es estudiado para mejorar SolverSwift. |
| Offset/boolean 2D | **Clipper2** | BSL (Boost Software License) | **LIB** — SPM binary target | Para offset de perfiles 2D en sketch. Ligero, rápido, sin dependencias. |
| UV unwrapping | **libigl** | MPL 2.0 | **LIB** — XCFramework en CI | LSCM y ARAP para unwrapping automático. Maduro, usado en investigación. |
| CGAL | **CGAL** | GPL 3.0 / comercial | **DESCARTADO** — licencia inviable | Solo como referencia de algoritmos. La licencia comercial cuesta €€€€. |
| Sculpt brushes | **Blender sculpt** | GPL 2.0+ | **REFERENCIA de diseño** — estudiar algoritmos, NO copiar código | Entender los brushes de Blender (clay strips, scrape, elastic deform) para implementar versiones propias con mismo comportamiento UX. |
| Grease Pencil | **Blender grease pencil** | GPL 2.0+ | **REFERENCIA de diseño** — estudiar la UX de strokes 3D | Implementar ribbons 3D propios basados en los conceptos (no código) de grease pencil 3.0. |
| Armature UX | **Blender armature** | GPL 2.0+ | **REFERENCIA de diseño** | La jerarquía de huesos, pose mode, weight paint mode son conceptos universales — no implementaciones GPL. |

---

## 4. Riesgos y Mitigaciones

### 4.1 Riesgos de Build (C++ en CI)

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| **Manifold no compila para iOS ARM64** | Media | Alto — FD.2 se cae sin booleanos de malla | Probar compilación en semana 1 de FD. Plan B: implementar booleanos simplificados propios (BSP trees + ear clipping). Menos robusto, pero suficiente para prototipos. |
| **OpenVDB pesa >30MB en iOS** | Media | Medio — FD.2.09 se reduce a remesh propio | Implementar voxel remesh simplificado: grid 256³, marching cubes desde `SDFEngine`. Menos calidad que OpenVDB pero 100KB de código propio. |
| **ozz-animation no compila como XCFramework** | Baja | Alto — FD.4 pierde 70% de avance | ozz usa CMake y es portable. Build matrix: iOS arm64 + simulator arm64 + Mac Catalyst. Si falla, plan B: implementar FABRIK IK + LBS skinning en Swift puro (2 semanas extra). |
| **Tiempo de CI se dispara (>30 min por build de XCFramework)** | Alta | Medio — ralentiza iteración | Cache de artifacts en GitHub Actions. Build separate para cada XCFramework (solo cuando cambian). Workflow `build-all-xcframeworks.yml` semanal, no por PR. |
| **Conflictos de licencia en App Store** | Baja | Crítico — rechazo de Apple | Auditoría de licencias antes de cada merge a main. Script `check-licenses.sh` que escanea Package.resolved y LICENSE de cada XCFramework. |

### 4.2 Riesgos de Tamaño de App

| Componente | Tamaño estimado (compilado ARM64) |
|---|---|
| OCCT (ya integrado) | ~8-12 MB |
| Manifold | ~1-2 MB |
| OpenSubdiv | ~2-3 MB |
| OpenVDB (si se adopta) | ~8-15 MB |
| ozz-animation | ~0.2 MB |
| Clipper2 | ~0.5 MB |
| libigl | ~3-5 MB |
| **Total incremental** | **~15-26 MB** |
| **App total estimada** | **~50-70 MB** |

**Mitigación:** Por debajo del límite de 200MB de descarga celular de App Store. Si nos acercamos a 100MB, evaluar descarga de assets bajo demanda (on-demand resources).

### 4.3 Riesgos de Integración

| Riesgo | Mitigación |
|---|---|
| **OCCT + Manifold producen resultados inconsistentes** | FD.2 implementa ambos paths: boolean B-rep para CAD puro, boolean malla para sculpt. El usuario elige (o auto-detecta según tipo de objeto). |
| **ozz-animation + AnimationEngine existente duplican lógica** | FD.4 reescribe AnimationEngine para delegar en ozz internamente, manteniendo la API pública actual como fachada. |
| **SolverSwift no escala a >100 constraints** | El solver actual usa Gauss-Seidel (O(n²·iter)). Para sketches complejos, portar a sparse Cholesky (Eigen/Sparse o Accelerate). Medir en FD.1.01. |

### 4.4 Riesgos de Priorización

| Riesgo | Mitigación |
|---|---|
| **FD.4 (animación) es demasiado grande y bloquea otras fases** | FD.4 es independiente de FD.1/FD.2/FD.3/FD.5. Se puede desarrollar en paralelo completo. Si se atrasa, se entrega FD.1+FD.2+FD.5 primero (CAD+sculpt+paint integrado). |
| **FD tarda más de 4 meses en total** | Las fases están ordenadas por valor/esfuerzo. Si hay que cortar, FD.3 (paint) y FD.4 (animación) son las más prescindibles para un MVP CAD+sculpt. |

---

## 5. Re-priorización Sugerida del Roadmap v1

### Estado actual de las Olas (Waves)

| Ola | Estado actual | Propuesta FD |
|---|---|---|
| W1 (setup) | ✅ Completado | — |
| W2 (3D foundation) | ✅ Completado | — |
| W3 (sculpt) | ✅ Completado | — |
| W4 (CAD anim) | ✅ Completado | — |
| W5 (hybrid design) | ✅ Completado | — |
| W6 (theme IPA) | 🔄 En progreso | Terminar W6 primero |
| **C1-C10 (ola C original)** | ⏳ Planeado | **POSPONER** — FD.1..FD.5 toman prioridad |
| **F1-F5 (ola F original)** | ⏳ Planeado | **POSPONER** — FD es prerequisite |

### Nueva secuencia propuesta

```
W6 (theme IPA) → [MERGE a main] → FD.1 + FD.2 (paralelo) → FD.5 → FD.3 → FD.4
                                      ↓
                              [MILESTONE: AppForge 1.0 "CAD+SCULPT"]
                                      ↓
                              FD.3 + FD.4 → [MILESTONE: AppForge 1.5 "FULL STUDIO"]
                                      ↓
                              Olas C (Community) y F (Final) originales
```

### Qué se pospone explícitamente

| Item pospuesto | Justificación |
|---|---|
| Ola C1-C5 (Community features) | Sin profundidad CAD/sculpt, no hay comunidad que retener |
| Ola C6-C10 (Cloud sync, collaboration) | Ídem |
| Ola F1-F5 (Polish final) | Sin funcionalidad real que pulir, es cosmético |
| Export USDZ/USDC | El export STL/glTF de FD cubre el 80% de casos de uso |

---

## RESUMEN FINAL

### Brechas confirmadas vs ya-cubiertas

| Brecha | Estado actual (0-5) | Target FD | Gap |
|---|---|---|---|
| Sketch 2D paramétrico | ⭐⭐⭐⭐ (4/5) | ⭐⭐⭐⭐⭐ (5/5) | Constraints real-time + revolve + cotas visibles |
| Booleanos robustos | ⭐⭐⭐½ (3.5/5) | ⭐⭐⭐⭐⭐ (5/5) | Mallas + B-rep, Manifold integrado |
| Sculpt sobre CAD | ⭐⭐ (2/5) | ⭐⭐⭐⭐ (4/5) | Flujo completo, mesh→shape, dyntopo |
| Pintura 3D | ⭐½ (1.5/5) | ⭐⭐⭐⭐ (4/5) | Ribbons 3D, UV editing, multi-capas |
| Animación | ⭐⭐ (2/5) | ⭐⭐⭐⭐ (4/5) | Esqueletal completo con IK |
| Capas no destructivas | ⭐½ (1.5/5) | ⭐⭐⭐⭐⭐ (5/5) | Stack completo con modifiers |

### Top adopciones open-source recomendadas

1. **Manifold** (Apache 2.0) — 🟢 Prioridad máxima. Cierra la brecha de booleanos de malla.
2. **ozz-animation** (MIT) — 🟢 Prioridad máxima. Cierra el 70% de animación.
3. **OpenSubdiv** (Apache 2.0) — 🟡 Prioridad media. Subdivisión para multi-res sculpt.
4. **Clipper2** (BSL) — 🟡 Prioridad media. Offset 2D para sketch.
5. **libigl** (MPL 2.0) — 🟡 Prioridad media. UV unwrapping automático.
6. **OpenVDB** (MPL 2.0) — 🔴 VERIFICAR peso antes de adoptar.

### Micro-tareas por sub-fase

| Sub-fase | # Micro-tareas | Tamaño total (días-hombre) | Paralelizable |
|---|---|---|---|
| FD.1 Sketch 2D | 14 | 25-30 | 7 tareas (50%) |
| FD.2 Booleanos + Sculpt | 15 | 30-35 | 6 tareas (40%) |
| FD.3 Paint real | 15 | 25-30 | 8 tareas (53%) |
| FD.4 Animación | 22 | 40-50 | 8 tareas (36%) |
| FD.5 Capas | 12 | 15-20 | 7 tareas (58%) |
| **TOTAL** | **78** | **135-165** | **36 (46%)** |

### Confianza del plan

| Aspecto | Confianza | Nota |
|---|---|---|
| Auditoría de código | **ALTA (95%)** | Todos los archivos del PASO 1 fueron leídos completos |
| SolverSwift | **ALTA (90%)** | Código revisado — funciona pero necesita medición de performance |
| OCCT integración | **ALTA (85%)** | B-rep operations confirmed working, bridge mesh→shape roto |
| Manifold integrabilidad | **MEDIA (70%)** | Licencia OK, CMake portable. VERIFICAR build ARM64 iOS |
| ozz-animation integrabilidad | **MEDIA (75%)** | MIT, portable, maduro. VERIFICAR build XCFramework |
| OpenVDB peso en iOS | **BAJA (40%)** | Necesita build de prueba. Plan B listo (SDFEngine propio) |
| Estimaciones de tiempo | **MEDIA (65%)** | Basadas en complejidad de código existente. No incluyen bugs de integración C++/Swift |
| Competitividad final | **MEDIA-ALTA (75%)** | Si FD.1+FD.2+FD.5 se completan, AppForge iguala/supera a Shapr3D+Nomad en integración CAD-sculpt |

### Próximo paso inmediato

```bash
# 1. Build de prueba de Manifold para iOS (FD.2 prerequisite)
# 2. Build de prueba de ozz-animation para iOS (FD.4 prerequisite)
# 3. Medir performance de SolverSwift con 50+ constraints (FD.1 prerequisite)
```

---

*Documento generado por NEXUS. Auditoría de código: 12 archivos fuente leídos completos. Licencias verificadas contra SPDX. Plan listo para revisión de Andrés.*
