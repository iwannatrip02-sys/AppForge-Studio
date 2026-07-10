# WORKSPACES + MANUFACTURE (slicer integrado) — arquitectura y timing
> 2026-07-10 · El esqueleto de la plataforma todo-en-uno: cómo se conectan los
> workspaces, la arquitectura del slicer FDM+resina integrado, qué se copia de
> quién (y qué NO se puede copiar por licencias), y cuándo arranca cada pieza
> relativo a las fases CAD/perf. Complementa INGENIERIA_INVERSA_CAD.md y
> ARQUITECTURA_RENDIMIENTO.md.

---

## 0. LA TESIS

Todos los slicers parten de: modelo → exportar STL → abrir slicer → preparar →
slice → exportar gcode. Nosotros eliminamos el cambio de aplicación:

```
Modelar → Esculpir → tap "Manufacture" → mismo documento, otro workspace
```

Sin exportar, sin importar, sin perder materiales/nombres/jerarquía. Nadie
tiene esto en tablet. Es la misma tesis anti-app-switching de la visión
general aplicada a fabricación.

## 1. ⚠️ LICENCIAS PRIMERO (lo que "copiar y mejorar" significa legalmente)

| Slicer | Licencia | ¿Podemos usar su código? |
|---|---|---|
| OrcaSlicer / PrusaSlicer / libslic3r | **AGPL-3.0** | **NO** en app comercial cerrada — AGPL obliga a liberar TODO nuestro código. Copiamos UX, mecánicas y defaults; CERO código |
| CuraEngine | LGPL-3.0 | Legalmente gris en App Store (linking estático + anti-tivoization de v3). Evitar |
| Lychee | Propietario | Nada de código; UX como referencia |
| Materialise Magics | Propietario | Solo estudiar flujos |
| UVtools (formatos resina) | MIT | ✓ SÍ — referencia de formatos .ctb/.cbddlp/.pwmx/.goo documentados |
| Clipper2 (booleanas 2D/offsets) | **BSL-1.0** | ✓ SÍ — es EL building block de perímetros/infill que usan todos |

**Conclusión estratégica**: motor de slicing PROPIO en Swift/C++/Metal, con
Clipper2 como única dependencia de geometría 2D. Es más trabajo, pero: (a) es
la única vía legal para app de pago, (b) nos deja explotar Metal (nadie slicea
en GPU en tablet), (c) el motor propio es activo vendible/licenciable después.

## 2. ARQUITECTURA DE WORKSPACES (el esqueleto)

### 2.1 Lo que ya existe (no partir de cero)
- `Features/` ya tiene 6 workspaces de facto: CADMode, SculptMode, PaintMode,
  AnimationMode, ExportMode, HybridMode.
- **Deuda a pagar antes de sumar otro**: hay 3 enums de modo duplicados
  (`AppState.AppMode`, `CanvasViewModel.AppMode`, `WorkspaceToolViewModel.ActiveMode`)
  → unificar en UN `Workspace` canónico. (Tarea F-WS-0, pequeña.)

### 2.2 El contrato de Workspace
```swift
enum Workspace: String, CaseIterable {
    case cad, sculpt, paint, animation, render, manufacture  // export se absorbe
}

protocol WorkspaceModule {
    var workspace: Workspace { get }
    // El documento es COMPARTIDO; el workspace solo aporta vista + herramientas
    func makeView(document: SceneDocument) -> AnyView
    func willEnter(from: Workspace?)   // preparar (p.ej. Manufacture: teselar fino)
    func willLeave(to: Workspace?)     // liberar recursos pesados (contratos perf §C4)
}
```

### 2.3 SceneDocument: el documento único (la clave de TODO)
Hoy `Scene3D` + `ProjectPersistenceService` (.appforge) ya son el embrión.
Regla: **cada workspace lee/escribe el MISMO documento**; nada de "exportar
al siguiente modo".

```
SceneDocument (.appforge)
├── models[]           ← B-rep (CAD) + malla (sculpt) + materiales (paint)
├── cadHistory (DAG)   ← paramétrico
├── animation tracks
├── config (unidades, grid)
└── manufacture        ← NUEVO subdocumento:
    ├── printers[]     (perfiles de impresora: FDM/resina/otra)
    ├── placements[]   (qué modelos van en la cama, transform, por-objeto)
    ├── settings       (perfil activo + overrides por objeto)
    └── jobs[]         (slices generados: gcode/ctb + metadatos + preview)
```

El punto fino: Manufacture consume la MALLA teselada del B-rep con deflection
FINA (calidad de fabricación ≠ calidad de viewport — el GeometryActor de
ARQUITECTURA_RENDIMIENTO §2 sirve ambas con el mismo API, distinto parámetro).
Si el usuario edita el CAD después de slicear → el job queda `stale` (el DAG
ya sabe qué cambió) y se re-slicea SOLO lo afectado.

## 3. WORKSPACE MANUFACTURE — qué copiamos de quién

### 3.1 De OrcaSlicer (FDM) — el benchmark de features
Copiar (UX/mecánica, no código): árbol de configuración por capas
impresora/filamento/proceso · calibraciones integradas (flow, PA, temp towers)
· pintado de soportes/costuras en el modelo · modificadores por objeto y por
región (modifier meshes) · preview por feature-type con leyenda · plancha
múltiple (plates). **NO copiar**: sus 400 parámetros expuestos de golpe —
nuestro modo default es "3 sliders" (calidad/velocidad/resistencia) con
progressive disclosure hacia el árbol completo.

### 3.2 De Lychee (resina) — el benchmark de UX
Soportes automáticos con edición manual fina · detección de islas POR CAPA ·
huecado + drenajes · orientación inteligente (minimiza soportes/succión) ·
vista de capas con zonas de riesgo. Aquí está nuestra ventaja Metal: la
detección de islas y el preview de capas son render-to-texture — lo hacemos
EN VIVO mientras orientas la pieza (nadie lo hace en vivo).

### 3.3 De Magics (industrial) — los flujos
Reparación de mallas robusta (ya tenemos pre-export validation ✓ — crecerla)
· nesting automático de cama · reportes de trabajo. Fase tardía.

### 3.4 "Otras impresoras menos convencionales" (julio 2026)
La arquitectura debe ser N-tecnologías desde el día 1: el `PrinterProfile`
declara su `kinematics` (gcode cartesiano/delta/belt) o `layerImageFormat`
(resina) o `toolpathDialect` (láser/CNC/paste). FDM y resina son los dos
primeros `SlicerBackend`; SLS/DLP-metal/bioprinting entran como backends
nuevos sin tocar el documento ni la UI de placement.

## 4. EL MOTOR (SwiftSlice — nuestro core propio)

### 4.1 Resina PRIMERO (decisión de secuencia, y por qué)
El slicer de resina es geométricamente más simple y juega a nuestras fuerzas:
1. Slicing = intersección plano-malla por capa → **ya tenemos esa matemática
   en SectionPlaneModule** (intersección triángulo-plano ✓).
2. Cada capa es una IMAGEN (bitmap 4K-12K) → render-to-texture Metal, nuestro
   terreno. GPU slicing real: todas las capas de una pieza de 10cm en
   segundos.
3. Salida = formatos de archivo documentados (via UVtools/MIT): .ctb, .goo,
   .pwmx + el genérico .zip de imágenes. Sin física de extrusión.
4. Soportes de resina (árboles) comparten código con… los soportes de árbol
   FDM después.
FDM requiere además: perímetros/offsets (Clipper2), infill, retracción,
aceleraciones, flavors de gcode, presión advance — motor 2.

### 4.2 Módulos del motor (ambas tecnologías)
```
SwiftSlice/
├── MeshPrep      (reparación, orientación, huecado, drenajes)   ← compartido
├── Supports      (islas, árboles, pintado manual)               ← compartido
├── SliceCore     (plano-malla → polígonos por capa; GPU path)   ← compartido
├── ResinBackend  (AA/blur de capa, exposiciones, .ctb/.goo)
├── FDMBackend    (Clipper2: perímetros/infill/brim; gcode)
└── Preview       (scrubber de capas, por-feature, tiempos/costo)
```

## 5. TIMING — cuándo arranca qué (integrado al roadmap real)

Regla vigente: **cero botones falsos** — el workspace Manufacture NO aparece
en la UI hasta que su primer flujo funcione de punta a punta.

| Fase | Qué | Cuándo / paralelo a qué |
|---|---|---|
| F-WS-0 | Unificar los 3 enums de modo en `Workspace` + protocolo `WorkspaceModule` (refactor interno, sin UI nueva) | Con F-CAD-3 (es limpieza que igual necesita el chrome nuevo) |
| F-MFG-1 | `manufacture` subdocumento en .appforge + `PrinterProfile` N-tecnologías (solo modelo de datos + tests) | Con F-CAD-3, bajo riesgo, sin UI |
| F-MFG-2 | SliceCore GPU (reusa SectionPlane) + preview de capas como herramienta de ANÁLISIS dentro del CAD (útil ya: inspeccionar el cohete capa por capa) | Tras perf-1 (GeometryActor) — el slicing corre sobre esa infraestructura |
| F-MFG-3 | ResinBackend completo: orientación+huecado+soportes+islas+export .ctb/.goo → **primer workspace Manufacture visible** | Tras F-CAD-4; el CAD ya verificado en device |
| F-MFG-4 | FDMBackend (Clipper2, perfiles, gcode, calibraciones) | Tras F-MFG-3; es el módulo más largo |
| F-MFG-5 | Nesting, plates múltiples, reportes, backends exóticos | Post-lanzamiento, según demanda |

**Por qué este orden**: F-MFG-2 da valor ANTES de ser slicer (sección por capas
como herramienta de análisis CAD = feature que Shapr3D no tiene), valida el
core GPU con usuarios reales, y cuando F-MFG-3 llega, el 60% del riesgo
técnico ya está quemado.

## 6. LO QUE ESTO LE HACE AL NEGOCIO

Manufacture es EL candidato natural a tier Pro (la visión freemium): modelar
gratis, fabricar con Pro. Y el motor propio (SwiftSlice sin AGPL) queda como
activo licenciable independiente. Actualizar la matriz de INGENIERIA_INVERSA
§4 cuando F-MFG-3 aterrice: ni Shapr3D ni Fusion-iPad tienen NADA de esto.
