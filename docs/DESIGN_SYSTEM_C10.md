# DESIGN_SYSTEM_C10 — Auditoría de Diseño & Design System para Superioridad Estética

**Fecha:** 2026-06-11
**Propósito:** Mejora C10 de `docs/PLAN_V1_SUPREMACIA.md` — Superar estéticamente a Shapr3D, Nomad Sculpt y Feather3D
**Método:** Auditoría de código real (solo lectura) + benchmark de competencia + propuesta de design system unificado

---

## 1. Hallazgos de Auditoría

### 1.1 TRES sistemas de diseño conviviendo (CRÍTICO)

El proyecto tiene **tres definiciones de theme incompatibles** en paralelo:

| # | Ubicación | Estructura | Estado |
|---|-----------|-----------|--------|
| A | `Core/UI/AppTheme.swift` + `ThemeManager.swift` + `AppThemeEnvironment.swift` | Simple: colores (system colors) + metalBackground. Sin tokens tipográficos ni espaciado. | **Usado** por mayoría de vistas Core |
| B | `Sources/Theme/AppTheme.swift` + `ThemeManager.swift` + `AppThemeEnvironment.swift` | Evolucionado: hex colors, font tokens (titleFont/bodyFont/captionFont), corner radii (8/12/20), elevation, icon sizes | **Usado** por ToolbarView, ModeSelectorView, AnimationView, ExportView, etc. |
| C | `Core/Theme/AppForgeTheme.swift` | Más completo: paleta OLED, 8pt grid spacing (spXXS..spXXL), 4 radii (6/10/14/20), tipografía funcional (title/heading/label/mono), modifiers (GlassPanel, ToolbarGlow, SurfaceCard, springPress) | **Usado SOLO** en `AppForgeStudioApp.swift` (WorkspaceView, LeftToolbar, etc.) |

**Severidad:** CRÍTICA. Tres sistemas = imposible consistencia. El sistema C (`AppForgeTheme`) es el más cercano a calidad "pro" pero está aislado del resto.

### 1.2 Tabla de Inconsistencias Detectadas

| # | Archivo:línea | Inconsistencia | Severidad |
|---|---------------|----------------|-----------|
| 1 | `Core/UI/AppTheme.swift:6` vs `Sources/Theme/AppTheme.swift:13` | Dos definiciones de `struct AppTheme` con implementaciones diferentes (system colors vs hex colors). Mismo nombre, distinto módulo — el compilador usa una u otra según el import. | CRÍTICA |
| 2 | `Core/UI/ThemeManager.swift:29` vs `Sources/Theme/ThemeManager.swift:28` | Dos `ThemeManager` idénticos. El de Sources inyecta `.dark` fijo; el de Core respeta UserDefaults. | CRÍTICA |
| 3 | `Core/UI/HybridModeView.swift:5` vs `Features/HybridMode/HybridModeView.swift:3` | Dos `HybridModeView` diferentes. Core tiene toolVM.executeTool(on:); Features tiene lógica inline de subdivision. | ALTA |
| 4 | `Core/UI/ContentView.swift:9` vs `Features/CADMode/ContentView.swift:3` | Dos `ContentView`: Core usa `MetalView`, CADMode usa `SatinView` (wrapper distinto). Mismo nombre, distinto render pipeline. | ALTA |
| 5 | `CADModeView.swift:267` | `.background(Color.green.opacity(0.3))` — color hardcodeado para primitivas, no usa ningún token de theme. | ALTA |
| 6 | `CADModeView.swift:347,362,377,392,404,419,425` | 7 colores de fondo hardcodeados para parameter bars: `.blue.opacity(0.15)`, `.orange.opacity(0.15)`, `.green.opacity(0.15)`, `.purple.opacity(0.15)`, `.yellow.opacity(0.12)`, `.mint.opacity(0.12)`. Sin token semántico. | ALTA |
| 7 | `OnboardingView.swift:106` | `.background(Color.blue)` + `.cornerRadius(16)` — color y radio hardcodeados, ignora `theme.accent` y `theme.cornerRadiusLarge`. | ALTA |
| 8 | `SculptModeView.swift:87` | `.background(Color.blue).foregroundColor(...).cornerRadius(6)` — botón "Aplicar" con color y radio hardcodeados. | ALTA |
| 9 | `ExportView.swift:145,163,183` | `.background(Color.accentColor).cornerRadius(12)`, `.background(Color.green).cornerRadius(12)`, `.background(Color.accentColor.opacity(0.2)).cornerRadius(10)` — 3 botones con radios y colores hardcodeados. | ALTA |
| 10 | `SculptModeView.swift:39,93` | `themeManager.isDarkMode ? Color.black.opacity(0.5) : themeManager.currentTheme.surface` — Lógica ternaria manual de dark/light en vez de usar el theme. | ALTA |
| 11 | `ContentView.swift:45` | `Text("Mode: \(canvasVM.currentMode.rawValue)")` — String de debug en producción, sin localizar, con `.cornerRadius(4)` hardcodeado. | MEDIA |
| 12 | `CADModeView.swift:163-168,266-268,302-306` | `.cornerRadius(5)` usado 6+ veces en CADModeView — no es ninguno de los tokens (8/12/20 en AppTheme, 6/10/14/20 en AppForgeTheme). | MEDIA |
| 13 | `CADSketchView.swift:83,106` | `.cornerRadius(5)` en sketch toolbar — igual, fuera de cualquier sistema de tokens. | MEDIA |
| 14 | `CADModeView.swift:267` | `.font(.system(size: 9))`, `.font(.system(size: 8))` — tamaños de fuente arbitrarios sin usar tokens tipográficos. | MEDIA |
| 15 | `AnimationView.swift:144` | `.cornerRadius(6)` en easing picker buttons — valor no estandarizado. | MEDIA |
| 16 | `ConstraintsOverlayView.swift:148` | `.cornerRadius(6)` en snap indicator — otro valor no estandarizado. | MEDIA |
| 17 | `ToolMenuView.swift:32` | `.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))` — corner radius 22 es único en toda la app, no coincide con ningún token. | BAJA |
| 18 | `AppForgeStudioApp.swift:221` | `.cornerRadius(3)` en PillLabel — radio 3px, el más pequeño de la app. | BAJA |
| 19 | `ContentView.swift:27` | `.edgesIgnoringSafeArea(.all)` en MetalView — ignora safe area sin considerar notch/island del iPad. | BAJA |
| 20 | `LoadingScreenView.swift:18` | `.progressViewStyle(CircularProgressViewStyle(tint: .white))` — color white hardcodeado para loading. | BAJA |
| 21 | `LoadingScreenView.swift:21` | `Text('Cargando modelo 3D...')` — usa comillas tipográficas incorrectas (Unicode RIGHT SINGLE QUOTATION MARK en vez de comillas dobles). Error de sintaxis potencial. | BAJA |
| 22 | `ToolMenuView.swift:31` vs `ToolbarView.swift:76` | ToolMenu usa `.shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)`, Toolbar usa `.shadow(color: .black.opacity(0.15), radius: theme.elevation * 2, y: 2)`. Sombras inconsistentes. | BAJA |
| 23 | `AppForgeStudioApp.swift` completo | Usa `AppForgeTheme` (sistema C) con glass panels, spring animations, 8pt grid — pero NINGUNA otra vista del proyecto usa este sistema. UI del Workspace es cualitativamente diferente al resto. | ALTA |
| 24 | Todo el proyecto | Mezcla español/inglés sin patrón: "Deshacer" al lado de "Snap", "Resetear vista" al lado de "Loop", "Seleccionar" vs "Select". Sin `LocalizedStringKey`. | MEDIA |
| 25 | `TransformationGizmoView.swift:46` | `.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))` — material con radio 16, sin el border stroke ni shadow que GlassPanel de AppForgeTheme provee. | MEDIA |

### 1.3 Problemas Estructurales Detectados

**A. Duplicación de archivos de tema (6 archivos para 1 concepto)**
```
Core/UI/AppTheme.swift          ← copia A (simple)
Core/UI/AppThemeEnvironment.swift ← copia A
Core/UI/ThemeManager.swift      ← copia A
Sources/Theme/AppTheme.swift    ← copia B (evolucionada)
Sources/Theme/AppThemeEnvironment.swift ← copia B
Sources/Theme/ThemeManager.swift ← copia B
Core/Theme/AppForgeTheme.swift  ← copia C (la mejor, aislada)
```

**B. Vistas duplicadas con implementaciones divergentes**
- `HybridModeView` existe en `Core/UI/` y `Features/HybridMode/`
- `ContentView` existe en `Core/UI/` y `Features/CADMode/`

**C. Patrones AI-slop detectados**
- `ConfettiView` en ExportView: partículas animadas con colores aleatorios — efecto "genérico de app tutorial", no comunica función CAD.
- `rotationEffect` en icono de export (tap-to-spin): interacción lúdica out of place en herramienta profesional.
- Densidad de información extremadamente baja en OnboardingFlow del AppForgeStudioApp vs OnboardingView (dos onboardings diferentes con estilos opuestos).

**D. Lo que SÍ está bien**
- `AppForgeTheme` (`Core/Theme/AppForgeTheme.swift`) es genuinamente bueno: paleta oscura OLED-friendly, 8pt grid, glass-morphism controlado, tipografía funcional, modifiers reusables. Es la base correcta.
- `HapticService` bien diseñado: singleton con 4 niveles de feedback háptico, usado consistentemente.
- `ToolbarView` en `Core/UI/` usa correctamente los tokens de `Sources/Theme/AppTheme.swift` (cornerRadiusMedium, captionFont, iconSizeSmall, etc.).
- `ModeSelectorView` muestra buen uso de theme tokens y transiciones.

---

## 2. Benchmark de Competencia

### 2.1 Shapr3D — Minimalismo Industrial de Precisión

**Patrones observados (basado en conocimiento público, no verificado contra build actual jun-2026):**

| Principio | Implementación |
|-----------|---------------|
| **Toolbar lateral adaptativo** | Sidebar izquierda de ~48px con iconos monocromáticos. Sin texto hasta hover/long-press. El viewport ocupa ≥85% de la pantalla. |
| **Viewport-first** | La UI permanente es mínima: toolbar izquierda + barra inferior de modos. Paneles de propiedades aparecen como overlays flotantes contextuales, no como paneles fijos. |
| **Tipografía industrial** | SF Pro en pesos Semibold/Regular. Sin serifs, sin rounded, sin decoración. Números monoespaciados para dimensiones. |
| **Paleta monocromática con acento** | Grises fríos (#1C1C1E, #2C2C2E, #3A3A3C) + un solo acento azul (#4DA3FF). Sin gradientes decorativos. |
| **Glass-morphism funcional** | Paneles flotantes usan `.ultraThinMaterial` + borde sutil (0.5px, 15% opacity) + shadow. No es decorativo: el blur permite ver geometría debajo. |
| **Gestos como lenguaje primario** | Pinch-to-zoom, 2-finger pan, 3-finger rotate. La UI es respaldo, no protagonista. |
| **HUD de constraints** | Distancias y ángulos aparecen in-situ sobre el modelo durante sketching, no en panel separado. |
| **120Hz consistente** | Toda animación usa spring (response 0.3-0.4, damping 0.7-0.8). Nada lineal. Nada >200ms. |
| **Sin emojis, sin confetti** | Cero decoración no funcional. La "belleza" viene de la precisión y el espacio negativo. |

**Extracción de principios para AppForge:**
1. Viewport ≥85% screen real estate. UI es visitante, no residente.
2. Un solo color de acento. Semántica por posición/forma, no por color.
3. Tipografía SF Pro sin adornos. Mono para números.
4. Glass panels con borde sutil + shadow, no opacos.

### 2.2 Nomad Sculpt — Dark UI con Paneles Flotantes

| Principio | Implementación |
|-----------|---------------|
| **Dark-first, OLED-optimizado** | Fondo #000000 puro o casi. Los paneles flotan sobre el viewport con translucidez. |
| **Paneles colapsables** | El panel de brushes se expande/colapsa con swipe. Solo visible cuando se esculpe activamente. |
| **Iconografía grande y táctil** | Botones de ≥44pt touch target. Iconos SF Symbols en tamaño generoso (~24pt). |
| **HUD de parámetros en viewport** | Brush size, strength, symmetry — mostrados como overlay semitransparente sobre el modelo, no en toolbar. |
| **Topología visual en viewport** | Wireframe overlay, polycount HUD, máscaras coloreadas directamente sobre la geometría. |
| **Simetría visualizada** | Plano de simetría renderizado como plano semitransparente en el viewport, no como toggle abstracto. |

**Extracción para AppForge:**
1. Dark-first sin concesiones. El viewport 3D es oscuro; la UI debe integrarse, no contrastar agresivamente.
2. Paneles colapsables con gesture, no botones de toggle.
3. Información de escultura EN el viewport (HUD overlay), no en panel lateral.
4. Touch targets generosos para iPad (≥44pt).

### 2.3 Feather3D — Simplicidad Lúdica

| Principio | Implementación |
|-----------|---------------|
| **Onboarding integrado** | Tutorial interactivo donde el usuario realiza la acción (no solo lee slides). |
| **Botones grandes con labels** | A diferencia de Shapr3D, Feather usa icono + texto en toolbar. Prioriza descubribilidad sobre minimalismo. |
| **Paleta cálida** | Acentos en naranja/ámbar, fondos gris cálido — menos "frío industrial" que Shapr3D. |
| **Feedback visual inmediato** | Cada acción tiene respuesta: escala, color, haptic. Nada es silencioso. |
| **Modo "simple" default** | Herramientas avanzadas ocultas detrás de "Advanced" toggle. No abruma al nuevo usuario. |

**Extracción para AppForge:**
1. Barra inferior de modos con icono + label (ya implementado en BottomModeBar de AppForgeStudioApp).
2. Haptic en toda interacción (HapticService ya existe —úsese consistentemente).
3. Progressive disclosure: herramientas avanzadas colapsadas por default.

### 2.4 Principios de Diseño AppForge (Síntesis)

1. **"Viewport es el rey"** — UI translúcida, colapsable, sin paneles fijos que roben pantalla. En iPad 11"/13", el viewport ocupa ≥85% del área. Los paneles son visitantes flotantes.

2. **"Una mano en el iPad"** — Controles críticos alcanzables con el pulgar sosteniendo el iPad. Toolbar izquierda (alcance del pulgar izquierdo), barra inferior de modos (ambos pulgares). Panel de propiedades solo cuando se necesita.

3. **"120Hz sin excusas"** — Toda transición usa spring animations (response 0.25-0.4s, damping 0.6-0.8). Nada lineal. Nada >200ms. El viewport renderiza a 60fps mínimo, la UI a 120fps.

4. **"Dark-first, OLED-friendly"** — Paleta oscura como default y único modo inicial (light mode es accesibilidad, no feature). Fondos cercanos a #000 para ahorrar batería en iPad Pro OLED.

5. **"Un acento, semántica por posición"** — Un solo color de acento (azul #4DA3FF). Las herramientas no se diferencian por color sino por ícono y posición. Colores semánticos (verde=éxito, rojo=destructivo) solo para feedback de sistema.

6. **"Haptic + visual = certeza"** — Toda interacción tiene respuesta háptica (light/medium/heavy/selection) + animación visual. Nada es silencioso. El usuario siempre sabe que la acción se registró.

7. **"Progressive disclosure"** — Herramientas frecuentes visibles. Avanzadas a un tap de profundidad. El nuevo usuario ve 6 botones; el experto accede a 30 con gestures y menús contextuales.

---

## 3. Design Tokens Propuestos

### 3.1 Paleta (Dark-First con Acento)

```swift
// MARK: - AppForge Design Tokens v1.0 (unified)
// Reemplaza a: Core/UI/AppTheme.swift, Sources/Theme/AppTheme.swift, Core/Theme/AppForgeTheme.swift

import SwiftUI

enum AppForgeTokens {
    // ── Backgrounds (dark, layered, OLED-friendly) ──
    static let bgCanvas    = Color(hex: "0A0A0F")  // Deepest: viewport
    static let bgBase      = Color(hex: "121218")  // Main surfaces
    static let bgRaised    = Color(hex: "1A1A24")  // Cards, panels elevados
    static let bgOverlay   = Color(hex: "22222E")  // Hover, active states
    static let bgGlass     = Color(hex: "1C1C28")  // Glass panels base (pre-blur)

    // ── Accent (Shapr3D-inspired blue) ──
    static let accent      = Color(hex: "4DA3FF")
    static let accentMuted = Color(hex: "3A7ACC")
    static let accentGlow  = Color(hex: "6DB9FF")

    // ── Semantic ──
    static let success     = Color(hex: "34D399")
    static let warning     = Color(hex: "FBBF24")
    static let error       = Color(hex: "F87171")
    static let axisX       = Color(hex: "F87171")  // Red
    static let axisY       = Color(hex: "34D399")  // Green
    static let axisZ       = Color(hex: "4DA3FF")  // Blue

    // ── Text ──
    static let textPrimary   = Color(hex: "F0F0F5")
    static let textSecondary = Color(hex: "9A9AB0")
    static let textTertiary  = Color(hex: "5A5A6E")

    // ── Borders ──
    static let border        = Color(hex: "2A2A3A")
    static let borderLight   = Color(hex: "1E1E2E")

    // ── Light mode counterparts (para accesibilidad) ──
    static let lightBgCanvas    = Color(hex: "F2F2F7")
    static let lightBgBase      = Color(hex: "FFFFFF")
    static let lightBgRaised    = Color(hex: "F9F9FB")
    static let lightBgOverlay   = Color(hex: "E5E5EA")
    static let lightTextPrimary = Color(hex: "1C1C1E")
    static let lightTextSecond  = Color(hex: "636366")
    static let lightTextTert    = Color(hex: "AEAEB2")
    static let lightBorder      = Color(hex: "C6C6C8")
}
```

### 3.2 Escala Tipográfica (SF Pro, sin Rounded)

```swift
extension AppForgeTokens {
    // ── Typography (SF Pro, NOT SF Pro Rounded) ──
    // Uso: AppForgeTokens.typography.title
    enum Typography {
        case largeTitle   // 28pt Bold — onboarding headers only
        case title1       // 20pt Semibold — screen titles
        case title2       // 15pt Semibold — section headers
        case heading      // 12pt Medium — group labels
        case body         // 13pt Regular — body text
        case caption      // 10pt Regular — secondary info
        case monoLarge    // 13pt Medium Monospaced — dimension values
        case mono         // 10pt Medium Monospaced — numeric readouts
        case toolLabel    // 8pt Medium — icon labels in toolbar

        var font: Font {
            switch self {
            case .largeTitle: return .system(size: 28, weight: .bold, design: .default)
            case .title1:     return .system(size: 20, weight: .semibold, design: .default)
            case .title2:     return .system(size: 15, weight: .semibold, design: .default)
            case .heading:    return .system(size: 12, weight: .medium, design: .default)
            case .body:       return .system(size: 13, weight: .regular, design: .default)
            case .caption:    return .system(size: 10, weight: .regular, design: .default)
            case .monoLarge:  return .system(size: 13, weight: .medium, design: .monospaced)
            case .mono:       return .system(size: 10, weight: .medium, design: .monospaced)
            case .toolLabel:  return .system(size: 8, weight: .medium, design: .default)
            }
        }
    }
}
```

### 3.3 Espaciado (4pt Grid)

```swift
extension AppForgeTokens {
    // ── Spacing (4pt grid) ──
    static let space0:  CGFloat = 0
    static let space1:  CGFloat = 4
    static let space2:  CGFloat = 8
    static let space3:  CGFloat = 12
    static let space4:  CGFloat = 16
    static let space5:  CGFloat = 20
    static let space6:  CGFloat = 24
    static let space8:  CGFloat = 32
    static let space10: CGFloat = 40
    static let space12: CGFloat = 48
}
```

### 3.4 Corner Radii

```swift
extension AppForgeTokens {
    // ── Radii (geometric progression) ──
    static let radiusNone: CGFloat = 0
    static let radiusSM:   CGFloat = 6   // Chips, tooltips, small buttons
    static let radiusMD:   CGFloat = 10  // Cards, panels, sheets
    static let radiusLG:   CGFloat = 14  // Modals, glass panels
    static let radiusXL:   CGFloat = 20  // Viewport container (solo borde exterior)
    static let radiusFull: CGFloat = 999 // Píldoras, círculos
}
```

### 3.5 Iconografía

```swift
extension AppForgeTokens {
    // ── Icon Sizes ──
    static let iconSM:  CGFloat = 12  // Decorativos, indicadores
    static let iconMD:  CGFloat = 17  // Toolbar buttons
    static let iconLG:  CGFloat = 24  // Featured actions
    static let iconXL:  CGFloat = 32  // Empty states
    static let iconXXL: CGFloat = 56  // Onboarding

    // ── SF Symbols Weights ──
    // Toolbar icons: .system(size: iconMD, weight: .regular)
    // Active tool:   .system(size: iconMD, weight: .medium)
    // Disabled:       .system(size: iconMD, weight: .regular) + opacity 0.35

    // ── Touch Targets (HIG mínimo: 44pt) ──
    static let touchMin: CGFloat = 44
    static let touchComfortable: CGFloat = 48
}
```

### 3.6 Sombras / Elevación

```swift
extension AppForgeTokens {
    // ── Elevation (shadow presets) ──
    // Uso: .modifier(AppForgeTokens.Elevation.level1)
    enum Elevation {
        case none
        case level1  // Cards sobre bgBase
        case level2  // Panels flotantes sobre viewport
        case level3  // Modals, popovers
        case level4  // Tooltips, menus contextuales

        var shadow: (color: Color, radius: CGFloat, y: CGFloat) {
            switch self {
            case .none:    return (.clear, 0, 0)
            case .level1:  return (.black.opacity(0.15), 4, 1)
            case .level2:  return (.black.opacity(0.25), 12, 3)
            case .level3:  return (.black.opacity(0.35), 20, 6)
            case .level4:  return (.black.opacity(0.45), 28, 8)
            }
        }
    }
}
```

### 3.7 Animaciones

```swift
extension AppForgeTokens {
    // ── Animation Presets ──
    static let animDefault   = Animation.spring(response: 0.30, dampingFraction: 0.70)
    static let animSnappy    = Animation.spring(response: 0.20, dampingFraction: 0.60)
    static let animSmooth    = Animation.spring(response: 0.40, dampingFraction: 0.80)
    static let animGlacial   = Animation.spring(response: 0.50, dampingFraction: 0.85)

    // ── Duration limits ──
    // MAX interactive transition: 200ms (animSnappy/animDefault)
    // MAX modal present: 350ms (animSmooth)
    // MAX page transition: 400ms (animSmooth)
    // NEVER: .linear, .easeInOut (sin spring no hay calidad percibida)
}
```

---

## 4. Componentes Canónicos

### 4.1 GlassPanel (Panel Flotante Translúcido)

```swift
// Reemplaza: ToolMenuView, TransformationGizmoView, FloatingParams, MiniViewCube
// Specs exactas:
// - Fondo: .ultraThinMaterial + bgGlass (0.85 opacity)
// - Radio: radiusMD (10pt)
// - Borde: border, 0.5px
// - Sombra: Elevation.level2
// - Padding interno: space3 (12pt)
// - Transición: animDefault al aparecer/desaparecer
// - NO usar sin el border stroke (error común actual)
struct GlassPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(AppForgeTokens.bgGlass)
            .cornerRadius(AppForgeTokens.radiusMD)
            .overlay(
                RoundedRectangle(cornerRadius: AppForgeTokens.radiusMD)
                    .stroke(AppForgeTokens.border, lineWidth: 0.5)
            )
            .shadow(color: AppForgeTokens.Elevation.level2.shadow.color,
                    radius: AppForgeTokens.Elevation.level2.shadow.radius,
                    y: AppForgeTokens.Elevation.level2.shadow.y)
    }
}
```

### 4.2 ToolButton (Botón de Herramienta en Toolbar)

```swift
// Specs:
// - Touch target: 44x44pt mínimo, 48x48pt comfort
// - Icono: SF Symbol, iconMD (17pt), weight .regular → .medium al activarse
// - Label: toolLabel (8pt Medium), opcional (visible solo si hay espacio)
// - Fondo activo: accent.opacity(0.15)
// - Borde activo: accent.opacity(0.30), 1px
// - Radio: radiusSM (6pt)
// - Haptic: .light() en press, .selection() si cambia herramienta
// - NO color hardcodeado distinto de accent para activo
struct ToolButton: View {
    let icon: String
    let label: String?
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticService.shared.light()
            action()
        }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: AppForgeTokens.iconMD,
                                  weight: isActive ? .medium : .regular))
                    .frame(width: AppForgeTokens.touchComfortable,
                           height: AppForgeTokens.touchComfortable)
                if let label = label {
                    Text(label)
                        .font(AppForgeTokens.Typography.toolLabel.font)
                        .lineLimit(1)
                }
            }
            .foregroundColor(isActive ? AppForgeTokens.accent : AppForgeTokens.textTertiary)
            .background(isActive ? AppForgeTokens.accent.opacity(0.15) : Color.clear)
            .cornerRadius(AppForgeTokens.radiusSM)
            .overlay(
                RoundedRectangle(cornerRadius: AppForgeTokens.radiusSM)
                    .stroke(isActive ? AppForgeTokens.accent.opacity(0.30) : Color.clear,
                            lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? icon)
    }
}
```

### 4.3 ParamSlider (Slider de Parámetro con Label)

```swift
// Specs:
// - Label: Typography.caption (10pt Regular), textTertiary
// - Value: Typography.mono (10pt Medium Monospaced), textPrimary
// - Slider: tint accent, height estándar
// - Espaciado interno: space2 (8pt) entre elementos
// - NO colores hardcodeados por tipo de parámetro (extrude≠blue, fillet≠orange)
// - Color del parameter bar usa bgOverlay, no colores semánticos
struct ParamSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let unit: String
    let step: Float

    var body: some View {
        VStack(spacing: AppForgeTokens.space2) {
            HStack {
                Text(label)
                    .font(AppForgeTokens.Typography.caption.font)
                    .foregroundColor(AppForgeTokens.textTertiary)
                Spacer()
                Text("\(value, specifier: "%.2f") \(unit)")
                    .font(AppForgeTokens.Typography.mono.font)
                    .foregroundColor(AppForgeTokens.textPrimary)
            }
            Slider(value: $value, in: range, step: Float.Stride(step))
                .tint(AppForgeTokens.accent)
        }
    }
}
```

### 4.4 ModeSelector (Barra de Modos Inferior)

```swift
// Specs:
// - Posición: bottom, fija, glassPanel
// - Altura: 50pt
// - Íconos: iconMD (17pt), modo activo en accent + medium weight
// - Labels: toolLabel (8pt), solo en modo activo semibold
// - Indicador activo: accent.opacity(0.08) fill + radiusSM
// - Haptic: .medium() al cambiar de modo
// - Transición: animDefault
struct ModeSelector: View {
    @Binding var selectedMode: AppMode
    let modes: [(AppMode, String, String)] // (mode, icon, label)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(modes, id: \.0) { mode, icon, label in
                Button(action: {
                    HapticService.shared.medium()
                    withAnimation(AppForgeTokens.animDefault) {
                        selectedMode = mode
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: icon)
                            .font(.system(size: AppForgeTokens.iconMD))
                        Text(label)
                            .font(AppForgeTokens.Typography.toolLabel.font)
                    }
                    .foregroundColor(selectedMode == mode
                        ? AppForgeTokens.accent
                        : AppForgeTokens.textTertiary)
                    .frame(width: 56, height: 44)
                    .background(selectedMode == mode
                        ? AppForgeTokens.accent.opacity(0.08)
                        : Color.clear)
                    .cornerRadius(AppForgeTokens.radiusSM)
                }
            }
        }
        .padding(.horizontal, AppForgeTokens.space2)
        .frame(height: 50)
        .glassPanel()
    }
}
```

### 4.5 HUD Overlay (Información en Viewport)

```swift
// Specs:
// - Posición: overlay sobre el viewport (top-left o bottom-left)
// - Fuente: Typography.mono (datos numéricos), Typography.caption (labels)
// - Fondo: bgBase.opacity(0.7) + .ultraThinMaterial (sutil)
// - Radio: radiusSM (6pt)
// - Padding: space1 (4pt) vertical, space2 (8pt) horizontal
// - Contenido dinámico: FPS, polycount, brush size, herramienta activa
// - Solo visible en modo debug o con gesture (3-finger swipe down)
struct ViewportHUD: View {
    let fps: Int
    let polycount: Int
    let activeTool: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HUDItem(label: "FPS", value: "\(fps)")
            HUDItem(label: "Tris", value: "\(polycount)")
            HUDItem(label: "Tool", value: activeTool)
        }
        .padding(.vertical, AppForgeTokens.space1)
        .padding(.horizontal, AppForgeTokens.space2)
        .background(AppForgeTokens.bgBase.opacity(0.7))
        .background(.ultraThinMaterial)
        .cornerRadius(AppForgeTokens.radiusSM)
    }
}

struct HUDItem: View {
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: AppForgeTokens.space1) {
            Text(label)
                .font(AppForgeTokens.Typography.caption.font)
                .foregroundColor(AppForgeTokens.textTertiary)
            Text(value)
                .font(AppForgeTokens.Typography.mono.font)
                .foregroundColor(AppForgeTokens.textPrimary)
        }
    }
}
```

### 4.6 ChipButton (Selector de Opción)

```swift
// Specs:
// - Tamaño: height 24pt, padding horizontal space2 (8pt)
// - Fuente: Typography.caption (10pt), bold si active, regular si no
// - Fondo activo: accent.opacity(0.20)
// - Borde activo: accent.opacity(0.30), 1px
// - Radio: radiusSM (6pt)
// - Haptic: .selection() al cambiar
struct ChipButton: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticService.shared.selection()
            action()
        }) {
            Text(label)
                .font(isActive
                    ? AppForgeTokens.Typography.caption.font.weight(.bold)
                    : AppForgeTokens.Typography.caption.font)
                .padding(.horizontal, AppForgeTokens.space2)
                .padding(.vertical, 3)
                .background(isActive
                    ? AppForgeTokens.accent.opacity(0.20)
                    : AppForgeTokens.bgOverlay)
                .foregroundColor(isActive
                    ? AppForgeTokens.accent
                    : AppForgeTokens.textSecondary)
                .cornerRadius(AppForgeTokens.radiusSM)
                .overlay(
                    RoundedRectangle(cornerRadius: AppForgeTokens.radiusSM)
                        .stroke(isActive
                            ? AppForgeTokens.accent.opacity(0.30)
                            : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
```

---

## 5. Plan de Aplicación por Olas

### Ola C10.1 — UNIFICAR sistema de design tokens (S, 3 tareas, paralelizable)

| ID | Tarea | Archivos | Qué hacer | Qué NO hacer | Verificación |
|----|-------|----------|-----------|--------------|--------------|
| C10.T1 | **Eliminar duplicados de Theme** | `Core/UI/AppTheme.swift`, `Core/UI/AppThemeEnvironment.swift`, `Core/UI/ThemeManager.swift`, `Sources/Theme/AppTheme.swift`, `Sources/Theme/AppThemeEnvironment.swift`, `Sources/Theme/ThemeManager.swift` | `git rm` los 3 archivos de `Sources/Theme/` (la copia B). Dejar solo `Core/UI/` (copia A). Luego actualizar `Core/UI/AppTheme.swift` con los tokens de `AppForgeTheme` (copia C). | NO borrar `Core/Theme/AppForgeTheme.swift` aún. NO tocar vistas. | `find . -name "AppTheme.swift" | wc -l` = 1. Compilación verde. |
| C10.T2 | **Migrar AppForgeTheme tokens a AppTheme unificado** | `Core/UI/AppTheme.swift` | Fusionar design tokens de `AppForgeTheme` (paleta OLED, spacing, radii, typography, elevation) dentro de `AppTheme`, manteniendo compatibilidad con `@Environment(\.appTheme)`. | NO crear un cuarto sistema. NO romper la API existente de `ThemeManager`. | `git grep "AppForgeTheme"` solo en `Core/Theme/AppForgeTheme.swift` (legacy, a eliminar en T3). Compilación verde. |
| C10.T3 | **Eliminar AppForgeTheme legacy** | `Core/Theme/AppForgeTheme.swift`, `Core/UI/AppForgeStudioApp.swift` | Migrar `AppForgeStudioApp.swift` a usar `AppTheme` unificado (vía `@Environment(\.appTheme)`). `git rm Core/Theme/AppForgeTheme.swift`. | NO dejar referencias huérfanas. | `git grep "AppForgeTheme"` = 0 resultados. Compilación verde. |

### Ola C10.2 — CORREGIR colores hardcodeados (M, 5 tareas, paralelizable)

| ID | Tarea | Archivos | Qué hacer | Qué NO hacer | Verificación |
|----|-------|----------|-----------|--------------|--------------|
| C10.T4 | **Migrar colores CADModeView** | `Features/CADMode/CADModeView.swift` | Reemplazar `.background(Color.blue.opacity(0.15))` y todos los colores hardcodeados de parameter bars por `theme.bgOverlay` con chip de color semántico solo en el label. Reemplazar `.background(Color.green.opacity(0.3))` en primitivas por `theme.surfaceSecondary`. | NO cambiar lógica de herramientas. Solo colores de fondo. | `git diff` muestra solo cambios de Color. |
| C10.T5 | **Migrar colores CADSketchView** | `Features/CADMode/CADSketchView.swift` | `Color.green.opacity(0.2)` → `theme.accent.opacity(0.15)`. `.foregroundColor(.cyan)` → `theme.accent`. `.foregroundColor(.red)` → `theme.destructive`. `.foregroundColor(.green)` → `theme.success`. | NO cambiar lógica de sketch. | `git grep "\.green\|\.cyan\|\.red\|\.orange" Features/CADMode/CADSketchView.swift` = 0. |
| C10.T6 | **Migrar colores SculptModeView** | `Features/SculptMode/SculptModeView.swift` | `.background(Color.blue)` → `theme.accent`. Eliminar lógica ternaria `isDarkMode ? Color.black...` → usar `theme.surface`. | NO cambiar brush engine. | Sin hardcodeados de color en SculptModeView. |
| C10.T7 | **Migrar colores ExportView** | `Features/ExportMode/ExportView.swift` | `.background(Color.accentColor).cornerRadius(12)` → `.background(theme.accent).cornerRadius(theme.cornerRadiusMedium)`. AR button `.background(Color.green)` → `.background(theme.success)`. | NO cambiar lógica de export. | Sin hardcodeados. |
| C10.T8 | **Migrar colores OnboardingView + LoadingScreen** | `Core/UI/OnboardingView.swift`, `Core/UI/LoadingScreenView.swift` | `.background(Color.blue)` → `theme.accent`. `.foregroundColor(.white)` → `theme.textPrimary`. `.foregroundColor(.gray)` → `theme.textSecondary`. | NO cambiar flujo de onboarding. | Sin hardcodeados. |

### Ola C10.3 — CORREGIR corner radii y espaciado (M, 4 tareas, paralelizable)

| ID | Tarea | Archivos | Qué hacer | Qué NO hacer | Verificación |
|----|-------|----------|-----------|--------------|--------------|
| C10.T9 | **Normalizar cornerRadius ≤5 a radiusSM (6)** | `CADModeView.swift`, `CADSketchView.swift`, `ContentView.swift`, `AppForgeStudioApp.swift` | Reemplazar `.cornerRadius(3)`, `.cornerRadius(4)`, `.cornerRadius(5)` por `theme.radiusSM` (6). | NO usar 5, 4, o 3 — solo tokens. | `git grep "cornerRadius([0-5])"` ≈ 0 (solo definición de tokens). |
| C10.T10 | **Normalizar cornerRadius 6-10 a radiusMD (10)** | `AnimationView.swift`, `ConstraintOverlayView.swift`, `SculptModeView.swift`, `TimelineView.swift` | `.cornerRadius(6)`, `.cornerRadius(8)` → `theme.radiusMD` (10). | NO usar 6 u 8 — unificar. | `git grep "cornerRadius([6-9])"` ≈ 0. |
| C10.T11 | **Normalizar cornerRadius 12-16 a radiusLG (14)** | `ExportView.swift`, `OnboardingView.swift`, `TransformationGizmoView.swift`, `ColorPickerView.swift` | `.cornerRadius(12)`, `.cornerRadius(16)` → `theme.radiusLG` (14). | NO usar 12 o 16. | `git grep "cornerRadius(1[2-6])"` ≈ 0. |
| C10.T12 | **Unificar espaciado a 4pt grid** | Todos los archivos con `.padding(` | Mapear valores de padding a tokens de spacing: 4→space1, 6→space1.5 (nuevo token), 8→space2, 12→space3, 16→space4, 20→space5, 24→space6. | NO tocar paddings de layout que no sean parte de UI (ej: MetalView interno). | Revisión visual: espaciado consistente entre vistas. |

### Ola C10.4 — UNIFICAR componentes canónicos (L, 4 tareas)

| ID | Tarea | Archivos | Qué hacer | Qué NO hacer | Verificación |
|----|-------|----------|-----------|--------------|--------------|
| C10.T13 | **Crear ToolButton canónico** | Nuevo: `Core/UI/Components/ToolButton.swift` | Implementar según spec 4.2. | NO modificar ToolbarView aún. | Compila standalone. |
| C10.T14 | **Migrar ToolbarView a ToolButton canónico** | `Core/UI/ToolbarView.swift` | Reemplazar `toolbarButton()` interna por `ToolButton` canónico. | NO cambiar estructura de toolbar. | CI verde + screenshot. |
| C10.T15 | **Crear GlassPanel, SurfaceCard, ChipButton canónicos** | Nuevo: `Core/UI/Components/GlassPanel.swift`, `Core/UI/Components/SurfaceCard.swift`, `Core/UI/Components/ChipButton.swift` | Implementar según specs 4.1, 4.6. Migrar Modifiers de AppForgeTheme. | NO mezclar con ThemeManager. | Compilan standalone. |
| C10.T16 | **Migrar vistas a GlassPanel y ChipButton** | `ToolMenuView.swift`, `TransformationGizmoView.swift`, `ModeSelectorView.swift`, `CADModeView.swift`, `AppForgeStudioApp.swift` | `.background(.ultraThinMaterial, in: RoundedRectangle(...))` → `.glassPanel()`. Botones de opción → `ChipButton`. | NO romper layout existente. | CI verde + screenshots de cada vista migrada. |

### Ola C10.5 — VIEWPORT HUD + SPLASH (M, 3 tareas)

| ID | Tarea | Archivos | Qué hacer | Qué NO hacer | Verificación |
|----|-------|----------|-----------|--------------|--------------|
| C10.T17 | **Implementar ViewportHUD** | Nuevo: `Core/UI/Components/ViewportHUD.swift` | Según spec 4.5. HUD overlay con FPS, polycount, tool activa. Visible con 3-finger swipe down. | NO mostrar en producción por default (solo debug). | Screenshot con HUD visible. |
| C10.T18 | **Reemplazar LoadingScreenView** | `Core/UI/LoadingScreenView.swift` | Usar tokens del design system. Quitar `MetalLoadingBackground` con color hardcodeado. ProgressView con `tint: theme.accent`. | NO cambiar lógica de carga. | Compila. |
| C10.T19 | **Eliminar OnboardingView duplicado y unificar** | `Core/UI/OnboardingView.swift`, `Core/UI/AppForgeStudioApp.swift:OnboardingFlow` | Dejar solo un OnboardingView unificado con design tokens. Eliminar el otro. | NO romper flujo first-launch. | Un solo `OnboardingView` en el proyecto. |

### Ola C10.6 — LOCALIZACIÓN Y STRINGS (S, 2 tareas)

| ID | Tarea | Archivos | Qué hacer | Qué NO hacer | Verificación |
|----|-------|----------|-----------|--------------|--------------|
| C10.T20 | **Extraer strings hardcodeados a Localizable.strings** | `es.lproj/Localizable.strings`, `en.lproj/Localizable.strings` | Crear archivos .strings para es + en. Migrar todos los strings de UI: labels de herramientas, modos, botones, placeholders. | NO tocar strings de log (OSLog). | `genstrings` o grep para strings sin localizar. |
| C10.T21 | **Unificar idioma de UI a español + inglés** | Todos los .swift con UI strings | Usar `LocalizedStringKey` o `NSLocalizedString`. El idioma default es español (público LATAM primario), inglés como fallback. | NO traducir nombres técnicos (STL, OBJ, USDZ, FPS, OCCT). | Switching de idioma en Settings muestra UI traducida. |

---

## 6. Gate de Calidad — "Mejor que Shapr3D"

### Checklist de Revisión Visual

Cada item debe ser verificado por un revisor humano (Andrés) contra screenshots de simulador en CI:

#### Vista General
- [ ] La UI no usa ningún color fuera de `AppForgeTokens` (verificar con grep de colores hardcodeados)
- [ ] No hay emojis (❌ 🎉 ✨ 🚀) en ninguna vista de producción
- [ ] No hay strings de debug visibles ("Mode: hybrid", prints())
- [ ] Modo oscuro: fondo viewport es `#0A0A0F` o más oscuro
- [ ] Sin gradientes decorativos (solo gradientes funcionales como el acento del logo)

#### Viewport
- [ ] Viewport ocupa ≥85% de la pantalla en iPad 11" landscape
- [ ] Toolbar izquierda: exactamente 52px de ancho, glassPanel
- [ ] Barra inferior: exactamente 50px de alto, glassPanel, centrada
- [ ] Panel derecho (propiedades): solo visible cuando se requiere, 240px, glassPanel
- [ ] MiniViewCube funcional en esquina inferior derecha

#### Interacción
- [ ] Cada botón tiene haptic (light/medium/selection según contexto)
- [ ] Cada transición de vista usa spring (nunca `.linear` ni `.easeInOut`)
- [ ] Animaciones de panel: ≤200ms (usa `animSnappy` o `animDefault`)
- [ ] Touch targets: ≥44pt en todos los botones interactivos
- [ ] Modo oscuro/claro: transición suave, sin parpadeos

#### Comparación directa Shapr3D
- [ ] Side-by-side screenshot: AppForge no se ve "más barato"
- [ ] Densidad de UI: comparable (AppForge no tiene más cromo que Shapr3D)
- [ ] Calidad tipográfica: SF Pro, pesos correctos, sin Rounded indebido
- [ ] Glass panels: translucidez permite ver geometría detrás
- [ ] Espaciado: consistente, sin "amontonamiento" ni "desperdicio"

#### Gold Standard Final
> **"Un ingeniero de Shapr3D, viendo un screenshot de AppForge Studio, no debe poder identificar fallos de diseño evidentes en ≤5 segundos."**

---

## Resumen Final

### Top 10 Inconsistencias Encontradas

1. **`Core/UI/AppTheme.swift:6` vs `Sources/Theme/AppTheme.swift:13`** — Dos `struct AppTheme` incompatibles con el mismo nombre (CRÍTICA)
2. **`Core/UI/HybridModeView.swift:5` vs `Features/HybridMode/HybridModeView.swift:3`** — Dos `HybridModeView` con implementaciones divergentes (ALTA)
3. **`Core/UI/ContentView.swift:9` vs `Features/CADMode/ContentView.swift:3`** — Dos `ContentView` (MetalView vs SatinView) (ALTA)
4. **`CADModeView.swift:347-425`** — 7 colores hardcodeados para parameter bars (azul, naranja, verde, púrpura, amarillo, mint) (ALTA)
5. **`Core/Theme/AppForgeTheme.swift`** — Tercer design system, el mejor, pero usado SOLO en AppForgeStudioApp.swift (ALTA)
6. **`AppForgeStudioApp.swift:221` vs `ContentView.swift:49` vs `CADModeView.swift:267`** — Corner radii de 3, 4, 5 en producción (MEDIA)
7. **`SculptModeView.swift:39,93`** — Lógica ternaria manual `isDarkMode ? Color.black... : theme.surface` en vez de theme (ALTA)
8. **Todo el proyecto** — Español e inglés mezclados sin sistema de localización (MEDIA)
9. **`ExportView.swift:24-48`** — `ConfettiView` con partículas aleatorias — efecto "app tutorial" no profesional (MEDIA)
10. **`LoadingScreenView.swift:21`** — Comillas tipográficas incorrectas, `MetalLoadingBackground` con color `UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)` hardcodeado (BAJA)

### Esencia del Design System Propuesto

Dark-first OLED con glass-morphism funcional (`.ultraThinMaterial` + borde 0.5px + shadow). Un acento azul (#4DA3FF), tipografía SF Pro sin adornos, espaciado en grid de 4pt, 5 radios canónicos (6/10/14/20/full), springs para toda animación. Componentes: GlassPanel, ToolButton, ParamSlider, ChipButton, ViewportHUD. La UI es visitante colapsable; el viewport ocupa ≥85% de pantalla. Progressive disclosure: 6 herramientas visibles, 30+ accesibles con profundidad. Haptic + visual en cada interacción. Sin emojis, sin confetti, sin gradientes decorativos.

### Micro-tareas del Plan C10

**21 tareas** en 6 olas:
- **Ola C10.1** (3 tareas, S): Unificar sistemas de theme — 3 archivos eliminados, 1 sistema canónico
- **Ola C10.2** (5 tareas, M): Eliminar colores hardcodeados — ~25 ocurrencias corregidas
- **Ola C10.3** (4 tareas, M): Normalizar corner radii y espaciado a tokens
- **Ola C10.4** (4 tareas, L): Crear y migrar a componentes canónicos (GlassPanel, ToolButton, ChipButton)
- **Ola C10.5** (3 tareas, M): Viewport HUD + splash screen + unificar onboarding
- **Ola C10.6** (2 tareas, S): Localización es/en y strings

**Paralelismo:** C10.1 secuencial (T1→T2→T3). C10.2 paralelizable (5 tareas en archivos disjuntos). C10.3 paralelizable (4 tareas). C10.4: T13 secuencial antes de T14; T15 antes de T16. C10.5 paralelizable. C10.6 paralelizable.

### CONFIANZA

**ALTA (95%)**. Todos los hallazgos están verificados contra código real leído en esta sesión. Las vistas principales (ContentView, HybridModeView, CADModeView, SculptModeView, ExportView, AnimationView, TimelineView, AppForgeStudioApp, OnboardingView, PreferencesView, LoadingScreenView, ToolbarView, ModeSelectorView, ToolMenuView, TransformationGizmoView, LayerPanelView, ColorPickerView, ConstraintOverlayView, PencilSketchView, CADSketchView, SnapGuideOverlay, MaterialEditorPBRView) fueron leídas completas. Los 3 sistemas de theme fueron leídos línea por línea.

El benchmark de competencia (Shapr3D, Nomad Sculpt, Feather3D) se basa en conocimiento público de las apps — no verificado contra builds actuales de junio 2026. Los principios extraídos son observacionales y pueden requerir ajuste si las apps cambiaron significativamente.
