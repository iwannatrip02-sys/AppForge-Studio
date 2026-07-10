# INGENIERÍA INVERSA CAD v2 — Catálogo completo Shapr3D + Fusion 360 → AppForge
> 2026-07-10 · Catálogo EXHAUSTIVO de ambos productos (estado real a julio 2026,
> verificado contra Help Center de Shapr3D y docs de Autodesk), mecánica interna
> de cada herramienta (input→estado→preview→commit→historial), limitaciones
> reales de Shapr3D, el superset Fusion adaptado a touch, y la matriz de estado
> contra el código actual de AppForge. Este doc es LA spec del módulo CAD.
>
> v1 (2026-07-09) cubría ~40% del catálogo. v2 lo cubre entero.

---

## 0. EL PATRÓN UNIVERSAL (la máquina de estados de toda herramienta Shapr3D)

```
ACTIVAR → PEDIR ENTRADA (selección/toque, con hint en banner)
        → PREVIEW EN VIVO (geometría fantasma + número editable)
        → COMMIT (tap fuera / botón / soltar) → HISTORIAL (re-editable)
        → LA HERRAMIENTA SIGUE ACTIVA para repetir (no vuelve a Select)
```

Reglas deducidas usándola:
1. **La selección es un PARÁMETRO, no un modo previo**: Extruir→tocar cara o
   seleccionar→Extruir; ambos órdenes funcionan (`activate()` acepta pre/post).
2. **Preview fantasma SIEMPRE** antes del commit; el número vive junto a la
   geometría, editable con teclado numérico flotante.
3. **Nada te expulsa de la herramienta**: encadenable (5 agujeros seguidos).
   Escape = tap en vacío o Select.
4. **Todo es re-editable** desde el historial paramétrico.
5. **Adaptive UI** (mecánica transversal 2024+): al seleccionar algo, el menú
   contextual ofrece SOLO lo que aplica a esa selección (cara → extrude/offset/
   shell; arista → fillet/chamfer; 2 cuerpos → booleanas). La barra es la misma
   superficie donde luego viven los parámetros del tool activo.
6. **Doble input**: TODA herramienta funciona con dedo Y con Pencil; el Pencil
   dibuja/arrastra, el dedo orbita — sin cambiar de modo (palm rejection real).

## 1. SHAPR3D — CATÁLOGO COMPLETO (julio 2026)

### 1.1 Interfaz y mecánicas base
| Mecánica | Cómo funciona | AppForge hoy |
|---|---|---|
| Orbit/pan/zoom | 1 dedo orbita (si no toca geometría), 2 dedos pan+zoom simultáneo, pinch continuo sin detentes | ✓ CanvasViewModel |
| View cube / vistas | Tap en gizmo de esquina → front/top/right/iso con animación; doble tap cara del cubo = normal a esa cara | parcial (falta gizmo) |
| Items panel | Árbol lateral: cuerpos, sketches, planos, carpetas, grupos; ojo para hide/show; isolate con long-press | parcial (lista simple) |
| Isolate / Hide | Isolate atenúa todo lo demás (no lo borra visualmente, lo deja fantasma al 10%) | ✗ |
| Snapping 3D | Al mover cuerpos: snap a caras/aristas/vértices de otros cuerpos con imán visual | ✗ |
| Grid adaptativo | La rejilla se re-escala con el zoom (1mm→10mm→100mm) y muestra la unidad activa | ✓ WorkPlaneGrid (falta re-escala por zoom) |
| Teclado numérico flotante | Aparece junto al parámetro tocado, con unidades, aritmética inline (30/2+1.5) y tab entre campos | ✗ — CLAVE para sentirse pro |
| Undo/redo gestual | 2 dedos tap = undo, 3 dedos tap = redo (además de botones) | ✗ |

### 1.2 Menú Add (creación de entidades)
| Item | Mecánica | AppForge |
|---|---|---|
| Sketch | Elige plano (base o cara plana de cuerpo) → entra a modo sketch con cámara normal al plano | ✓ |
| Shapes (primitivas) | Box, Cylinder, Sphere, Cone, Torus — se COLOCAN arrastrando sobre cara/plano con dimensiones vivas | ✓ (falta colocación por drag) |
| Text | Texto paramétrico (fuente, tamaño, espaciado) como sketch → extruible/grabable; editable después | ✗ |
| Image | Imagen de referencia sobre plano (calcar); opacidad y escala calibrable ("esta arista = 50mm") | ✗ |
| Construction plane | Offset de plano/cara, por 3 puntos, por ángulo desde arista, tangente a superficie, punto medio entre 2 caras | ✗ (solo planos base) |
| Construction axis | Por arista, por 2 puntos, por centro de cilindro | ✗ |
| Import | STEP, IGES, X_T/X_B (Parasolid), STL, OBJ, 3MF, DWG/DXF (a sketch), SLDPRT, JT, CATPart, USDZ | parcial (STEP vía OCCT) |

### 1.3 Sketch — herramientas 2D completas
| Herramienta | Mecánica interna | AppForge |
|---|---|---|
| Línea/Arco AUTO | Un solo tool: recto = línea; quiebre del trazo al final = conmuta a arco tangente. Cadena anclada. Cotas de longitud/ángulo vivas | ✓ cadena; falta conmutador arco |
| Spline | 2 modos: AJUSTE (pasa por puntos) y CONTROL (polígono); puntos arrastrables post-hoc, tangencia editable en extremos | ✓ spline básica |
| Rectángulo | Diagonal (2 taps) o centro; cotas W×H vivas | ✓ |
| Círculo | Centro→radio; cota Ø viva | ✓ |
| Elipse | Centro + 2 radios | ✗ |
| Polígono | N lados paramétrico, inscrito/circunscrito | ✓ |
| Fillet de sketch | Radio en esquina de 2 líneas, arrastra para cambiar radio | ✗ |
| Trim (Recortar) | Pasas el dedo sobre tramos a borrar; corta en INTERSECCIONES (exige grafo de intersecciones) | ✗ — depende del motor de regiones |
| Offset 2D | Curva/cadena → paralela con distancia viva; cadenas completas de una vez | ✗ |
| Mirror de sketch | Entidades + línea espejo → copia simétrica CON constraint de simetría | ✗ |
| Project | Aristas/siluetas de cuerpos 3D proyectadas al plano de sketch como referencias (asociativas: se actualizan) | ✗ (API `Drawing.project` ✓) |
| Scale de sketch | Escalar entidades seleccionadas con factor o referencia | ✗ |
| **Constraints (14)** | coincidente, horizontal, vertical, paralela, perpendicular, tangente, igual, punto-medio, concéntrica, simétrica, fija (lock), colineal, distancia, ángulo. Se INFIEREN al dibujar (badges), se agregan explícitas desde menú al seleccionar 2 entidades | ✓ solver 12 tipos (falta: badges visuales, agregar por selección, inferencia completa) |
| **Estados de definición** | Sketch sub-definido (azul) vs totalmente definido (negro) — feedback de color por entidad (2026) | ✗ |
| **Cotas conductoras** | Editas la cota → la geometría se regenera vía solver. Doble-tap a cota = teclado | parcial (solver ✓, UI de edición ✗) |
| **Expresiones/variables** | (2026) Variables nombradas (`grosor=3`) usables en cualquier campo; funciones abs(), min(); panel de variables del proyecto | ✗ — GAP GRANDE nuevo |
| Regiones | El sketch es un grafo plano: toda ÁREA CERRADA (por intersecciones) es región sombreada tocable — EL puente sketch→3D | ✓ SketchRegionDetector (verificar en device) |

### 1.4 Tools — sólidos (catálogo completo)
| Herramienta | Mecánica interna | AppForge |
|---|---|---|
| Extrude | Cara/región + flecha normal; ambos lados; "hasta objeto"; zero-thickness warning; si arrastras HACIA DENTRO de un sólido = resta automática | ✓ extrude/pushPull; falta hasta-objeto UI |
| Revolve | Perfil + eje (arista/línea/eje); ángulo vivo con arco fantasma; **(2026) auto-combina o corta según dirección** | ✓ revolve; falta pick de eje + auto-combine |
| Sweep | Perfil ⊥ + curva (spline/cadena); opción "mantener orientación" | ✓ VERIFICADO |
| Loft | 2+ perfiles ordenados; curvas guía opcionales; ruled vs smooth; punto inicial ajustable por perfil (evita torsión) | ✓ loft básico; faltan guías |
| Shell | Cuerpo + grosor; TOCAS las caras que quedan abiertas | ✓ shelled; falta pick de cara |
| Hole | Tap en cara → agujero ⊥ Ø/profundidad o pasante; múltiples de una vez | ✓ drilled + HoleLibrary (¡ya superamos: con roscas de catálogo!) |
| Offset Face | Cara + distancia (mueve cara, sólido se adapta) | ✓ |
| Fillet/Chamfer | Arista(s)/cadena tangente + radio vivo con drag; preview inmediato | ✓ por arista; falta cadena tangente |
| Union/Subtract/Intersect | 2+ cuerpos; subtract con "keep tool" opcional | ✓ |
| Split Body | Cuerpo + plano/cara de corte → N cuerpos | ✗ (API `split` en OCCT) |
| Replace Face | Cara A adopta superficie de cara B | ✗ |
| Pattern | Linear y circular; de CUERPOS y (2025+) de FEATURES; **(2026) cantidad/distancia/ángulo aceptan variables** | ✓ patrón circular básico; falta linear + variables |
| Mirror | Cuerpos + plano espejo; opción unir resultado | ✗ 3D (2D pendiente) |
| Scale | Uniforme/no-uniforme con punto de anclaje | parcial (transform) |
| Measure | Distancia/ángulo/área/volumen entre cualquier par de entidades; masa con densidad de material | parcial (DimensionManager mide, falta panel) |
| Section View | Plano de sección visual en viewport (no destructivo), arrastrable | ✓ SectionPlaneModule (verificar) |
| Project (3D→sketch) | Ver §1.3 | ✗ |

### 1.5 Transform
| Herramienta | Mecánica | AppForge |
|---|---|---|
| Move/Rotate | Gizmo unificado: 3 flechas + 3 arcos; drag numérico vivo; copiar con toggle | ✓ gizmo |
| Align | Cara-a-cara: tocas cara origen → cara destino → alinea con offset opcional | ✗ (AssemblyMates puede cubrirlo) |
| Translate por snap | Mover agarrando un VÉRTICE/arista para posicionar exacto contra otro cuerpo | ✗ |

### 1.6 Historial paramétrico (fuera de beta desde ~2025)
- Timeline lineal inferior con thumbnails de cada feature; tap = editar
  parámetros de esa feature; el modelo se regenera desde ahí.
- Suppress de features, rollback (arrastrar la barra), renombrar features.
- Cotas conductoras y variables globales con expresiones (2026).
- **Nuestro CADHistoryTree ya es DAG (más general que su timeline lineal) — la
  ventaja hay que MOSTRARLA en UI, no solo tenerla en el modelo.**

### 1.7 Visualization (render integrado)
| Capacidad | Detalle | AppForge |
|---|---|---|
| Materiales PBR | Biblioteca por categoría (metal, plástico, vidrio, madera…); (2026) frosted glass, brass, sliders Transmission/IOR | ✓ Metal PBR+IBL (falta biblioteca UI) |
| Entornos | HDRIs con rotación, intensidad, blur de fondo | parcial (IBL fijo) |
| Asignación | Drag material → cuerpo o cara individual | ✗ por cara |
| AR | Ver el modelo en AR (USDZ/QuickLook) a escala real | ✓ ARQuickLookView |

### 1.8 2D Drawings (documentación técnica)
| Capacidad | Detalle | AppForge |
|---|---|---|
| Vistas automáticas | Front/left/top/iso al crear hoja; proyección primera/tercer ángulo | ✗ |
| Section views | Desde vista base, línea de corte editable | ✗ |
| Detail views | Círculo de detalle magnificado | ✗ |
| Cotas | Longitud, punto-a-punto, ángulo, Ø/R; menú adaptativo al seleccionar; tolerancias | ✗ |
| Anotaciones | Notas, centerlines, center marks | ✗ |
| Export | DWG, DXF, PDF, SVG | ✗ |
| **Veredicto** | Módulo entero pendiente — Fase 5. Es lo que convierte "app de modelar" en "herramienta de ingeniería" | |

### 1.9 Interoperabilidad y ecosistema
- Export: SHAPR, STEP, IGES, X_T, STL, OBJ, 3MF, USDZ, PDF/DWG/DXF/SVG (drawings).
- Sync iCloud entre dispositivos; Shapr3D Webviewer (link de solo-vista).
- Sin API pública, sin plugins, sin scripting — **gap de extensibilidad que
  nosotros podemos explotar (pilar 4 de la visión)**.

## 2. LIMITACIONES REALES DE SHAPR3D (confirmadas a julio 2026)

1. **Sin mates/joints de ensamble paramétricos** (confirmado por su propia
   comparativa vs Fusion) — solo posicionamiento manual + align. Grandes
   ensambles (100+ piezas) = inmanejables. → AssemblyMatesEngine (8 tipos +
   solver) YA nos da esto; falta UI táctil.
2. **Sin roscas reales ni cosméticas** — Hole no rosca. → HoleLibrary +
   ThreadFeatures ISO ya lo superan.
3. **Sin rib/web/emboss/draft/thicken/coil/pipe** — features de manufactura.
4. **Sin superficies** (no thicken de surface, no boundary fill, no patch).
5. **Sin sheet metal.**
6. **Sin simulación ni CAM** (fuera de alcance nuestro a corto plazo — ok).
7. **Sin configuraciones** (variantes de un diseño).
8. **Sin API/plugins/scripting.**
9. **Timeline lineal** (no DAG): reordenar features es limitado.
10. **Precio**: $299/año sin tier gratuito útil (solo 2 diseños).

## 3. FUSION 360 — EL SUPERSET (catálogo completo, con adaptación táctil)

Fusion en iPad NO existe como CAD real (solo viewer web) — todo esto es campo libre en tablet.

### 3.1 Create (lo que falta en Shapr3D, priorizado para iPad)
| Feature | Mecánica Fusion | Adaptación táctil propuesta | Prioridad |
|---|---|---|---|
| **Hole avanzado** | Simple/counterbore/countersink + tapped con estándares (ISO/ANSI), profundidad de rosca, punta de broca | Tap cara → flyout con 3 tipos + picker de estándar (ya tenemos HoleLibrary M1.6-M64, UNC, UNF) | F2 ✓ en curso |
| **Thread** | Rosca modelada o cosmética sobre cilindro, con estándar y clase | Tap cara cilíndrica → toggle modelada/cosmética | F2 |
| **Rib / Web** | Perfil abierto → nervio con grosor y dirección | Sketch abierto + drag de grosor | F4 |
| **Emboss** | Texto/sketch sobre cara curva (relieve/grabado) | Con el tool Text de §1.2: texto → cara → altura ± | F4 |
| **Thicken** | Superficie → sólido con grosor | Pick superficie + drag | F4 |
| **Coil** | Hélice paramétrica (resortes, roscas custom) | Primitiva con Ø/paso/vueltas vivas | F4 |
| **Pipe** | Sólido circular/cuadrado a lo largo de curva 3D | Ya tenemos tubo por ruta ✓ — ampliar secciones | ✓ |
| **Pattern on path** | Patrón siguiendo curva | Curva + cantidad | F3 |
| **Boundary Fill** | Volumen cerrado por caras/planos → sólido | — | F5 |
| **Form (T-splines)** | Modelado orgánico box-modeling con conversión a BREP | **NUESTRO MODO SCULPT YA ES ESTO** — el puente sculpt→CAD (convertir malla a BREP con reconocimiento) es EL diferenciador del pipeline unificado | F6-visión |

### 3.2 Modify (lo adoptable)
| Feature | Mecánica | Adaptación | Prioridad |
|---|---|---|---|
| **Press Pull** | Un solo tool contextual: cara→offset, arista→fillet, perfil→extrude | Ya es nuestra filosofía pushPull — extender a aristas | F3 |
| **Draft** | Ángulo de desmoldeo sobre caras con plano neutral | Pick caras + slider ángulo | F4 |
| **Fillet variable** | Radio distinto por vértice de la cadena | Handles por extremo | F4 |
| **Split Face** | Divide cara (para aplicar draft/color parcial) | — | F5 |
| **Combine keep-tools** | Booleanas conservando herramientas | Toggle en confirm | F2 fácil |
| **Parámetros de usuario** | Tabla de variables con expresiones y unidades; TODO campo acepta fx | Panel de variables del proyecto (Shapr3D ya lo copió en 2026 — no quedarnos atrás) | F3 |

### 3.3 Assemble (nuestro golpe de gracia vs Shapr3D)
| Feature | Mecánica Fusion | Estado AppForge |
|---|---|---|
| Components | Cuerpos agrupados con origen propio | parcial (grupos) |
| **Joints (7 tipos)** | Rigid, revolute, slider, cylindrical, pin-slot, planar, ball — con límites y animación de rango | AssemblyMatesEngine tiene 8 tipos de mates + solver iterativo ✓ — FALTA UI: tap cara A → tap cara B → picker de mate + preview animado |
| As-built joints | Unir sin mover | fácil sobre lo anterior |
| Interference | Detección de colisiones entre cuerpos | API `polygonInterference` ✓ |
| Motion | Drive joints con slider | F5 — pero en iPad un slider que ANIMA el mecanismo es espectacular para demos |

### 3.4 Inspect
Measure ✓(parcial) · Interference (F3) · Section analysis ✓ · Center of mass
(F3, trivial con OCCT `volumeProperties`) · Draft analysis (F4) · Zebra/curvatura (F5).

## 4. MATRIZ DE ESTADO — AppForge hoy vs los dos gigantes

Leyenda: ✓ hecho (pendiente verificación en device) · ◐ parcial · ✗ falta

| Área | Shapr3D | Fusion | AppForge |
|---|---|---|---|
| Sketch básico (línea/rect/círculo/polígono/spline) | ✓ | ✓ | ✓ |
| Constraints con solver en vivo | ✓ | ✓ | ✓ (12 tipos, Newton-Raphson) |
| Badges + inferencia + estados de definición | ✓ | ✓ | ✗ |
| Trim/offset/fillet/mirror de sketch | ✓ | ✓ | ✗ |
| Regiones por intersección | ✓ | ✓ | ✓ (verificar) |
| Variables/expresiones | ✓ 2026 | ✓✓ | ✗ |
| Extrude/revolve/sweep/loft | ✓ | ✓ | ✓ |
| Fillet/chamfer/shell/holes | ✓ | ✓✓ | ✓ |
| Roscas | ✗ | ✓ | ✓ API (falta UI) |
| Booleanas | ✓ | ✓ | ✓ |
| Split body / replace face | ✓ | ✓ | ✗ |
| Patrones (linear/circular/features) | ✓ | ✓✓ | ◐ |
| Historial paramétrico re-editable | ✓ lineal | ✓✓ | ✓ DAG (verificar recompute) |
| Ensambles con mates/joints | ✗ | ✓✓ | ✓ motor (falta UI) — **DIFERENCIADOR** |
| Cotas 3D en viewport | ✗ (solo drawings) | ◐ | ✓ — **DIFERENCIADOR** |
| Sección en vivo | ✓ | ✓ | ✓ |
| Materiales/render | ✓✓ | ✓ | ◐ (PBR+IBL sin biblioteca UI) |
| 2D Drawings | ✓✓ | ✓✓ | ✗ — gap más grande |
| Sculpt/orgánico | ✗ | ◐ Form | ✓✓ SculptMode — **DIFERENCIADOR** |
| Paint/texturas | ✗ | ✗ | ✓ PaintMode — **DIFERENCIADOR** |
| Import/export | ✓✓ | ✓✓ | ◐ (STEP/STL/OBJ/USDZ) |
| Extensibilidad (scripts/plugins) | ✗ | ✓✓ | ✗ — oportunidad pilar 4 |
| Precio | $299/año | $545/año (gratis hobbyist) | $0 → freemium |

## 5. MECÁNICAS TÁCTILES QUE HAY QUE CLAVAR (el "cómo se siente")

Estas 8 mecánicas separan "tiene la feature" de "se siente Shapr3D-quality";
son transversales y van ANTES que nuevas features:
1. Teclado numérico flotante con aritmética y unidades (§1.1).
2. Menú adaptativo por selección (ya iniciado en selectionBar ✓).
3. Preview fantasma en TODA operación (LivePreviewEngine ✓ — cablear a todas).
4. Herramienta encadenable que no expulsa (patrón §0 en las 22 ops).
5. Drag numérico: arrastrar el número mismo como slider fino (±ajuste).
6. Undo 2-dedos / redo 3-dedos.
7. Snapping con imán + haptic tick en cada snap (HapticService ✓ — conectar).
8. Hints de banner por herramienta ("Toca la cara a extruir…").

## 6. ORDEN DE IMPLEMENTACIÓN ACTUALIZADO

**F-CAD-1 ✓**: rail+flyouts, selección multi, sketch v1.
**F-CAD-2 (en curso — cerrar y VERIFICAR EN DEVICE)**: agujero+biblioteca,
  spline, sweep, loft, revolve con eje, shell con pick de cara, feature tree
  DAG, cotas 3D, constraints en vivo, regiones, sección, mates (motor), unidades,
  persistencia .appforge.
**F-CAD-3 — paridad de sensación**: las 8 mecánicas de §5 + trim/offset/fillet/
  mirror de sketch + badges de constraints + estados de definición + variables/
  expresiones + patrón linear/de-features + split body.
**F-CAD-4 — superset Fusion**: thread UI, draft, rib, emboss+Text, thicken,
  coil, fillet variable, align, center of mass, interference, planos de
  construcción ricos, UI de mates de ensamble (tap-tap-picker).
**F-CAD-5 — documentación**: 2D Drawings (vistas auto, secciones, cotas,
  DWG/DXF/PDF/SVG) + biblioteca de materiales UI.
**F-CAD-6 — visión**: puente sculpt→BREP, scripting/plugins, motion de joints.

## 7. FUENTES (verificadas 2026-07-10)
- Shapr3D Manual y Tools menu: support.shapr3d.com (Manual 9760033847964, Tools 7768348416028)
- Release 26.100 (2026-06-08): Revolve auto-combine, expresiones, variables en Pattern, frosted glass/brass, Transmission/IOR
- History-Based Parametric out of beta: shapr3d.com/blog product-updates
- 2D Drawings: support 7874466328348 + shapr3d.com/product/2d-drawings (DWG/DXF/PDF/SVG, sections, detail views, tolerancias, centerlines)
- Limitación ensambles confirmada: shapr3d.com/content-library/shapr3d-vs-fusion-360 ("lacks parametric assembly constraints (mates, relationships)")
- Fusion: help.autodesk.com GD-MODIFY-TOOLS, SLD-MODIFY-SOLID-BODY
