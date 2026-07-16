# AppForge Studio — DESIGN SYSTEM v1.0 (Forge Glass)

> v1.0 · 2026-07-15 · Agente DESIGN BIBLE
> **Fuente ÚNICA de verdad de toda UI.** Lenguaje y filosofía en `VISION.md`.
> Tokens máquina-legibles en `design_tokens.json` (de ahí se genera el Theme Swift).
> Contrato de gestos SAGRADO en `docs/DISENO_INTERFAZ.md` — este doc no lo contradice.
>
> ## REGLA CERO (no negociable)
> **Nunca se improvisa UI.** Todo componente se arma con los tokens y componentes de
> abajo. **Si un componente necesario ROMPE el sistema, primero se actualiza el sistema
> (este doc + `design_tokens.json` + `VISION.md`), con justificación escrita, y LUEGO se
> construye.** El código nunca va por delante del sistema. Un color, radio, blur o
> duración fuera de estos tokens es un bug de diseño aunque compile.

---

## 1. Paleta — roles semánticos

El color comunica ESTADO, no decora. Cada token tiene un ROL; usar el hex por "porque
se ve bien" está prohibido. Dark-first es el único modo de identidad; el claro existe
solo por accesibilidad.

### 1.1 Fondos — "taller de noche" (OLED)

| Token | Hex | Rol semántico |
|---|---|---|
| `bg.canvas` | `#0A0B10` | El viewport 3D. El negro más profundo. El modelo es el héroe; nada más puede ser tan oscuro. |
| `bg.base` | `#12141A` | Superficie principal cuando NO hay viewport (settings, export, onboarding). |
| `bg.raised` | `#1A1D26` | Cards y superficies elevadas sobre `bg.base`. |
| `bg.overlay` | `#222630` | Estado hover/activo de una fila o celda. |
| `bg.glass` | `#1B1E28` | Tinte base del vidrio (se pinta DEBAJO del `.ultraThinMaterial`, ver §3). |

### 1.2 Brasa — acento único (estado "caliente / editándose ahora")

| Token | Hex | Rol semántico |
|---|---|---|
| `ember` | `#FF7A45` | Acción activa, selección, foco, número vivo, glow de operación. |
| `ember.glow` | `#FFA06B` | Halo del glow y estados presionados. |
| `ember.deep` | `#D9541E` | Destructivo-intencional: excavar, boolean subtract, hornear. |

**Regla de oro:** si algo brilla brasa, responde al tacto o está siendo modificado
AHORA. Nada decorativo lleva brasa. **Una sola cosa caliente a la vez.**

### 1.3 Materiales — la dualidad B-rep / malla (corazón de la identidad)

| Token | Hex | Rol semántico |
|---|---|---|
| `steel` | `#6FA3D0` | Material exacto (B-rep): edge-overlay, badge ⬡, cotas, valores CONFIRMADOS. |
| `steel.bright` | `#8FBCE4` | Acero enfatizado: selección de cara exacta. |
| `clay` | `#C79A6B` | Material libre (malla): badge 〰, tinte de selección de malla. |

### 1.4 Semánticos de sistema (SOLO feedback de sistema, nunca chrome)

| Token | Hex | Rol |
|---|---|---|
| `success` | `#34D399` | Éxito. Coincide con eje Y (verde). |
| `warning` | `#FBBF24` | Atención. |
| `error` | `#F87171` | Error. Coincide con eje X (rojo). |
| `axis.x` | `#F87171` | Eje X — convención universal, no se toca. |
| `axis.y` | `#34D399` | Eje Y. |
| `axis.z` | `#6FA3D0` | Eje Z (acero). |

### 1.5 Texto y bordes

| Token | Hex | Rol |
|---|---|---|
| `text.primary` | `#F0F1F5` | Texto principal, valores. |
| `text.secondary` | `#9AA0B0` | Labels, texto de apoyo. |
| `text.tertiary` | `#5A5F6E` | Iconos inactivos, hints, unidades. |
| `border.default` | `#2A2E3A` | Borde de vidrio y separadores (1px). |
| `border.subtle` | `#1E212B` | Borde apenas perceptible en superficies internas. |

### 1.6 Contrapartes de modo claro (accesibilidad)

`light.bg.canvas #F2F2F7` · `light.bg.base #FFFFFF` · `light.bg.raised #F9F9FB` ·
`light.bg.overlay #E5E5EA` · `light.text.primary #1C1C1E` · `light.text.secondary
#636366` · `light.text.tertiary #AEAEB2` · `light.border #C6C6C8`. Brasa/steel/clay se
conservan idénticos (funcionan en ambos modos).

---

## 2. Regla suprema: jerarquía de chrome sobre el viewport

**El viewport es el rey.**

- **Chrome permanente ≤ 15% del área** (iPad 11"/13" apaisado). El viewport nunca se
  recorta por paneles: los paneles FLOTAN encima, translúcidos.
- **Nada opaco sobre el viewport.** Todo panel sobre la escena 3D es vidrio (§3). Cajas
  opacas grises están prohibidas sobre `bg.canvas`.
- **El modelo es el punto más brillante de la pantalla, siempre.** Ningún panel de
  vidrio debe tener más contraste/brillo que la geometría renderizada.
- **Layout canónico** (ver `DISENO_INTERFAZ.md §2`):
  - Rail de herramientas: **izquierda**, ancho fijo **56pt**, vidrio, icono+flyout.
  - Barra de modos: **inferior**, alto **56pt**, vidrio, centrada.
  - Panel de propiedades / parámetros: **efímero**, aparece solo con la tool activa,
    junto al efecto; desaparece al aplicar.
  - Chrome superior: mínimo (modo a la izquierda, ⚙︎ a la derecha), ≤44pt de alto.
- **HUD en viewport, no en panel:** cotas, ángulos, número vivo y datos de operación se
  dibujan SOBRE la geometría (píldora inline, ver Componente 4.8), nunca en un panel
  lejano.

---

## 3. Materiales, translucidez y blur (LO QUE MÁS IMPORTA)

Andrés lo pidió explícito: *"esos colores, las semitransparencias, las opacidades"*.
Aquí se define con precisión de reloj. Hay **un solo material de panel** — no se
inventa otro.

### 3.1 Receta canónica del panel de vidrio (`glassPanel`)

Se aplica a TODO panel flotante (flyouts, barra de parámetros, popovers, mode bar):

```
capa 1 (fondo):   bg.glass (#1B1E28) al 72% de opacidad
capa 2 (blur):    .ultraThinMaterial  (iOS system blur ≈ radio 20–30pt, adaptativo)
borde:            border.default (#2A2E3A), 1px, dentro del corner radius
sombra:           elevation.level2  (negro 25%, radio 12, y +3)
corner radius:    radius.md (10pt)  — flyouts y barras
padding interno:  space.3 (12pt)
```

**Opacidad exacta del tinte por contexto:**

| Contexto | Opacidad de `bg.glass` sobre el material | Por qué |
|---|---|---|
| Panel sobre el viewport 3D | **0.72** | debe verse la geometría detrás; el blur hace el resto |
| Flyout de herramienta | **0.78** | legibilidad de labels sobre escena movida |
| Barra de parámetros activa | **0.80** | contiene el número vivo, prioriza lectura |
| Panel sobre `bg.base` (settings/export, sin 3D detrás) | **0.92** | no hay nada valioso detrás que mostrar |
| HUD inline (cota/número en viewport) | **0.65** + material | mínima intrusión sobre el modelo |

### 3.2 Blur radii

- **Paneles flotantes:** `.ultraThinMaterial` del sistema (nunca custom `.blur()` sobre
  contenido — mata rendimiento y rompe la consistencia). Equivale a ~20–30pt adaptativo.
- **Glow de estado (§3.4):** blur gaussiano **24pt** sobre la capa de color, SOLO en la
  luz del glow, nunca sobre texto.
- **Nunca** blur > 30pt en UI. Nunca blur decorativo sobre el viewport completo.

### 3.3 Cuándo SÍ / cuándo NO usar vidrio

| SÍ vidrio | NO vidrio (usar superficie opaca `bg.raised`) |
|---|---|
| Cualquier panel que flote sobre el viewport 3D | Pantallas full-screen sin 3D detrás (onboarding, export sheet) |
| Flyouts de herramienta, barra de parámetros | Fondo de listas largas y densas (rendimiento) |
| Mode bar, popovers, tooltips | Modales de sistema (usar sheet nativo iOS) |
| HUD inline sobre geometría | Fondo del propio viewport (es `bg.canvas`, no vidrio) |

### 3.4 El glow de estado (la FIRMA — reemplaza el "templado" de borde)

Cuando una operación está **activa/caliente**, su panel irradia un glow desde dentro:

```
color:      ember (#FF7A45) para operación normal · ember.deep para destructiva
forma:      radial gradient centrado en el panel, del 45% de opacidad al 0%
blur:       24pt sobre la capa de color (nunca sobre el texto)
extensión:  se derrama ~16pt fuera del borde del panel (bleed)
```

**Templado (confirmación):** al aplicar la operación, el glow transiciona
`ember → steel` y decae a 0 en **400ms easeOut**, con haptic `medium`. Confirmación
visual sin toast: "el metal se templó, la operación es sólida". Un SOLO efecto de
firma, usado en: push/pull, boolean, fillet, chamfer, shell, hornear, validar sketch.

**Prohibido:** dos glows a la vez; glow sin operación activa; glow verde/azul (el color
del glow codifica calor, no marca).

### 3.5 Prohibiciones de materialidad

- Gradientes decorativos multicolor (los de `ref-03/04` son inspiración de *sensación*,
  no se copian como fondo).
- Sombras de color (solo negro semitransparente para elevación).
- Blur sobre texto.
- Más de un material de panel. Si algo no es `glassPanel` ni `bg.raised` opaco, no
  existe en el sistema.

---

## 4. Tipografía — "instrumental" (SF Pro, NO Rounded)

La personalidad va en las REGLAS, no en la fuente.

### 4.1 Escala

| Token | Tamaño / peso / diseño | Uso |
|---|---|---|
| `type.largeTitle` | 28 Bold | Solo headers de onboarding. |
| `type.title1` | 20 Semibold | Títulos de pantalla. |
| `type.title2` | 15 Semibold | Headers de sección. |
| `type.heading` | 12 Medium | (base para group labels, ver §4.2) |
| `type.body` | 13 Regular | Texto de cuerpo. |
| `type.caption` | 10 Regular | Info secundaria, unidades. |
| `type.monoLarge` | 13 Medium **Monospaced** | Valores de dimensión en barras. |
| `type.mono` | 10 Medium **Monospaced** | Lecturas numéricas pequeñas. |
| `type.numberLive` | 34 Regular **Monospaced** | **Número vivo** grande en viewport (Patrón 3), color brasa. |
| `type.toolLabel` | 8 Medium | Labels de icono en rail/mode bar. |

### 4.2 Leyes tipográficas (auditables)

1. **Toda cifra es monospaced, siempre.** Una medida que baila al pasar de 9.9 a 10.0
   es amateur.
2. **Labels de grupo: 10pt UPPERCASE, tracking +8%** — voz de instrumento de precisión.
3. **Máximo 2 pesos por pantalla** (Regular + Semibold). El énfasis lo da el
   color-estado, no el peso.
4. **Número vivo** (`type.numberLive`): brasa mientras se edita, se enfría a `steel` al
   confirmar. La unidad va en `type.caption` gris al lado.
5. Español, técnico, seco, 2–4 palabras. "Cara seleccionada · 24.00 mm". Sin
   exclamaciones, sin "¡Genial!".

---

## 5. Espaciado — grid base 4pt

| Token | pt |
|---|---|
| `space.0` | 0 |
| `space.1` | 4 |
| `space.2` | 8 |
| `space.3` | 12 |
| `space.4` | 16 |
| `space.5` | 20 |
| `space.6` | 24 |
| `space.8` | 32 |
| `space.10` | 40 |
| `space.12` | 48 |

**Jerarquía por AIRE, no por líneas** (Patrón 5). Los grupos se separan con
`space.4`/`space.6`, no con divisores. Prohibido cualquier padding fuera del grid.

---

## 6. Corner radius

| Token | pt | Uso |
|---|---|---|
| `radius.none` | 0 | — |
| `radius.sm` | 6 | Chips, tooltips, botones pequeños, HUD inline. |
| `radius.md` | 10 | Cards, paneles de vidrio, flyouts, barras. |
| `radius.lg` | 14 | Modales, sheets, glass panels grandes. |
| `radius.xl` | 20 | Contenedor exterior del viewport (solo borde). |
| `radius.full` | 999 | Píldoras, círculos, chips-pill. |

**Prohibido** cualquier radio fuera de esta lista (el C10 detectó 3/4/5/16/22 sueltos —
todos migran a estos tokens).

---

## 7. Elevación / sombras

| Token | Sombra (color / radio / y) | Uso |
|---|---|---|
| `elevation.none` | — | Plano. |
| `elevation.level1` | negro 15% / 4 / 1 | Cards sobre `bg.base`. |
| `elevation.level2` | negro 25% / 12 / 3 | **Paneles de vidrio sobre viewport** (default). |
| `elevation.level3` | negro 35% / 20 / 6 | Modales, popovers. |
| `elevation.level4` | negro 45% / 28 / 8 | Tooltips, menús contextuales. |

Solo sombra negra semitransparente. El único "resplandor" permitido es el glow de
estado (§3.4), que es información, no sombra.

---

## 8. Iconografía (SF Symbols)

| Token | pt | Uso |
|---|---|---|
| `icon.sm` | 12 | Decorativos, indicadores. |
| `icon.md` | 17 | Botones de rail / mode bar. |
| `icon.lg` | 24 | Acciones destacadas. |
| `icon.xl` | 32 | Empty states. |
| `icon.xxl` | 56 | Onboarding. |

**Pesos:**
- Icono inactivo: `.regular`, color `text.tertiary`.
- Icono activo/seleccionado: `.medium`, color `ember`.
- Icono deshabilitado: `.regular`, opacidad 0.35.

**Escala SF Symbols:** `.medium` scale por defecto en rail; `.large` en acciones
destacadas. Iconos de HERRAMIENTA propios cuando SF no exista: trazo 1.5pt, esquinas
vivas para herramientas exactas (acero), terminaciones redondeadas para pinceles
(arcilla) — la dualidad llega hasta el icono.

**Touch targets:** mínimo `44pt` (HIG); cómodo `48pt`. Todo botón interactivo lo cumple.

---

## 9. Estados de componente (obligatorio para cada control)

Todo control interactivo define los 8 estados. Ninguno se omite.

| Estado | Tratamiento visual |
|---|---|
| **normal** | icono `text.tertiary` / texto `text.secondary`; fondo transparente o `bg.glass`. |
| **hover** (Pencil/trackpad) | fondo `bg.overlay`; sin cambio de color de icono. |
| **pressed** | escala 0.96 (spring); fondo `ember.glow` al 12%; haptic `light`. |
| **selected / active** | icono `ember` `.medium`; fill `ember` 15%; borde `ember` 30% 1px; en operación, glow §3.4. |
| **disabled** | opacidad 0.35; sin haptic; sin respuesta a tap. |
| **loading** | spinner `ember` sobre el control; label a `text.tertiary`; interacción bloqueada. |
| **error** | borde `error` 1px + haptic `heavy`; mensaje seco en `statusMessage`. |
| **focus** (accesibilidad) | anillo `ember` 2px separado 2pt (VoiceOver/teclado). |

---

## 10. Animaciones (duraciones y curvas)

Toda animación es **spring** (nunca `.linear`, nunca `.easeInOut` puro salvo el decay
del glow). Nada > 400ms.

| Token | Curva | Uso |
|---|---|---|
| `anim.snappy` | spring(response 0.20, damping 0.60) | Micro-interacciones, press, chips. |
| `anim.default` | spring(response 0.30, damping 0.70) | Aparición de paneles, selección. |
| `anim.smooth` | spring(response 0.40, damping 0.80) | Modales, transiciones de pantalla. |
| `anim.glacial` | spring(response 0.50, damping 0.85) | Transiciones grandes (raro). |

**Firmas de motion:**
- **Encendido:** al activar herramienta → fade-in del fill+glow en 150ms. Sin bounce.
- **Templado (glow):** al confirmar → glow `ember→steel`, decay a 0 en **400ms
  easeOut** + haptic `medium` (§3.4). ÚNICA excepción a "todo spring".
- **Aparición de flyout:** `anim.default`, con leve escala 0.96→1.0.

**Límites duros:** interactivo ≤200ms (`snappy`/`default`); modal ≤350ms (`smooth`);
transición de pantalla ≤400ms. Viewport 60fps mínimo, UI 120fps.

---

## 11. Componentes canónicos (el catálogo — no se inventan otros)

Cada componente usa EXCLUSIVAMENTE tokens de arriba. Specs resumidas; el código Swift
se genera desde `design_tokens.json` + estas specs.

- **11.1 `GlassPanel`** — receta §3.1. Todo panel flotante. Nunca sin borde ni sombra.
- **11.2 `ToolButton`** — rail. 48pt, icono `icon.md`, label `type.toolLabel` opcional,
  8 estados §9, haptic `light`/`selection`.
- **11.3 `ToolFlyout`** — al mantener/tap en `ToolButton`: `GlassPanel` con lista de
  icono+label (patrón Shapr3D, vidrio Forge). `anim.default`.
- **11.4 `ParamBar`** — barra efímera de parámetro. `GlassPanel` opacidad 0.80, glow de
  estado §3.4, contiene el número vivo (`type.numberLive`), botones Aplicar/Cancelar.
  Aparece junto al efecto, desaparece al aplicar.
- **11.5 `LiveNumber`** — `type.numberLive` brasa + unidad `type.caption` gris.
  Monospaced. Se enfría a `steel` al confirmar.
- **11.6 `Chip` / `PillSelector`** — selector de opción. `radius.full`, `type.caption`,
  activo = `ember` 20% fill + `ember` 30% borde. Haptic `selection`.
- **11.7 `ModeBar`** — inferior, 56pt, `GlassPanel`, icono+label, modo activo `ember`.
- **11.8 `InlineHUD`** — cota/dato SOBRE la geometría: `GlassPanel` opacidad 0.65,
  `radius.sm`, `type.mono`, padding mínimo. Estilo píldora `ref-15`.
- **11.9 `ElementRow`** — fila de la lista de elementos: icono de tipo (⬡ steel / 〰
  clay), nombre `type.body`, ojo de visibilidad, hover `bg.overlay`.
- **11.10 `SurfaceCard`** — card opaca `bg.raised` + `elevation.level1` para pantallas
  sin viewport (settings/export).

**AI-slop prohibido:** confetti, partículas aleatorias, rotación lúdica de iconos,
emojis, gradientes decorativos, iconos que giran al tocar. Detectados en C10 — no
vuelven.

---

## 12. Checklist de conformidad (gate antes de mergear UI)

- [ ] Cero colores fuera de §1 (grep de hardcodeados = 0).
- [ ] Cero radios fuera de §6. Cero paddings fuera del grid §5.
- [ ] Todo panel sobre viewport es `GlassPanel` (ningún opaco sobre `bg.canvas`).
- [ ] El modelo es el punto más brillante; chrome ≤15%.
- [ ] Una sola cosa caliente (un glow) a la vez.
- [ ] Toda cifra monospaced. Máx 2 pesos/pantalla. Group labels UPPERCASE +8%.
- [ ] Cada control define sus 8 estados §9 y dispara haptic.
- [ ] Toda animación es spring, ≤400ms; solo el glow-decay usa easeOut.
- [ ] Sin emojis, confetti, gradientes decorativos, strings de debug.
- [ ] El cambio respeta el contrato de gestos (`DISENO_INTERFAZ.md`).
