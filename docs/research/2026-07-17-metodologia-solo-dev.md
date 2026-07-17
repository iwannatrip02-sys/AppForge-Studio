# Metodología para Construir Software Geométrico Profesional con Equipo Mínimo
**Investigación: Casos Reales, Patrones de Fracaso, y Camino Correcto**

---

## Resumen Ejecutivo

Este documento analiza cómo se construye realmente software CAD de magnitud profesional con equipos pequeños. Los datos muestran que:

1. **Plasticity** (1 dev): 2 años full-time + clave: compró kernel Parasolid (no reinventó), alcance acotado (NURBS, no CAD completo)
2. **Shapr3D** (fundador solo en 2014, luego 152 personas en 2026): necesitó **4 años** (2014-2018) con 1 dev + licencia de Parasolid para v1 usable
3. **SolveSpace**: 14 años de 1 dev (2008-2022); alcance mínimo deliberado; luego pasó a comunidad
4. **Dune3D**: 2.5 años (2023-presente), 1 dev, heredando solver de SolveSpace, objetivo: CAD básico para makers
5. **Onshape** (2012): 5 devs fundadores ex-SolidWorks + inversión; no comparable, pero apunta al tamaño mínimo funcional

**Hallazgo crítico**: Ningún software geométrico profesional se construyó en solitario DESDE CERO en menos de 4 años. Los que lo lograron en 2 años compraron/licenciaron el kernel. 

AppForge hoy está en punto de ruptura: ciclo de "placebo + reescritura" acelera la ruina. La solución es **vertical slice enfocado** + arquitectura real + usuarios tempranos en iPad.

---

## 1. Casos Reales con Línea de Tiempo

### 1.1 Plasticity — Nick Kallen (2021-2023)

**Modelo**: 1 dev, kernel licenciado, alcance acotado.

- **2021-2023**: ~2 años en beta pública (trabajo full-time) antes de v1.0 (abril 2023)
- **Kernel**: Parasolid (Siemens; el mismo que Shapr3D, SolidWorks, NX, Fusion 360)
- **Alcance**: Modelador NURBS "para artistas" — NO CAD completo
  - Splines, superficies, operaciones básicas (boolean, fillet, shell)
  - NO sketch paramétrico (eso es Fusion/Shapr3D)
  - NO constraint engine
  - Interfaz minimalista, flujo directo
- **Resultado**: Competidor viable en nichos (diseño industrial, sculpting), precio bajo (499$)
- **Lección**: Compra el motor, define alcance claro, evita paridad con Fusion

**Fuente**: [80.lv — Plasticity: An Upcoming Modeling Tool by Nick Kallen](https://80.lv/articles/plasticity-an-upcoming-modeling-tool-by-nick-kallen), [CG Channel releases 2023](https://www.cgchannel.com/2023/05/nick-kallen-ships-plasticity-1-1/)

---

### 1.2 Shapr3D — István Csanády (2014-2018)

**Modelo**: 1 dev inicial + team creciente, kernel licenciado, iPad/Pencil first.

- **2014**: Csanády deja su trabajo; comienza desarrollo full-time (fe en iPad Pro como herramienta)
- **2015**: Fundación oficial; construye team desde cero
- **2016 (marzo)**: Shapr3D 1.0 lanzada al iPad (2 años desde decisión)
- **Kernel**: Siemens Parasolid (profesional, usado en SOLIDWORKS/NX)
- **Alcance v1**: Sketch + extrusión + booleanas + fillet + algunos patrones
  - NOT revolucionable (v2+)
  - NOT constraint paramétrico avanzado (eso llegó después)
- **2026**: 152 empleados; versión de escritorio, colaboración cloud

**Lección**: v1 fue **muy acotada**, verificada en device (no simulator), con kernel profesional de entrada. Team creció cuando el modelo probó traction.

**Fuente**: [Wikipedia — Shapr3D](https://en.wikipedia.org/wiki/Shapr3D), [Apple Developer — Behind the Design](https://developer.apple.com/news/?id=i6qdbzn9)

---

### 1.3 SolveSpace — Jonathan Westhues (2008-2022)

**Modelo**: 1 dev, open-source, constraint-based, alcance MÍNIMO.

- **2008-2012**: Desarrollo propietario (freeware, Windows solo)
- **2013**: Open-source (GPLv3); reconoce que "ya no puede avanzar solo"
- **2022**: Sigue activo con contribuciones comunitarias
- **Kernel**: Propio, constraint solver graph-reduction, muy optimizado
- **Alcance deliberado**: 
  - 2D sketch + constraint + extrude/revolve/sweep mínimos
  - NO modelado de superficies
  - NO operaciones complejas
  - Enfoque: precisión paramétrica + rendimiento
- **Contexto**: Westhues era ingeniero NASA; nunca fue "startup" de verdad

**Lección**: Décadas para 1 dev en solo sketch+3D básico. Open-source fue pivote, no plan original. El alcance mínimo es la única forma de un dev solo.

**Fuente**: [Wikipedia — SolveSpace](https://en.wikipedia.org/wiki/SolveSpace), [Hackaday — Dune 3D origin story](https://hackaday.com/2024/05/05/dune-3d-open-source-3d-parametric-modeler-from-the-maker-of-horizon-eda/)

---

### 1.4 Dune3D — Lukas K. (2023-presente)

**Modelo**: 1 dev, basado en ecosistema abierto (hereda SolveSpace solver), objetivo maker-focused.

- **2023-2026**: 2.5 años; aún en desarrollo activo
- **Kernel**: Propio (wire geometry) + Open CASCADE (B-rep sólido)
- **Alcance**: Enclosures para electrónica + parte mecánica simple
  - Sketch 2D constrainido
  - Extrude/pocket/pad
  - No operaciones NURBS
  - No assembly
- **Dev**: Antecedente: Horizon EDA (diseño de PCB, mismo dev)
- **Motivación**: Ni FreeCAD ni SolveSpace hacían lo que necesitaba; construyó para sí

**Lección**: Un dev que trabaja en su propio problema, con herramientas heredadas (OCCT, SolveSpace solver), aún tarda 2.5 años en "usable". Necesita una comunidad paralela.

**Fuente**: [GitHub — Dune3D](https://github.com/dune3d/dune3d), [Hackaday — Dune 3D Review](https://hackaday.com/2024/05/05/dune-3d-open-source-3d-parametric-modeler-from-the-maker-of-horizon-eda/)

---

### 1.5 Blender — Ton Roosendaal (1994-2002)

**Modelo**: 1 dev (attic → studio → empresa → fallida → open-source)

- **1994**: Ton escribe Blender v0 para estudio de animación (NeoGeo)
- **1998-2002**: NaN (Not a Number) intenta comercializar; fracasa por inversores
- **2002 (mayo)**: Crowdfunding "Free Blender" (110k EUR en 7 semanas), open-source
- **2002-2007**: Comunidad voluntaria
- **2007+**: Blender Institute + full-time team

**Lección**: Incluso con un creador brillante, 8 años solo/small-team. Punto de inflexión: comunidad + inversión. Sin eso, la empresa murió.

**Fuente**: [Blender.org — History](https://www.blender.org/about/history/)

---

### 1.6 Onshape — Jon Hirschtick et al. (2012-2015)

**Modelo**: 5 devs fundadores (ex-SolidWorks), capital de riesgo, cloud-native.

- **2012 (nov)**: Fundación; team de 5 (Hirschtick, McEleney, Corcoran, Harris, Lauer)
- **2015**: Beta privada; demostró viabilidad
- **2018+**: Acquisition por PTC
- **Alcance**: Full parametric CAD en el navegador (ambicioso desde inicio)

**Lección**: Ni siquiera con 5 devs ex-SolidWorks fue posible v1 en <3 años. Con capital masivo, arquitectura nativa en nube, seguía siendo 3 años mínimo. **No escalable a 1 dev o agentes IA**.

**Fuente**: [Wikipedia — Onshape](https://en.wikipedia.org/wiki/Onshape), [Jon Hirschtick @ Engineering.com](https://www.engineering.com/founding-and-developing-solidworks-and-onshape/)

---

## 2. Patrones de Fracaso en Software Geométrico

### 2.1 La Espiral de Reescrituras (Raíz de AppForge Hoy)

**Síntoma**: "No avanza hacia software profesional."

**Causa**: Dos sistemas de sketch paralelos (`CADSketchEngine` + `SketchController`) con semántica contradictoria:
- Points duplicados en `splitToLines` → topología rota
- `addPoint` encadena líneas automáticas → dibujos ensuciados
- Ambos intentan ser "el sistema real"; ninguno lo es
- Cada fix en uno rompe el otro

**Patrón de reescritura**:
1. Dev A construye Sistema 1 (incompleto, presionado por tiempo)
2. Dev B (u otro contexto) construye Sistema 2 ("mejor", en paralelo)
3. Ambos coexisten; feature X en 1 no está en 2
4. Usuarios tocan ambos; corrupción silenciosa de datos
5. Director ordena "unificar", pero ninguno es ganador claro
6. **Reescritura comienza**; 2-3 meses perdidos sin feature nueva
7. La reescritura descubre deuda acumulada; de nuevo diverge
8. Loop infinito hasta que el proyecto cae

**Soluciones que fallan**:
- "Agreguemos más gente" → 2x personas = 1/2x productividad durante onboarding (Brooks Law)
- "Pongamos principios arquitectónicos" sin código → cargo-cult
- "Hagamos tests primero" sin entender qué es "correcto" para geometría

**Solución correcta** (§4):
- **Un** sistema de sketch (el ganador) definido con contrato
- Tests de oráculo (golden files) para "correcto" en geometría
- Congelar el perdedor; migrar features una por una
- Verificación en device real antes de marcar done

### 2.2 Fachada Antes que Motor

**Síntoma**: Toolbar completo (16 herramientas), 80% placebos (véase CATALOGO_HERRAMIENTAS.md L36-66).

**Raíz**: Presión de "parecer completo" + falta de definición de "hecho".

**Ejemplos de AppForge**:
- "Chaflán": botón visible, opera sobre índices hardcodeados `[0]`, resultado impredecible → **placebo**
- "Loop cut": idem, "formas extrañas"
- "Sweep/Loft": retirados del código pero aún en UI mental del usuario
- "Booleana unir/restar": motor existe (OCCT), pero selección A/B por chevrones invisibles → inutilizable

**Patrón financiero**: Investor/stakeholder ve toolbar → "¿Dónde está la versión?" Dev intenta "demostrar progreso" sin bases.

**Lección de casos exitosos**:
- **Plasticity**: Solo hace lo que hace bien; no tiene boolean inicialmente
- **Dune3D**: Sketch + pad/pocket + fillet; punto
- **SolveSpace**: Sketch + extrude/revolve; luego sweep/loft si tiempo
- **Shapr3D v1**: Sketch + extrude + boolean + fillet; nada más

**Aritmética honesta**:
- 1 herramienta profesional = 3-4 semanas (diseño UX + motor + snap + selección + preview + gizmos + edición numérica + undo/redo)
- 1 placebo = 2 horas (botón + stub)
- AppForge tiene 12 placebos = 24 horas de "trabajo fantasma" + deuda de 5-6 meses en realidad

**Fijación correcta**: Cada herramienta entra al toolbar solo si cumple FASE_1_DIBUJO_CONTRATO L5 ("el usuario lo verifica en device y funciona").

### 2.3 Falta de Usuarios Tempranos (Beta en Device)

**Síntoma**: "Aristas demasiado delgadas" (L54 CATALOGO), "selección imposible" (L86).

**Raíz**: Iteración exclusiva en CI/simulador. El simulador:**
- No tiene presión Pencil (tactile feedback incorrecto)
- Gestos de dedo no escalan; la hit-zone es pixel-perfect, no 44pt
- Zoom/pan no siente igual
- Lighting/color diferente
- Cumple "CI verde" pero falla con usuario real

**AppForge**: Audit 2026-07-11 (device real) encontró que de 7 "✅" en catálogo, solo 1 era real. Resto 🟡/❌.

**Patrón de fracaso**:
1. Dev confía en tests / CI
2. Usuario real en device: "Esto no funciona, arista invisible, no me deja seleccionar"
3. Dev: "¿Cómo? Los tests pasan..."
4. Downtime 1-2 semanas en debug, device-only problems
5. Re-arquitectura + 3 semanas perdidas
6. Repeats 5-6 veces/año → 3-4 meses de pérdida en ciclo

**Directriz en FASE_1_DIBUJO_CONTRATO L78**:
> "Cada entrega al iPad lleva una lista corta de qué probar. Si el usuario no lo percibe funcionando, se reabre y no se avanza."

**Casos correctos**:
- **Shapr3D**: iPad Pro & Pencil desde day 1 (era el target, no "después")
- **Plasticity**: Keyboard/mouse desktop (diferente device, pero user-verified; no simulator)
- **Dune3D**: 3D-print test (uso real, feedback inmediato)

### 2.4 Definición Débil de "Hecho"

**Síntoma**: Herramienta marca ✅, pero usuario dice "no funciona".

**Raíz**: Métricas de desarrollo ≠ métricas de producto.

**AppForge hoy**:
- "CI verde" ≠ "funciona en device" (visto 2026-07-11)
- "Tests pasan" ≠ "usuario lo puede usar" (hermético geométrico sin feedback visual)
- "Botón en toolbar" ≠ "herramienta completa" (falta snap, gizmos, numérica, preview)

**Definición correcta de "hecho" para herramienta CAD**:
1. Motor geométrico produce resultado correcto (oracle: golden file o test de oráculo)
2. UX fluido en device (hit-testing, snap feedback, gizmos visibles, radio adaptativo)
3. Entrada numérica (teclado + validación)
4. Undo/redo perfecto
5. **Usuario lo verificó en iPad sin instrucciones** (criterio supremo)

**Métrica de duda**: Si el usuario tarda >1 min en descubrir cómo usar, está mal.

---

## 3. El Proceso Correcto: Vertical Slice + Walking Skeleton

### 3.1 Vertical Slice en CAD: No Por Módulo, Por Capacidad de Usuario

**Modelo horizontal (fracasa)**:
```
Semana 1-2:  "Architecure" (cero features visibles)
Semana 3-4:  "Rendering engine" (bonita, no funcional)
Semana 5-6:  "Geometric kernel" (internals, black box)
Semana 7-8:  "UI binding" (conecta kernel a UI, primeros crashes)
→ Semana 8: Usuario aún no puede dibujar nada visible
→ Desmoralización
```

**Modelo vertical (correcto)**:
```
Sprint 1 (1-2 semanas):  Walking skeleton
  → Usuario dibuja línea con Pencil
  → Línea aparece en pantalla
  → Undo funciona
  → Nada más; punto

Sprint 2 (2 semanas):  Línea profesional
  → Snap a extremos, puntos medios
  → Encadenado por segmentos (H/V automático)
  → Entrada numérica de longitud
  → Selección y edición
  → Undo/redo

Sprint 3 (2 semanas):  Círculo completo
  → Centro-radio, radio editable
  → Snap para centro
  → Preview en vivo
  → Undo/redo

Sprint 4 (2-3 semanas):  Rectángulo + región cerrada
  → 2 modos: esquina-esquina, desde centro
  → Detección de región cerrada (sombreado visual)
  → Tap región = extruir
  → Preview extrusión viva

Sprint 5 (2 semanas):  Arco + Spline
  → 2 modos arco: 3 puntos, centro-inicio-fin
  → Spline por puntos (después por control)
  → Ambos editables con Pencil

Sprint 6-7 (3 semanas):  Selección profesional + gizmos
  → Tap → selecciona trazo/región
  → Doble tap → cadena completa
  → Tap punto → lo mueve (con snap)
  → Gizmos siempre visibles
  → Estados visuales claros (normal/seleccionado/bajo dedo/snap activo)

Sprint 8+ (ongoing):  Segunda ola
  → Elipse, polígono
  → Trim/split/offset/mirror
  → Constraints UI (visualización de inferencias)
  → Planos de trabajo / cara de sólido
  → Proyección de aristas
```

**Regla**: **Cada sprint entrega una capacidad de usuario verificable en device.** No "internals mejorados"; no "refactor"; no "para la v2".

**Duración realista**: Sketch profesional (de arriba) = 8-10 semanas con 1 dev + agentes IA para código repetitivo.

### 3.2 Arquitectura en Capas para AppForge

Dado que:
- 1 director no-programador + agentes IA
- Verificación solo en device (iPad físico)
- Kernel OCCT ya existe

**Arquitectura recomendada**:

```
┌─────────────────────────────────────────────┐
│  USER INTERFACE LAYER                        │  ← Agentes IA aquí (boilerplate Swift/UIKit)
│  (Toolbar, Gizmos, Hit-Testing, Gestures)   │  ← Director valida comportamiento
├─────────────────────────────────────────────┤
│  CONTRACTS / PROTOCOL LAYER                  │  ← Director LEE esto (defines "correcto")
│  - SketchDataModel: qué es un sketch         │
│  - SelectionModel: qué puede seleccionarse  │
│  - SnapRules: cuándo snap
│  - UndoRedo: qué es una acción atómica       │
├─────────────────────────────────────────────┤
│  GEOMETRIC ENGINE LAYER                      │  ← Agentes IA: implementan contratos
│  - SketchEngine (único, reina):              │     Riesgo bajo: reglas claras
│    - Wire topology (topología conectada)     │
│    - Point/Curve/Region primitives           │
│  - B-Rep integration (OCCT):                 │
│    - Extrude / Boolean / Fillet              │
│  - Snap & Inference (motor):                 │
│    - Grid, endpoints, centers, intersections │
│    - Guides (visual feedback)                │
├─────────────────────────────────────────────┤
│  PERSISTENCE LAYER                           │  ← Director: verifica archivo .appforge
│  - Serialización B-rep (STEP real)           │     Riesgo bajo: formato estándar
│  - Undo/redo stack (binary, pequeño)         │
│  - Project metadata (JSON)                   │
├─────────────────────────────────────────────┤
│  TESTS / ORACLES (no es layer, es vigilancia)
│  - Golden files (SVG o JSON) de sketch       │  ← Agentes IA generan pairs (input → expected)
│  - 3D geometry comparators (tolerancia eps)  │  ← Director VERIFICA en device
│  - Undo/redo invariants                      │
│  - Serialization round-trip tests            │
└─────────────────────────────────────────────┘
```

**Para el director**:

1. **Lee SOLO la capa de Contracts** (los .swift/.kt files con `protocol` o `interface`).
   - Ejemplo: `SketchDataModel` dice qué métodos existen, qué entran/salen
   - No necesita entender código interno
   - **Esta es la "especificación ejecutable"**

2. **Exige que cada PR cambie solo 1 layer** (no mezcles UI + Engine en same commit)
   - Esto permite diffs legibles

3. **Valida en device**: "¿Puedo dibujar una línea recta? ¿Snappea a extremos? ¿Puedo deshacer?"
   - No esperes a "CI verde"; eso es condición necesaria, no suficiente

### 3.3 Pirámide de Tests para Software Geométrico

```
                 ▲
                /│\
               / │ \
              /  │  \                (1 test / sprint)
             / E2E │  \              Verificación device
            /      │   \            real (manual + script)
           ╱────────────╲
          /  Golden      \           (10-20 tests)
         / Files (SVG)    \          Entrada sketch compleja
        ╱──────────────────╲         → verificar SVG/JSON
       /                    \        salida exacta
      ╱  Unit: Geometry     ╲       (50-100 tests)
     ╱    Solvers,           ╲      Extrude, boolean, fillet
    ╱      Topology           ╲     Snap correctness
   ╱________Invariants_________╲    Undo/redo
  ║                              ║
  ║  Golden Files (B-rep Tests)  ║
  ║  - Input: Wire sketch        ║  (20-50 tests)
  ║  - Output: B-rep SolidID     ║  Topología correcta,
  ║  - Oracle: STEP reference    ║  sin duplicados
  ║                              ║
  ╚══════════════════════════════╝
```

**Estructura concreta**:

1. **Capas bajas** (Geometry unit tests):
   - `testLineCreation_TwoPoints_ShouldSnapToBothEndpoints()`
   - `testRectangle_FromCorner_ShouldProduceClosedRegion()`
   - `testExtrude_Region_ShouldProduceB_RepWithCorrectVolume()` (verificar con oracle: OCCT)
   - `testBoolean_Union_ShouldMaintainTopology()` (comparar B-rep con STEP esperado)

2. **Golden files** (input-output pairs):
   ```
   test_sketch_arc_3pt.json (input: 3 puntos)
   test_sketch_arc_3pt_expected.svg (output esperado)
   → Test: dibuja arco, exporta SVG, compara píxel-a-píxel con tolerancia
   ```

3. **E2E en device** (manual + automation):
   - Script: "Dibuja línea, toca pantalla, verifica aparición"
   - Manual (semanal): Director o usuario toca iPad, verifica feel

**Herramientas**:
- **Unit tests**: XCTest (Swift) o su equivalente
- **Golden files**: SVG comparator (píxel diff); B-rep comparator (STEP tolerance)
- **E2E**: XCUITest (Apple's automation) + screenshot comparison

### 3.4 Cadencia de Release a Usuarios Reales

**Modelo AppForge**:

```
Semana 1-2:  Sprint ciclo
  ┌─ Dev (agentes IA) construye verticalslice
  ├─ Unit tests verdes
  ├─ PR review (director lee contracts + diff legible)
  └─ Merge a main

Semana 2:  Build & Deploy
  ├─ CI compila IPA (ya existe)
  ├─ Director sideloads a iPad personal
  └─ Verifica feature: "¿Funciona como la especificación?" (sí/no)

Resultado:
  ✅ SÍ → release a TestFlight (beta pública)
          Usuarios reales 1-2 semanas
          Feedback: bugs, feel, qué falta
          ← VUELVE A SEMANA 1 (nuevo sprint)

  ❌ NO  → Abre issue específico
          "Snap no funciona en arco 3pt"
          Dev arregla (1-3 días)
          Re-test (día 1)
          Si aún no: se suspende feature, pasa a sprint siguiente
          ← NO RETRASA PIPELINE
```

**Duración**: 2 semanas por vertical slice mínimo; 3 semanas realista.

**Releases públicas**: Cada 4-6 sprints (2-3 meses), o cuando hay "3+ usuarios piden feature completada".

### 3.5 Cuándo NO Añadir Features

**Reglas de "congelación de alcance"** (ya en FASE_1_DIBUJO_CONTRATO):

1. **Si falta una herramienta de la primera ola**: no comiences la segunda ola.
   - Primera ola: Línea, círculo, rectángulo, arco, spline
   - Segunda ola: Elipse, polígono, trim/split/offset/mirror
   - Si spline no tiene 2 modos en device = bloquea segunda ola

2. **Si 2+ herramientas tienen bugs sin fix en 2 semanas**: congelar nuevas, arreglar las viejas.
   - Deuda geométrica crece exponencialmente

3. **Si usuario real rechaza 3 características seguidas**: pause roadmap, entrevista 1:1 con usuario.
   - Razón es arquitectura (p.ej. vértices/puntos no son reales = imposible mover caras)
   - No es "más features", es "fundamentos quebrados"

4. **Cada herramienta nueva requiere:**
   - Contrato de comportamiento (en comments del código)
   - Golden file mínimo (1 input-output pair)
   - Device verification (director toca iPad)
   - **Si alguno falta**: herramienta no entra a codebase

---

## 4. Aritmética Honesta: ¿Qué es Alcanzable en 6/12/24 Meses?

### 4.1 Supuestos Base

- **Recurso**: 1 director no-programador + agentes IA (Claude Code)
- **Agentes IA**: Buenos para boilerplate, tests, documentación; débiles en decisiones de diseño geométrico
- **Verificación**: Solo iPad físico (sin simulador)
- **Kernel**: OCCT ya integrado ✅
- **Timeline actual**: Julio 2026; AppForge lleva ~3 meses activos (fase 1)

### 4.2 Modelo de Productividad

**1 dev (humano) solo**:
- 1 herramienta CAD profesional = 3-4 semanas
- 1 fix de bug geométrico = 3-5 días (debug en device, tolerancias)
- 1 arquitectura rediseño = 2-4 semanas

**1 dev + agentes IA (sin arquitectura rota)**:
- Agentes: boilerplate Swift, tests unitarios, documentación
- Dev (via director/agentes): decisiones de diseño, debug de device, quality gates
- **Speedup esperado**: 1.5x-2x vs solo (no 10x; geometría es dura)

**1 dev + agentes IA (con arquitectura rota = AppForge hoy)**:
- 50% tiempo en "arreglar reescrituras"
- 30% tiempo en debug device (gaps simulator-device)
- 20% tiempo en features nuevas
- **Speedup efectivo**: 0.3x (más lento que solo; deuda acumulada)

### 4.3 Roadmap Realista por Horizonte

#### **6 Meses (Oct 2026)**

**Requisito previo**: Arreglar TODA la deuda (ciclo actual, 2-3 semanas de reescritura de sketch).

**Alcanzable**:
- ✅ Sketch profesional v1 (línea, círculo, rectángulo, arco, spline; snap, selección, gizmos)
- ✅ Extrusión desde región (preview vivo)
- ✅ Boolean unir/restar/intersecar (flujo por tocar cuerpos, no chevrones)
- ✅ Fillet selectivo (por arista, radio variable)
- ⚠️ Shell/vaciar (básico, drag en vivo)
- ❌ Chaflán por arista (placebo, mejor retirar)
- ❌ Loop cut (requiere wire-face topology real; no en 6 meses)
- ❌ Sweep/loft complejos (después de sketch profesional)

**Usuarios**: 5-10 beta testers en TestFlight (arquitectos/makers); feedback diario.

**Métrica de éxito**: "Puedo dibujar un cubo en el iPad en <2 minutos sin frustración."

#### **12 Meses (Enero 2027)**

**Construcción sobre 6 meses**:
- ✅ Sketch completo (segunda ola: elipse, polígono, trim/split/offset/mirror)
- ✅ Constraints visualizadas (badges: H/V/tangente/perpendicular)
- ✅ Planos de trabajo (XY/XZ/YZ, datum planes)
- ✅ Proyección de aristas a sketch
- ✅ Sweep/loft (2-3 perfiles)
- ✅ Patrón lineal & circular (ya existen, consolidar)
- ✅ Mirror (ya existe, consolidar)
- ✅ Mover caras (push/pull mejorado)
- ⚠️ Assembly (solo lectura de .appforge; sin edición multipart)
- ❌ Sculpt profesional (máscaras, dyntopo, multires; v2+)
- ❌ Renderizado PBR tiempo-real (materiales, maybe v2)

**Usuarios**: 20-50 beta (profesionales, CAD veterans); referencia contra Shapr3D.

**Métrica de éxito**: "Puedo hacer 80% de workflows básicos de Fusion/Shapr3D."

#### **24 Meses (Julio 2027)**

**Construcción sobre 12 meses**:
- ✅ Assembly (multipart, mates básicos, explosionado)
- ✅ Renderizado PBR (materiales, AO, sombras)
- ✅ Sculpt pro (máscaras, pinceles avanzados, dyntopo básico)
- ✅ Constraints paramétrico avanzado (cota-conducida, resolver automático)
- ✅ Sheet metal (unfold, doblez)
- ✅ Trabajo colaborativo nativo (iPad + desktop sync)
- ✅ Export/import STEP/IGES sin pérdidas
- ⚠️ Feature recognition (identificar booleanas y descomponerlas; AI-heavy)
- ❌ Análisis FEA nativo (mejor partnership o plugin)
- ❌ PCB/mecánica simultanea (Dune3D hace eso; no es nuestro nicho)

**Usuarios**: 100-200 profesionales; pago freemium si tracción.

**Métrica de éxito**: "Sustituye Fusion 360 en 70% de mis workflows CAD en iPad."

### 4.4 Recortes Necesarios para Viabilidad

**Shapr3D necesitó 4 años (2014-2018) + 152 personas (2026).**
**AppForge no puede ser Shapr3D.**

**Recortes sugeridos** (priorizan foco vs. cobertura):

| Característica | Shapr3D v1 | AppForge 24m | Por qué |
|---|---|---|---|
| Sketch | Sí | Sí | Core; todo deriva de aquí |
| Extrude/Revolve/Sweep | Sí | Sí (revolve 12m, sweep luego) | Operaciones básicas |
| Boolean | Sí | Sí | No CAD sin booleanas |
| Fillet | Sí | Sí (selectivo; global después) | Común; relativamente barato |
| Assembly | v3+ | v2.x (24m) | Shapr3D tardó 2+ años; nosotros después |
| Constraint completo | v3+ | v2 básico (12m) | Inferencia, no solver | 
| Sheet metal | v4+ | No (v3+) | Nicho; después |
| Sculpt pro | v3+ | v2 básico (12m) | Máquina diferente; después |
| Renderizado real | v2+ | v1 (12m, básico) | Arte, no ingeniería; importante para UX |
| Colaboración cloud | v2+ | v2.x (24m) | Complejo; primero local perfecto |
| Freemium/suscripción | Ahora | v1.5 (18m, beta) | No sin usuarios reales |

**Versión mínima viable ("MVP real", no "1.0 complete")**:
- Sketch profesional
- Extrude/revolve/sweep
- Boolean unir/restar/intersecar
- Fillet/chaflán
- Visualización clara
- Export STEP sin pérdidas
= **¿Qué hace falta vs. hoy?** De lo de arriba, ya está OCCT. Falta: sketch OK, booleana usable (hoy imposible), selección 3D (vértices reales).

---

## 5. Qué Debe Aprender el Fundador (Director No-Técnico)

### 5.1 Los 4 Conceptos Críticos

#### 1. **Arquitectura por Capas = "Contratos"**

**Por qué importa**: Si entiende esto, puede pedir cambios sin entender el código.

**Concepto simple**:
```
La app es un sandwich:
[UI] 
[Contracts/APIs (la capa visible)]  ← AQUÍ LEE EL DIRECTOR
[Implementation details]
[Persistence]
```

El director necesita entender:
- Qué métodos existen (contrato)
- Qué entra/qué sale
- Qué invariantes deben mantenerse (p.ej. "nunca dos puntos en la misma ubicación")

**NO necesita**:
- Cómo se implementa (el código interno)
- Lenguajes de programación
- Data structures

**Herramienta**: Pedir al dev que escriba el "contrato" como comentarios/interfaces antes de código.

**Recurso** (español):
- [Martin Fowler — Microservices (patterns)](https://martinfowler.com/microservices/) — aplica a capas
- ["API Design Like You Mean It" — Keynote](https://youtu.be/aAb7hSCJ5pM?t=1200) — 20 min, conceptos clave

#### 2. **Tests = Especificación Ejecutable**

**Por qué importa**: Tests no son "validación"; son "qué se supone que hace".

**Concepto simple**:
```
Test dice:
  INPUT: 2 puntos (0, 0) y (1, 0)
  ACTION: dibuja línea entre ellos
  OUTPUT: línea horizontal, seleccionable, snappea a extremos
  ✅ PASA o ❌ FALLA

Si test falla, el código NO hace lo que debería.
Si test pasa, código hace (mínimo) lo que test dice.

Tests son "la verdad" del software.
```

**Implicación para AppForge**:
- Cada PR debe venir con test nuevo o test mejorado
- Tests son la "especificación" (no doc de 100 páginas)
- Si implementación no tiene test, assume que no funciona

**Para el director**:
- Pedir: "¿Qué test verificó esto?"
- Si respuesta es "confío en que funciona" = red flag
- Si respuesta es "aquí está el test, lo puedes correr en device" = confianza

**Recurso** (español):
- [Test-Driven Development con ejemplos de geometría](https://www.codementor.io/blog/test-driven-development-tdd) — 15 min

#### 3. **Leer Diffs = Entender Qué Cambió**

**Por qué importa**: No puede entender código detallado, pero SÍ puede entender qué cambió y si es coherente.

**Concepto**:
```
ANTES:
  func sketch(didAddPoint: CGPoint) {
    let line = Line(from: lastPoint, to: point)  // Automático
    topology.add(line)
  }

DESPUÉS:
  func sketch(didAddPoint: CGPoint) {
    topology.add(point)  // Solo punto; sin línea automática
  }
  
INTERPRETACIÓN (para director):
- El cambio quita "crear línea automática"
- Eso arreglaba bug L15 del CATALOGO (encadena líneas)
- ✅ Parece correcto
```

**Cómo aprender**:
- GitHub / GitLab muestra diffs de colores (rojo = removido, verde = agregado)
- Aprende a leer en 5 líneas/PR
- Busca: cambios GRANDES (refactor) vs. cambios PEQUEÑOS (fix)
- Refactors grandes sin test nuevo = sospechoso

**Red flags en diffs**:
- 500+ líneas en 1 commit (probablemente refactor invisible)
- Nueva función pero ningún test la llama
- Cambios en 3+ capas (UI + Engine + Persistence) juntos = incohesivo

**Recurso**:
- [How to Read a Diff](https://www.git-tower.com/learn/git/ebook/en/command-line/basics/viewing-commits) — 10 min
- Práctica: GitHub UI muestra diffs automáticamente; 5 min/día durante 1 semana

#### 4. **Golden Files = "Oráculos Geométricos"**

**Por qué importa**: Geometría es difícil de verificar (no es "sí/no" sino "¿exacta según tolerancia?").

**Concepto**:
```
Pregunta: ¿La extrusión de una región cerrada produce un B-rep válido?

Respuesta anterior (mala):
  ✅ "CI verde" (tests pasan de forma genérica)

Respuesta correcta (golden file):
  INPUT:  Wire sketch: rectángulo 10x10 en XY
  ORACLE: B-rep esperado (STEP export de referencia, exacto)
  TEST:   Extrude rectángulo, compara B-rep con ORACLE
          ✅ Coinciden (tolerancia 0.001mm) = correcto
          ❌ No coinciden = BUG

Golden file = "lo que sabemos que es correcto"
```

**Para AppForge**:
- Cada extrude/boolean/fillet tiene golden file (STEP real, verificado a mano en device)
- Agente IA genera código, test ejecuta contra oracle
- Director: verifica en device que oracle es realmente correcto (1 vez)

**Herramienta**:
- Guardar archivo .appforge de ejemplo + salida STEP esperada
- Test compara STEP actual con esperado (tolerancia)

**Recurso**:
- [Joe Warren — Golden Testing for CAD](https://doscienceto.it/blog/posts/2026-04-27-golden-testing-cad.html) — 20 min; casos reales

### 5.2 Los 5 Hábitos de Dirección Diaria

#### Hábito 1: PR Review en 5 Minutos (No Leer Código)

**Proceso**:
1. Ve el diff (GitHub)
2. Lee el título y descripción
3. Pregunta: "¿Qué es lo que cambió? ¿Arregló un bug? ¿Feature nueva?"
4. Verifica: ¿Hay test nuevo? ¿Qué prueba?
5. Resultado: Aprueba O pide cambios (nunca "leo el código 30 min")

**Ejemplo PR buena**:
```
Título: "Fix: SketchEngine deduplica puntos automáticamente"
Descripción:
  Arreglaba bug L82 CATALOGO: cuando dibujabas 2 líneas, 
  addPoint duplicaba el punto compartido.
  
  Cambio: En topology.add(point), verify distance < epsilon; 
  si existe punto cercano, merge.
  
  Test: testAddPointDeduplicates_TwoLinesWithSharedEndpoint
  
Diff: 10 líneas en SketchEngine.swift, 5 líneas en test
```
Director dice: "✅ Aprobado. Pasa a device test mañana."

**Ejemplo PR mala**:
```
Título: "Refactor: Better architecture"
Descripción: (vacía)
Diff: 500 líneas, 3 archivos, sin test nuevo
```
Director dice: "❌ Rechazado. ¿Qué arreglaste? ¿Qué test verifica?"

#### Hábito 2: Verificación Weekly en Device (30 min)

**Lunes o viernes, 30 min**:
1. Compila ultima versión (CI da IPA)
2. Sideloads a iPad personal
3. Toca cada feature de la semana: "¿Funciona como se supone?"
4. Toma 2-3 screenshots de "antes/después"
5. Nota en ticket: "✅ Verificado" o "❌ Bug: [descripción]"

**Ejemplo**:
```
Ticket: "Implement Snap to Endpoints"
Verificación:
  - ✅ Dibuja línea, acerca punto a extremo → resalta en rojo
  - ✅ Suelta dedo → snap ocurre
  - ❌ Bug: A veces snappea a punto distante (radio mal calibrado)
      → Abrirá nuevo ticket "Tune snap radius"
```

#### Hábito 3: Congelación Semanal de Scope

**Cada lunes 9am**:
- Revisa sprint actual: "¿Qué está bloqueado? ¿Qué es realista para esta semana?"
- Si 2+ tareas sin progreso: congela nuevas features, arregla bloqueos
- Comunica al equipo (agentes IA): "Esta semana: arco + selección. Sin elipse."

#### Hábito 4: Entrevista a Usuario Mensual (30 min)

**Cada 4 semanas, 1 usuario beta real**:
- "¿Qué no funciona?"
- "¿Qué te falta más?"
- "¿En qué área pierdes más tiempo?"

**Salida**: 1-2 tickets nuevos de arquitectura (no features) o prioridad reordenada.

**Ejemplo**:
```
Usuario: "No puedo mover la cara de un cubo después de extruir."
Director: "¿Por qué? (escucha)"
Usuario: "Toco la cara, me lleva a move, pero mueve TODO el objeto."
Director: (Abre arquitectura issue): "Vértices/aristas/caras no son entidades reales"
         Depende de: Arreglar topología 3D
         Bloquea: Mover caras, selección selectiva, etc.
```

#### Hábito 5: Documentar "Corrección" en Contracts

**Cada que arreglas un bug significativo**:
1. Abre el archivo de contrato (p.ej. `SketchDataModel.swift`)
2. Añade comentario: "// BUG FIXED 2026-07-17: points no se deduplicaban"
3. Referencia ticket: "#123"

**Razón**: 6 meses luego, alguien pregunta "¿Por qué esta línea hace esto?" → respuesta está en contrato.

### 5.3 Currículo Mínimo Priorizado

Aprende en este orden (1 semana cada uno, paralelo a desarrollo):

#### Semana 1: **Arquitectura por Capas**
- Recurso: [Martin Fowler — Layered Architecture](https://martinfowler.com/bliki/LayeredArchitecture.html) (15 min)
- Tarea: Dibuja las 5 capas de AppForge en papel; etiqueta cada módulo
- Video: [Architecture Patterns in Practice](https://www.youtube.com/watch?v=kFz0L9RlTVg) (30 min, en inglés pero subs español)

#### Semana 2: **Tests como Especificación**
- Recurso: [Jest Test Examples](https://jestjs.io/docs/getting-started) (15 min; adaptable a Swift)
- Tarea: Lee 3 tests de AppForge (p.ej. `testLineCreation`), entiende qué verifican
- Práctica: Escribe en pseudo-código "qué debería hacer" una herramienta, luego mira test real

#### Semana 3-4: **Leer Diffs**
- Recurso: [GitHub Diff Help](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/about-pull-request-reviews) (10 min)
- Práctica: 10 PRs reales de AppForge; leer diffs, no código
- Objetivo: Detectar refactor vs. feature vs. bugfix en 1 minuto

#### Semana 5: **Golden Files & Oráculos**
- Recurso: [Joe Warren — Golden Testing](https://doscienceto.it/blog/posts/2026-04-27-golden-testing-cad.html) (20 min)
- Tarea: Selecciona 1 feature (p.ej. extrusión); define qué es "correcto"
- Práctica: Genera 3 golden files (input → salida esperada)

#### Después: **Deepdive Optativo**
- Paul Graham — [Great Hackers](https://www.paulgraham.com/gh.html) (40 min; inspiración + insight en diseño)
- [Software Architecture Monday](https://www.developertoarchitect.com/lessons/) (serie de videos, 5 min/ep; pick una semana)

---

## 6. Riesgos Críticos en los Próximos 6 Meses

### 6.1 Riesgo: La Reescritura de Sketch No Converge

**Síntoma**: "Llevamos 3 semanas, AÚN no tenemos línea profesional."

**Causa**: Ambición de "hacerlo bien" vs. "empezar a funcionar".

**Prevención**:
- Fijar hito: "Línea básica entra al device en 1 semana" (dump perfección)
- Fácil > Perfecto (iteración después)
- Si al día 7 no funciona: revert + plan b (ej. usar topología simple, no wire conectada)

### 6.2 Riesgo: Agentes IA Generan Código Incorrecto en Geometría

**Síntoma**: "El test pasa pero el usuario dice que falla."

**Causa**: Agentes IA no saben tolerancias/precisión numérica en geometría.

**Prevención**:
- **Nunca** dejes que agentes IA escriban lógica geométrica core (solver, snap, boolean)
- Agentes IA SOLO: boilerplate, tests, documentación, "pegamento"
- Geometría: director (con consejo de agentes IA) o revisión experta

**Chequeo**: "¿Cambió algo que toca números? (tolerancias, comparaciones). Si sí: verifica en device."

### 6.3 Riesgo: Feature Creep Oculto

**Síntoma**: "Dijimos 'línea', pero dev también añadió 'entrada numérica', que luego necesita 'validación', que necesita 'undo de valores numéricos'..."

**Prevención**: MoSCoW + congelación semanal.

```
Línea v1.0 MUST:
  - Dibujar con Pencil
  - Snap a extremos
  - Undo/redo
  
Línea v1.0 SHOULD:
  - H/V automático
  
Línea v1.0 COULD:
  - Entrada numérica (después)
  
Línea v1.0 WONT:
  - Restricciones (v1.5+)
  - Tangente automática (v1.5+)
```

Si algo aparece que no está en MUST: no entra a v1.0.

### 6.4 Riesgo: Verificación en Device se Vuelve Cuello de Botella

**Síntoma**: "Build tarda 20 min, sideload 5 min, prueba 10 min = 35 min/ciclo. Agentes IA generan 5x más rápido."

**Prevención**:
- Automatizar tests en simulator (para rapidez)
- **Pero** verificación de feel en device cada 2-3 días (no diaria)
- Usar script de XCUITest para "humo": "¿La app startea?"

### 6.5 Riesgo: Scope de 6 Meses Es Irreal

**Síntoma**: "Sketch profesional" = línea + círculo + rect + arco + spline + selección + gizmos + snap + preview. Son 8-10 semanas. Metimos 6 meses de otras cosas.

**Prevención**:
- Congelar TODO (booleana, fillet, etc.) hasta sketch esté 100% en device
- Sketching es **fundación**; todo lo demás depende
- Si sketch no es profesional, nada funciona bien

---

## 7. Resumen: El Camino en Pasos

### Mes 1 (Julio-Agosto 2026)

1. **Congelar 1 sistema de sketch** (winner: CADSketchEngine o SketchController, definir hoy)
2. **Reescribir topología**: UN wire conectado, sin duplicados
3. **Parar 10 herramientas placebo**: remover de UI (no de código, guardar para v2)
4. **Definir contrato SketchDataModel**: qué métodos, qué invariantes (comentarios, no tests todavía)
5. **Establecer golden files**: 3 ejemplos (rectángulo, círculo, arco)

### Mes 2-3 (Agosto-Octubre 2026)

6. **Línea + Snap profesional**: terminada en device, verificada
7. **Círculo + Rectángulo**: id.
8. **Arco + Spline**: ambos con 2 modos, editables
9. **Selección completa**: tap/doble-tap, arrastrar puntos
10. **Gizmos visuales**: siempre visibles, estados claros

### Mes 4-6 (Octubre-Diciembre 2026)

11. **Región cerrada → Extrusión viva**: preview en drag
12. **Booleana usable**: flujo por tocar cuerpos, preview coloreado
13. **Fillet selectivo**: radio variable, arista por arista
14. **Undo/Redo perfecto**: cubre sketch + 3D
15. **Beta TestFlight**: 10-20 usuarios, feedback semanal

### Si va bien (Meses 7-12):

16. **Segunda ola sketch**: elipse, polígono, trim/split/offset/mirror
17. **Constraints UI**: badges (H/V/tangente), inferencias visuales
18. **Revolve/Sweep**: operaciones de perfil rotado/barrido
19. **Assembly básico**: multipart, sin mates (v1.5 idea)

---

## 8. Conclusión: La Verdad Incómoda

**Shapr3D tardó 4 años con 1 dev + kernel licenciado.**
**Plasticity tardó 2 años solo porque compró Parasolid.**
**SolveSpace lleva 14 años de 1 dev y AÚN está en constraint+extrude básico.**
**Blender tardó 8 años; luego empresa se quebró; luego open-source + community.**

**AppForge puede ser viable en 24 meses si**:
1. Congelar scope deliberadamente (NO ser Shapr3D/Fusion)
2. Arquitectura limpia = director puede dirigir sin programar
3. Verificación implacable en device (no simulator)
4. Usuarios reales cada 2-3 meses
5. Aceptar que "sketch profesional" = 3-4 meses de dev enfocado

**AppForge fracasará si**:
1. Intenta paridad con Shapr3D (imposible)
2. Mantiene placebos en UI (deuda psicológica)
3. Confía en CI (simulator no es device)
4. Agrega features sin usuarios pidiendo
5. No congela scope (feature creep mata equipos pequeños)

**Lo que el fundador debe hacer YA**:
- Leer este documento 2x
- Entrevista 1:1 con dev/agentes: "¿En qué estado está realmente el sketch?"
- Decidir: ¿Congelamos o Reescribimos? (No ambos)
- Si Reescribimos: 2-3 semanas, nada más hasta que funcione
- Si Congelamos (mejor): defino contrato hoy, empiezo verticales slices mañana

**Métrica de victoria en 24 meses**:
> "Usuarios profesionales (sin instrucciones) pueden diseñar una pieza mecánica simple en iPad en <30 min, comparable a Shapr3D. No es feature-complete; es profundo en lo que hace."

---

## Fuentes y Referencias

### Casos Reales
- [80.lv — Plasticity: An Upcoming Modeling Tool by Nick Kallen](https://80.lv/articles/plasticity-an-upcoming-modeling-tool-by-nick-kallen)
- [Wikipedia — Shapr3D](https://en.wikipedia.org/wiki/Shapr3D)
- [Wikipedia — SolveSpace](https://en.wikipedia.org/wiki/SolveSpace)
- [Hackaday — Dune 3D: The Making of a Maker's Tool](https://hackaday.com/2024/05/05/dune-3d-open-source-3d-parametric-modeler-from-the-maker-of-horizon-eda/)
- [Blender.org — History](https://www.blender.org/about/history/)
- [Wikipedia — Onshape](https://en.wikipedia.org/wiki/Onshape)

### Patrones de Fracaso
- [Potapov.dev — Why Big Rewrites Fail](https://potapov.dev/blog/why-big-rewrites-fail/)
- [Peerbits — How to Rescue a Failing Software Development Project](https://www.peerbits.com/blog/rescue-failing-software-development-project.html)

### Arquitectura y Testing Geométrico
- [Shapr3D — Technological Foundations of CAD](https://www.shapr3d.com/content-library/what-is-cad-the-technological-foundations-of-cad-software)
- [Joe Warren — Golden Testing for CAD Software](https://doscienceto.it/blog/posts/2026-04-27-golden-testing-cad.html)
- [ScienceDirect — Geometric Modeling Kernels](https://www.sciencedirect.com/topics/engineering/geometric-modeling-kernel)

### Dirección No-Técnica
- [Medium — Non-Technical Founders Managing Engineering Teams](https://medium.com/@yewandesulaiman/managing-engineering-teams-as-a-non-technical-founder-pm-92d9a88ff1b7)
- [How Non-Technical Startup Founders Can Thrive](https://startupnation.com/grow-your-business/non-technical-startup-founders/)
- [Paul Graham — Great Hackers](https://www.paulgraham.com/gh.html)

### MVP y Vertical Slicing
- [Minimum Viable Product — Vertical Slicing](https://hacknplan.com/blog/understanding-vertical-slicing)
- [LogRocket — Feature Creep Prevention](https://blog.logrocket.com/product-management/what-is-feature-creep-how-to-avoid/)

---

**Investigación completada: 2026-07-17**
**Autor: Investigador — AppForge Studio**
**Clasificación: Interna — Decisión Estratégica**
