# SUPREMACÍA HOLÍSTICA — AppForge > (Shapr3D + Onshape + Fusion360)
> 2026-07-14 · Doc conector: por qué la SUMA nos hace superiores, cómo el sustrato
> de interacción es la palanca que une TODO, y el plan de olas (con contratos) para
> atacar todo el rango sin construir un castillo de naipes.
> Índices de detalle ya existentes: `ARQUITECTURA_MAESTRA.md` (plataforma/entregas),
> `INGENIERIA_INVERSA_CAD.md` (catálogo competidores), `docs/specs/2026-07-13-ola-sustrato-lane-b.md`
> (oleada actual + Waves), `AUDITORIA_DEVICE_SUBSTRATO_2026-07-13.md` (diagnóstico).

## 0. La tesis: por qué la SUMA gana

Cada gigante tiene UN foso; ninguno los tiene todos. Ahí está el hueco.

| Producto | Su foso real | Su techo (lo que NO tiene) |
|---|---|---|
| **Shapr3D** | Modelado directo táctil ("la geometría es el UI"), iPad-nativo, rápido | Sin ensambles paramétricos, sin variables profundas, sin CAM/sim, sin sculpt, timeline lineal, $299/año |
| **Onshape** | Paramétrico en la nube + ensambles + versionado/colaboración multiusuario real | No es táctil-nativo (es CAD de escritorio en navegador), sin sculpt/orgánico, sin render de alto nivel integrado |
| **Fusion360** | Superset: paramétrico + CAM + simulación + sheet metal + generative + Form(T-spline) | Pesado, curva de escritorio, en iPad solo es visor; no táctil real |

**Nuestra unión (lo que ninguno combina):** UN solo documento (`SceneDocument`) + UN
solo sustrato de interacción táctil que sirve, sin "exportar entre modos":
- **CAD directo** con la sensación de Shapr3D (esta oleada), **+ paramétrico DAG**
  (más general que el timeline lineal de Shapr3D) al nivel de Onshape/Fusion,
- **+ ensambles con mates/joints** (motor ya existe — foso de Onshape/Fusion que Shapr3D no tiene),
- **+ escultura orgánica** nivel Nomad (foso que NINGÚN CAD tiene),
- **+ pintura/materiales + render PBR/path-tracer**,
- **+ manufactura (slicer) y simulación** como capas del mismo documento,
- diferenciadores que nadie más tiene juntos: **cotas 3D en viewport**, **puente
  sculpt↔CAD**, **precio $0→freemium**, **extensibilidad (scripts/plugins)**.

Superarlos "juntos" = entregar cada foso Y las uniones que ellos no pueden hacer
porque arrastran arquitecturas de escritorio o de un solo dominio.

## 1. El sustrato unificado = la palanca que conecta todo

La regla sagrada (`DISENO_INTERFAZ.md`): **tocar geometría = actuar; tocar vacío = orbitar.**
El nudo que arreglamos esta sesión (selección→gizmo→transform→acción contextual como
UNA mecánica) no es "un arreglo de CAD": es el **sustrato del que cuelga TODO**:
- El mismo `TransformTarget`/resolver sirve a mover cuerpos, empujar caras, editar
  sub-objetos, posicionar ensambles y (mañana) transformar huesos de animación.
- El mismo contrato `SketchController` alimenta extrude/corte, y mañana rib/emboss/text.
- El mismo picking (`ScenePicking`) sirve a CAD, medición, sculpt y selección de material por cara.
- Sobre los **5 primitivos compartidos** (`ARQUITECTURA_MAESTRA §1`): SceneDocument,
  Workspace protocol, GeometryActor, RenderCore, Instrumentación. El sustrato de
  interacción es el 6º primitivo implícito: la **gramática de gestos única**.

Por eso esta oleada es la palanca: bien hecha, cada workspace futuro hereda la sensación.

## 2. Estado real hoy (verificado esta sesión)

**✅ Hecho (sin verificar en device aún):** contrato sketch→prisma real, no-op muerto,
resolver `TransformTarget`, gizmo anclado a sub-objeto, cara→push/pull real, gizmo
sin reinicio, overlays sin fantasmas, `performExtrusion` con Añadir/Cortar, sheet
Export en CAD, panel de patrón (lineal+circular 360°), dedo-dibuja, tests.

**🟡 Parcial (sensación por clavar):** numérico NO cableado al gizmo (existe `NumericField`
pero no en mover/rotar/escalar); sin snap por incrementos en el transform; sin toggle
local/global; "Guías" fueron retiradas.

**🔴 Falta/duro:** escalar arista/lazo y mover vértice (hoy caen al cuerpo); arrastre-de-cara
en vivo; estética de líneas oscuras nítidas; ángulo de patrón circular (<360°).

## 3. Plan de olas — atacar TODO con propiedad disjunta + contratos

Regla anti-castillo-de-naipes: **cada ola cierra con CI verde + verificación en device**
antes de apilar la siguiente sobre ella. Las olas de una misma tanda corren en paralelo
SOLO con archivos disjuntos + contrato firmado.

### Tanda A — cerrar la sensación + los duros de esta oleada (fleet 3 agentes)
- **G1 · Sensación del transform** — dueño: `CADModeView.swift`, `MetalView.swift`, gizmo.
  Numérico en gizmo (mover/rotar/escalar), snap por incrementos, toggle local/global,
  reponer guías, borrar `CADSketchView.swift` muerto, y **cablear** el motor de G2.
- **G2 · Edición de sub-objeto (el duro)** — dueño: NUEVO `Sources/Services/SubObjectEditEngine.swift` + tests.
  Spike REAL en OCCTSwift v1.8.8 (¿hay API para escalar el wire de una cara / mover arista?),
  implementar lo factible, y **siempre exponer la superficie del contrato** (aunque
  devuelva nil honesto donde OCCT no llegue). NO toca CADModeView.
- **G3 · Estética de líneas** — dueño: `SatinRenderer.swift`, `Shaders/*.metal`, `Theme/`,
  y los builders de geometría de arista/punto (`highlightTube`/`highlightDot`). Líneas
  oscuras nítidas AA, Acero&Brasa, contraste garantizado (halo/adaptativo). NO toca CADModeView/picking.

### Tanda B — conectar al resto del software (post-CI-verde de A, mapeado a F-CAD-3..6)
Variables/expresiones (`fx` en todo campo) · timeline DAG visible (chips reordenables) ·
UI de mates/joints (tap-tap-picker, foso de Onshape/Fusion, motor ya existe) · biblioteca
de materiales drag→cara · trim/offset/fillet/mirror de sketch + arcos · 2D Drawings ·
split body/replace face · puente sculpt↔CAD (el diferenciador bandera). Cada uno = spec
propia (spec-kit) con contrato.

## 4. Contratos de API (firmas — para paralelizar sin colisión)

**G2 provee (consume G1):**
```swift
enum SubObjectEditEngine {
  /// Escala el contorno (outer wire) de una cara planar en su plano, sobre su
  /// centroide, y reconstruye el sólido. nil si OCCT no lo soporta para esa cara.
  static func scaleFaceWire(_ shape: CADShape, faceIndex: Int, factor: Double) -> CADShape?
  /// Traslada una arista y estira las caras adyacentes (press-pull de arista). nil si no factible.
  static func moveEdge(_ shape: CADShape, edgeIndex: Int, delta: SIMD3<Double>) -> CADShape?
  /// Traslada un vértice. nil si no factible.
  static func moveVertex(_ shape: CADShape, vertexIndex: Int, delta: SIMD3<Double>) -> CADShape?
}
```
El engine SIEMPRE existe (compila); `nil` = honesto "OCCT no llega aún" → G1 muestra
estado real, cero botón falso. `TransformTarget.supportsRealGeometry` se actualiza según
lo que G2 logre.

## 5. Gobernanza (no se negocia)
1. Cada ola: **CI verde + device**. 2. Cero botones falsos. 3. Verificar firma OCCT contra
tag v1.8.8 antes de llamar. 4. Documentar en el spec + este doc. 5. Propiedad disjunta +
contrato para paralelizar. 6. Un solo documento; si algo necesita "exportar entre modos", está mal.
