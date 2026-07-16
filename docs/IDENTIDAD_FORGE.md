# IDENTIDAD FORGE — Acero & Brasa
> 2026-07-08 · Sistema de identidad visual v2. Sustituye la dirección estética de
> DESIGN_SYSTEM_C10 (que unificó tokens pero heredó el alma de Shapr3D: su azul).
> Los tokens viven en `Sources/Theme/AppTheme.swift`; este doc define el PORQUÉ y las
> reglas de articulación con lo funcional. Se lee junto a BLUEPRINT_UX_SUPREMACIA.md.

---

## 1. El concepto: la Forja

La app se llama AppForge y su superpoder es único en el mercado: **dos materiales en una
mesa de trabajo** — el sólido exacto (CAD/B-rep) y la forma libre (malla esculpible).
La identidad visual no decora ese concepto: LO CUENTA.

> **El taller es frío y oscuro. Lo que estás trabajando está al rojo.**

- **ACERO** (frío, azul-grafito): el mundo en reposo — chrome, paneles, geometría exacta,
  medidas, precisión. Todo lo confiable y estable es acero.
- **BRASA** (ember, naranja fundido): el calor de trabajo — la selección activa, el número
  vivo bajo el dedo, el pincel encendido, la operación en preview. **Calor = "esto está
  siendo modificado AHORA"**. Nada decorativo lleva brasa: si brilla naranja, responde al tacto.
- **El templado**: la firma de la app. Al confirmar una operación, el elemento se enfría
  — un flash brasa→acero de ~400ms. Confirmación visual sin toasts: el metal se templó,
  la operación es sólida. (Motion, ver §6.)

Ninguna app de la competencia tiene narrativa material: Shapr3D es azul corporativo,
Nomad es gris utilitario. Nosotros tenemos una FÍSICA visual.

## 2. Articulación con lo funcional (la regla que lo gobierna todo)

El color comunica ESTADO, jamás decora:

| Señal | Significado funcional | Dónde |
|---|---|---|
| Brasa `#FF7A45` | "activo / editándose / responderá a tu dedo" | selección, herramienta activa, número vivo, drag en curso, pincel |
| Brasa profunda `#D9541E` | "destructivo pero intencional" | excavar/pocket, boolean subtract, hornear |
| Acero `#6FA3D0` | "material exacto (B-rep vivo)" | edge-overlay de sólidos, badge ⬡, cotas, valores confirmados |
| Arcilla `#C79A6B` | "material libre (malla esculpible)" | badge 〰, wireframe tenue de mallas al seleccionar |
| Grafitos fríos | "reposo, estructura" | todo el chrome |
| Verde/ámbar/rojo semánticos | éxito / atención / error — SOLO sistema | toasts, validaciones |

Consecuencias directas (esto es lo que "articula"):
1. **La regla de oro del blueprint (§3.1) se VE**: los objetos exactos dibujan aristas
   acero; los libres no tienen aristas y su selección tiñe arcilla. El usuario distingue
   el contrato de tacto de cada objeto ANTES de tocarlo.
2. **El adaptive menu hereda el calor**: la barra contextual aparece con un borde-brasa
   de 1px que se templa a acero al confirmar. La UI dice "estoy escuchando" sin texto.
3. **Nunca dos brasas**: solo UNA cosa puede estar caliente a la vez (la edición activa).
   Si hay dos elementos naranjas en pantalla, es un bug de diseño.
4. **Los ejes XYZ conservan su convención universal** (R/G/B) — la precisión no se toca.

## 3. Paleta (tokens en AppTheme.swift)

### Fondos — "taller de noche" (fríos, OLED)
| Token | Hex | Uso |
|---|---|---|
| bgCanvas | `#0A0B10` | viewport — el negro más profundo de la app; el modelo es el héroe |
| bgBase | `#12141A` | superficies principales |
| bgRaised | `#1A1D26` | cards, paneles elevados |
| bgOverlay | `#222630` | hover/estados activos |
| bgGlass | `#1B1E28` | base de paneles vidrio |

(Deriva fría sutil respecto a C10: +2 puntos de azul en los grafitos — taller, no vacío.)

### Brasa (accent — reemplaza el azul heredado de Shapr3D)
| Token | Hex | Uso |
|---|---|---|
| accentColor / ember | `#FF7A45` | acción activa, selección, foco |
| accentGlow / emberGlow | `#FFA06B` | glow de estados presionados, gradiente cálido |
| accentMuted / emberDeep | `#D9541E` | variante profunda: destructivo-intencional |

### Materiales (NUEVO — el corazón de la identidad)
| Token | Hex | Uso |
|---|---|---|
| steel | `#6FA3D0` | material exacto: edges, badges, cotas |
| steelBright | `#8FBCE4` | acero enfatizado (selección de cara exacta) |
| clay | `#C79A6B` | material libre: badges, tint de selección de malla |

### Texto y bordes
Sin cambios estructurales respecto a C10 (jerarquía de 3 niveles) — el texto es
instrumento, no protagonista. `textPrimary #F0F1F5`, `textSecondary #9AA0B0`,
`textTertiary #5A5F6E`, `border #2A2E3A`.

## 4. Tipografía — "instrumental"

SF Pro (nativo = rendimiento y familiaridad iOS; la personalidad no va en la fuente,
va en las REGLAS):
1. **Toda cifra es monospaced, siempre** (`Typography.mono*`). Una medida que baila
   al cambiar de 9.9 a 10.0 es amateur. Ya existe el token: hacerlo LEY (auditar vistas).
2. **Labels de grupo: 10pt UPPERCASE tracking +8%** — voz de instrumento de precisión
   (estilo panel aeroespacial), no de app de consumo.
3. Máximo 2 pesos por pantalla (regular + semibold). El énfasis lo da el color-estado, no el peso.
4. Números grandes en vivo (push/pull, radio de pincel): `monoLarge` escalado ×2, color brasa.

## 5. Materialidad — "vidrio de taller"

UN solo material para todo panel flotante (ya existe `glassPanel()` — canonizarlo):
`ultraThinMaterial` + borde 1px `border` + sombra `Elevation.level2`. Nada más.
- Prohibido: gradientes decorativos, sombras de colores, blur excesivo. El único glow
  permitido es el de brasa en estados activos (es información, no adorno).
- Los paneles NUNCA superan al modelo en contraste: el viewport es el punto más oscuro
  y el modelo lo más iluminado (render PBR/IBL hace ese trabajo).
- Grid del viewport: sutilísimo, se desvanece al acercar (adaptive grid ya existe en
  ViewportFeatures) — jamás compite con la geometría.

## 6. Motion — "física de taller" (firma: el templado)

Los presets spring de C10 se conservan (animDefault/Snappy/Smooth). Se añade la firma:

- **Templado (`tempered`)**: al confirmar operación → overlay brasa al 60% → decay a 0
  en 400ms curva easeOut + haptic medium. UN solo efecto de firma, usado en: aplicar
  push/pull, boolean, fillet, hornear, validar sketch. (Componente en Components.swift, ola 2.)
- **Encendido**: al seleccionar/activar herramienta → 150ms fade-in del borde brasa. Sin bounce.
- Regla: el motion confirma física (algo se aplicó, algo se encendió). Nada se anima
  "porque se ve bonito". Duración máxima de cualquier animación de UI: 400ms.

## 7. Iconografía y voz

- Base SF Symbols (consistencia iOS, gratis). Iconos de HERRAMIENTA propios cuando el
  símbolo no exista: trazo 1.5pt, esquinas vivas para herramientas exactas, terminaciones
  redondeadas para pinceles de sculpt — la dualidad acero/arcilla llega hasta el icono.
- El icono de "hornear" 🔥→cubo es nuestro y debe ser memorable (marca del Forge Flow).
- Voz de la UI: español, técnico y seco, 2-4 palabras. "Cara seleccionada · 24.00 mm".
  Nunca exclamaciones, nunca "¡Genial!". La app es un instrumento, no un amigo.

## 8. Modo claro

Dark-first SIEMPRE (es un taller). El modo claro existe por accesibilidad (tokens light
de C10 se conservan) pero la identidad se define en oscuro; la brasa funciona en ambos.

## 9. Checklist de implementación
- [x] Tokens Acero & Brasa en AppTheme.swift (2026-07-08, esta ola)
- [ ] Ola 2: `tempered()` modifier + auditoría "nunca dos brasas" + edge-overlay acero
      en objetos exactos + labels uppercase tracking (barra por barra)
- [ ] Ola 2: purga de los ~15 colores hardcodeados que C10 detectó (§1.2 items 5-9)
      → tokens semánticos
- [ ] Ola 4 (Forge Flow): badges de material ⬡/〰 con steel/clay
- [ ] Icono de app nuevo: cubo con arista al rojo (brasa) sobre grafito
