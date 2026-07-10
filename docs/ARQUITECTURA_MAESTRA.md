# ARQUITECTURA MAESTRA — AppForge Studio, plataforma 3D completa
> 2026-07-10 · El esqueleto de TODO: orden de entregas, arquitectura por
> workspace, contratos de integración entre ellos, y el sistema de
> automatizaciones post-lanzamiento. Este doc es el índice maestro; cada área
> tiene su doc de detalle:
> - CAD: `INGENIERIA_INVERSA_CAD.md` (catálogo Shapr3D+Fusion, fases F-CAD-1..6)
> - Rendimiento: `ARQUITECTURA_RENDIMIENTO.md` (contratos C1-C5, perf-0..4)
> - Workspaces+Slicer: `WORKSPACES_Y_MANUFACTURE.md` (SwiftSlice, F-MFG-1..5)
>
> Meta final: "casi cualquier cosa de modelado 3D" — flujo 0 → render /
> impresión / producto final sin salir de la app, con calidad de producción
> para las empresas más grandes del mundo.

---

## 0. ORDEN DE ENTREGAS (el mapa de la guerra)

```
ENTREGA 1  ─ CAD ingenieril profesional + RENDER REAL con catálogo de materiales
ENTREGA 2  ─ Sculpt nivel Nomad/ZBrush + Slicer multiplataforma máximo nivel
TRANSVERSAL─ velocidad, potencia, integración fiable de TODO en TODO momento
ENTREGA 3  ─ Animación + simulaciones ingenieriles como parte del proceso
POST       ─ sistema de automatizaciones que mantiene el producto solo
```

Regla de cierre de cada entrega: **verificada en device real** (iPad Pro M1,
device loop pymobiledevice3), CI verde, benchmark de rendimiento sin
regresión, cero botones falsos.

## 1. EL ESQUELETO COMÚN (la plataforma debajo de los workspaces)

Todo workspace se monta sobre 5 primitivas compartidas. Nada se construye
dos veces:

| Primitiva | Qué es | Estado |
|---|---|---|
| **SceneDocument** (.appforge) | EL documento único: models (B-rep+malla+materiales), cadHistory (DAG), animation, manufacture, config. Cada workspace lee/escribe aquí — jamás "exportar al siguiente modo" | ✓ embrión (Scene3D + ProjectPersistenceService) |
| **Workspace protocol** | `makeView(document:) / willEnter / willLeave` — entrar/salir libera recursos (contrato C4). Un enum canónico (unificar los 3 duplicados: F-WS-0) | ✗ F-WS-0 |
| **GeometryActor** | TODA geometría pesada (OCCT, remesh, slicing, bake) corre aquí: fuera del main, cancelable por generación, con progreso | ✗ perf-1 — LA pieza estructural |
| **RenderCore (Metal)** | Un solo pipeline PBR+IBL que sirve a todos: viewport CAD, matcaps de sculpt, preview de slicer y render final (mismo material = mismo look en todos lados) | ✓ parcial (SatinRenderer, PBRMaterial, IBLPipeline) |
| **Instrumentación** | FPS HUD, os_signpost, hang detector, MetricKit, benchmark-cohete en CI | ✗ perf-0 |

## 2. ENTREGA 1a — CAD INGENIERIL (en curso)

Detalle completo en `INGENIERIA_INVERSA_CAD.md`. Estado: F-CAD-2 con CI verde
(2026-07-10, beta-2026-07-10b) — **pendiente verificación en device**. Siguen:
F-CAD-3 (paridad de sensación: teclado numérico flotante, badges de
constraints, variables/expresiones, trim/offset/mirror) → F-CAD-4 (superset
Fusion) → F-CAD-5 (2D Drawings).

"Nivel física profesional" incluye desde ya (base de la simulación futura):
- Propiedades de masa reales: volumen, masa por material, centro de gravedad,
  momentos de inercia (OCCT `volumeProperties` — barato, F-CAD-3).
- Densidades en el catálogo de materiales (§3): el material visual Y físico
  son EL MISMO asset.
- Interferencias de ensamble (ya hay API) + tolerancias/ajustes ISO en cotas.

## 3. ENTREGA 1b — RENDER REAL + CATÁLOGO DE MATERIALES

Benchmark: Visualization de Shapr3D (superar), KeyShot/Blender-Cycles
(referencia de calidad, no de alcance v1).

### 3.1 Arquitectura de render (dos niveles, un material)
- **Nivel A — viewport (siempre)**: PBR+IBL tiempo real ✓ + sombras de
  contacto (AO), reflexiones screen-space, anti-aliasing temporal. 60-120fps.
- **Nivel B — render final (Render workspace)**: **path tracer progresivo en
  Metal** (Metal ray tracing; hardware RT en M3+, compute en M1/M2) con
  denoiser (MPSSVGF / MetalFX). Progresivo = la imagen refina en vivo, el
  usuario decide cuándo está lista — nunca "esperar el render" a ciegas.
  Salida: PNG/EXR, turntables MP4.
- **Un solo modelo de material** alimenta ambos niveles y también al slicer
  (densidad para masa, color para preview multicolor).

### 3.2 Catálogo de materiales (el "decente" de la visión)
```
Material (asset único)
├── PBR: baseColor/metallic/roughness/normal/clearcoat/transmission/IOR/emisión
├── Físico: densidad, nombre de norma (AISI 304, PLA, ABS, resina X)
└── Fabricación: compatibilidad slicer (temp/exposición sugerida)
```
- Catálogo v1: ~80 materiales curados por categoría (metales, plásticos,
  vidrio, madera, cerámica, goma, resinas/filamentos de impresión).
- Asignación drag→cuerpo y drag→CARA (Shapr3D solo por cuerpo en algunos
  flujos — superarlo); editor de material custom (ya existe embrión:
  MaterialEditorView, MaterialPresets ✓).
- Entornos: ~12 HDRIs con rotación/intensidad/blur; fondo transparente para
  compositing.
- Formatos: texturas KTX2/BasisU (streaming, RAM contenida — contrato C5).

## 4. ENTREGA 2a — SCULPT NIVEL NOMAD/ZBRUSH

Ya existe base real: SculptEngine + brushes + deformers (grab/inflate/crease/
flatten/bend/morph ✓) + DynamicTopologyEngine embrión. Lo que falta para
"nivel Nomad" (ingeniería inversa detallada pendiente como doc propio cuando
arranque la entrega 2 — mismo método que el CAD):

| Capacidad | Referencia | Nota arquitectura |
|---|---|---|
| Dyntopo real (refinar bajo el pincel) | Nomad | half-edge + cola de edición local en GPU; NUNCA re-teselar todo (contrato C2) |
| Multiresolución (subdivisión con niveles) | ZBrush | pirámide de detalle, esculpir en nivel N, propagar |
| Remesh voxel | Nomad/ZBrush | SDF grid + marching cubes en Metal compute — comparte infraestructura con el kernel híbrido de booleanas (ARQUITECTURA_RENDIMIENTO §2.4 fase C: MISMA inversión, dos usos) |
| Máscaras + polygroups + simetría radial | ambos | máscara = atributo por vértice, pinta con los mismos brushes |
| Vertex paint / texturas | Nomad | ya existe PaintMode ✓ — unificar con materiales §3.2 |
| Stencils/alphas de pincel | ZBrush | biblioteca + import de imagen |
| **Puente sculpt→CAD** | NADIE lo tiene | remesh → reconocimiento de primitivas/superficies → BREP editable. Investigación bandera de la plataforma (post-E2) |

## 5. ENTREGA 2b — SLICER MULTIPLATAFORMA MÁXIMO NIVEL

Esqueleto completo en `WORKSPACES_Y_MANUFACTURE.md` (SwiftSlice: resina
primero por GPU, FDM después con Clipper2, CERO código AGPL). La ambición
"todas las impresoras y todos los parámetros" se implementa como:
- `PrinterProfile` declarativo N-tecnologías (FDM cartesiano/delta/belt,
  resina MSLA/DLP, y backends técnicos: SLS, metal binder-jet, paste/bio,
  láser/plasma como toolpath dialects).
- Base de datos de perfiles COMUNITARIA-COMPATIBLE: importar perfiles de
  impresoras existentes (los .json/.ini de perfiles NO son código — se pueden
  leer los formatos y convertir).
- Progressive disclosure: 3 sliders por defecto → árbol completo de parámetros
  (todos los de Orca como techo de referencia) para el usuario técnico.

## 6. TRANSVERSAL — INTEGRACIÓN FIABLE (el pegamento que nadie ve)

Los contratos entre workspaces son API versionadas del SceneDocument, no
casualidades:

| Frontera | Contrato | Riesgo |
|---|---|---|
| CAD → Sculpt | B-rep → malla adaptativa (el usuario elige densidad); la referencia al nodo CAD se conserva (volver al CAD no destruye el sculpt: capas) | medio |
| Sculpt → CAD | malla como cuerpo de referencia (medible, seccionable, boolean con B-rep vía malla) — reconocimiento a BREP es investigación posterior | alto |
| CAD/Sculpt → Render | mismo material asset, mismo RenderCore — cero conversión | bajo |
| CAD/Sculpt → Manufacture | malla de fabricación (deflection fina) + reparación automática; jobs marcados stale por el DAG al editar upstream | medio |
| Todo → Export | STEP/STL/OBJ/3MF/USDZ ✓ + gcode/ctb (E2) + EXR/MP4 (E1b) | bajo |
| Animación → todo (E3) | tracks referencian IDs del documento; transformar ≠ editar geometría | medio |

Regla: cada frontera tiene TESTS de round-trip en CI (crear en A, usar en B,
verificar invariantes) — la fiabilidad de integración se prueba, no se supone.

## 7. ENTREGA 3 — ANIMACIÓN + SIMULACIÓN INGENIERIL

- **Animación**: ya existe AnimationEngine embrión (keyframes pos/rot/scale ✓).
  Nivel entrega: timeline por cuerpo, cámaras animadas, turntables, exploded
  views animadas (ensambles: los mates definen los ejes de la animación —
  drive joints como Fusion), export MP4/GIF.
- **Simulación de uso ingenieril** (plasmada como parte del proceso, no un
  módulo aparte): sobre el mismo documento y los mismos materiales físicos:
  1. Nivel 1 (con E1): masa/CG/inercia, interferencias, sección analítica.
  2. Nivel 2: cinemática de mecanismos (los mates + drive joints = simulación
     de movimiento con detección de colisiones).
  3. Nivel 3: FEA estático lineal (tet-mesh desde el B-rep + solver propio o
     biblioteca con licencia compatible — CalculiX es GPL: NO embebible;
     evaluar solver propio simple o servicio cloud opcional).
  Presentación: mapa de tensiones/desplazamientos sobre el modelo en el
  viewport, como una capa más — no una app aparte.

## 8. POST-LANZAMIENTO — EL SISTEMA DE AUTOMATIZACIONES

La startup unipersonal escala por software, no por horas humanas. Piezas
(muchas ya sembradas hoy):

| Pieza | Qué automatiza | Base existente |
|---|---|---|
| CI/CD honesto | build+tests+benchmark+IPA en cada push; release firmado automático (cuando haya cuenta de developer: TestFlight/App Store por Fastlane en CI) | ✓ build.yml verde hoy |
| Benchmark del cohete | regresiones de rendimiento bloquean merge | perf-0 |
| Telemetría de campo | MetricKit: hangs, crashes, memoria, arranque — dashboard automático | perf-0 |
| Triage automático | crash/hang → issue con stack simbolizado → agente propone fix → PR → CI → review humana de 1 clic | post-E1 |
| Soporte por agentes | docs generadas desde los specs + agente de soporte con acceso a telemetría del usuario (opt-in) | post-lanzamiento |
| Feature analytics | qué herramientas se usan (opt-in, anónimo) → prioriza el roadmap con datos | post-E1 |
| Canary | releases por anillos (beta → 10% → 100%) con rollback automático por métricas | post-lanzamiento |

## 9. GOBERNANZA (las reglas que no se negocian, ya vigentes)

1. **Cero botones falsos** — nada visible sin efecto real.
2. **Done = CI verde + verificado en device.**
3. **Medir primero** — ninguna optimización sin número antes/después.
4. **Main thread limpio** — contratos C1-C5 de rendimiento.
5. **Licencias limpias** — AGPL/GPL jamás embebido; inventario en cada
   dependencia nueva (hoy: Satin MIT, OCCT LGPL-2.1 revisar linking pre-App
   Store, Clipper2 BSL futuro).
6. **Un solo documento** — si una feature necesita "exportar" entre
   workspaces, está mal diseñada.
7. **Cada frontera con tests de round-trip en CI.**
