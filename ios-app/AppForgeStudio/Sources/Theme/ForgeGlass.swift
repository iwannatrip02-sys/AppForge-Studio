// ForgeGlass.swift
// AppForge Studio — Forge Glass Design System
//
// Generado de docs/design/design_tokens.json v1.0 — ese JSON es la fuente;
// si cambias un valor, cámbialo ALLÁ primero.
//
// Este archivo es ADITIVO. No modifica AppTheme, ThemeManager ni Components.
// Los agentes de UI consumen las APIs públicas de este archivo directamente.

import SwiftUI

// MARK: - ForgeGlass Token Namespace

/// Todos los tokens del sistema Forge Glass como constantes Swift tipadas.
/// Organización espeja docs/design/design_tokens.json v1.0.
/// Uso: `ForgeGlass.Color.ember`, `ForgeGlass.Spacing.s3`, etc.
public enum ForgeGlass {

    // MARK: Color

    public enum Color {

        // ── Fondos — "taller de noche" (OLED) ──
        /// #0A0B10 — viewport 3D: el negro más profundo; el modelo es el héroe.
        public static let bgCanvas   = SwiftUI.Color(hex: "0A0B10")
        /// #12141A — superficie principal cuando NO hay viewport.
        public static let bgBase     = SwiftUI.Color(hex: "12141A")
        /// #1A1D26 — cards y superficies elevadas sobre bgBase.
        public static let bgRaised   = SwiftUI.Color(hex: "1A1D26")
        /// #222630 — estado hover / activo de fila o celda.
        public static let bgOverlay  = SwiftUI.Color(hex: "222630")
        /// #1B1E28 — tinte base del vidrio (se pinta DEBAJO del .ultraThinMaterial).
        public static let bgGlass    = SwiftUI.Color(hex: "1B1E28")

        // ── Brasa — acento único ──
        /// #FF7A45 — acción activa, selección, foco, número vivo. Una sola brasa a la vez.
        public static let ember      = SwiftUI.Color(hex: "FF7A45")
        /// #FFA06B — halo del glow y estados presionados.
        public static let emberGlow  = SwiftUI.Color(hex: "FFA06B")
        /// #D9541E — destructivo-intencional (boolean subtract, hornear, excavar).
        public static let emberDeep  = SwiftUI.Color(hex: "D9541E")

        // ── Materiales — dualidad B-rep / malla ──
        /// #6FA3D0 — B-rep exacto: edges, badge ⬡, cotas, valores CONFIRMADOS.
        public static let steel       = SwiftUI.Color(hex: "6FA3D0")
        /// #8FBCE4 — acero enfatizado: selección de cara exacta.
        public static let steelBright = SwiftUI.Color(hex: "8FBCE4")
        /// #C79A6B — material libre (malla): badge 〰, tinte de selección de malla.
        public static let clay        = SwiftUI.Color(hex: "C79A6B")

        // ── Semánticos de sistema ──
        /// #34D399 — éxito (coincide con eje Y).
        public static let success = SwiftUI.Color(hex: "34D399")
        /// #FBBF24 — atención.
        public static let warning = SwiftUI.Color(hex: "FBBF24")
        /// #F87171 — error (coincide con eje X).
        public static let error   = SwiftUI.Color(hex: "F87171")

        // ── Ejes (convención universal, no se modifican) ──
        /// #F87171 — eje X.
        public static let axisX = SwiftUI.Color(hex: "F87171")
        /// #34D399 — eje Y.
        public static let axisY = SwiftUI.Color(hex: "34D399")
        /// #6FA3D0 — eje Z (=steel, convención universal).
        public static let axisZ = SwiftUI.Color(hex: "6FA3D0")

        // ── Texto ──
        /// #F0F1F5 — texto principal, valores.
        public static let textPrimary   = SwiftUI.Color(hex: "F0F1F5")
        /// #9AA0B0 — labels, texto de apoyo.
        public static let textSecondary = SwiftUI.Color(hex: "9AA0B0")
        /// #5A5F6E — iconos inactivos, hints, unidades.
        public static let textTertiary  = SwiftUI.Color(hex: "5A5F6E")

        // ── Bordes ──
        /// #2A2E3A — borde de vidrio y separadores (1px).
        public static let borderDefault = SwiftUI.Color(hex: "2A2E3A")
        /// #1E212B — borde apenas perceptible en superficies internas.
        public static let borderSubtle  = SwiftUI.Color(hex: "1E212B")

        // ── Modo claro (solo accesibilidad) ──
        /// #F2F2F7
        public static let lightBgCanvas      = SwiftUI.Color(hex: "F2F2F7")
        /// #FFFFFF
        public static let lightBgBase        = SwiftUI.Color(hex: "FFFFFF")
        /// #F9F9FB
        public static let lightBgRaised      = SwiftUI.Color(hex: "F9F9FB")
        /// #E5E5EA
        public static let lightBgOverlay     = SwiftUI.Color(hex: "E5E5EA")
        /// #1C1C1E
        public static let lightTextPrimary   = SwiftUI.Color(hex: "1C1C1E")
        /// #636366
        public static let lightTextSecondary = SwiftUI.Color(hex: "636366")
        /// #AEAEB2
        public static let lightTextTertiary  = SwiftUI.Color(hex: "AEAEB2")
        /// #C6C6C8
        public static let lightBorder        = SwiftUI.Color(hex: "C6C6C8")
    }

    // MARK: Opacity

    public enum Opacity {

        // ── Vidrio por contexto ──
        /// 0.72 — panel sobre viewport 3D; debe verse la geometría detrás.
        public static let glassOnViewport: Double = 0.72
        /// 0.78 — flyout de herramienta; legibilidad sobre escena movida.
        public static let glassFlyout: Double = 0.78
        /// 0.80 — barra de parámetros activa; prioriza lectura del número vivo.
        public static let glassParamBar: Double = 0.80
        /// 0.92 — panel sobre bg.base (settings/export); nada valioso detrás.
        public static let glassOnBase: Double = 0.92
        /// 0.65 — HUD inline sobre geometría; mínima intrusión sobre el modelo.
        public static let glassInlineHud: Double = 0.65

        // ── Estados de componente ──
        /// 0.12 — fill al presionar (ember.glow).
        public static let statePressedFill: Double = 0.12
        /// 0.15 — fill del estado seleccionado (ember).
        public static let stateActiveFill: Double = 0.15
        /// 0.30 — borde del estado seleccionado (ember).
        public static let stateActiveBorder: Double = 0.30
        /// 0.20 — fill de chip activo (ember).
        public static let stateChipActiveFill: Double = 0.20
        /// 0.35 — control deshabilitado.
        public static let stateDisabled: Double = 0.35
        /// 0.45 — centro del glow de estado (radial gradient start).
        public static let glowCenter: Double = 0.45
    }

    // MARK: Blur

    public enum Blur {
        /// Paneles flotantes usan .ultraThinMaterial del sistema (~20-30pt adaptativo).
        /// No usar .blur() custom sobre contenido: mata rendimiento y rompe consistencia.
        public static let panelApproxPt: CGFloat = 25  // solo referencia; usar .ultraThinMaterial

        /// 24pt — blur gaussiano de la luz del glow de estado. SOLO sobre la capa de color, nunca texto.
        public static let glow: CGFloat = 24

        /// 30pt — límite duro de blur en UI. Nunca superar este valor.
        public static let maxUI: CGFloat = 30
    }

    // MARK: Spacing (grid base 4pt)

    public enum Spacing {
        public static let gridBase: CGFloat = 4

        public static let s0:  CGFloat = 0
        public static let s1:  CGFloat = 4
        public static let s2:  CGFloat = 8
        public static let s3:  CGFloat = 12
        public static let s4:  CGFloat = 16
        public static let s5:  CGFloat = 20
        public static let s6:  CGFloat = 24
        public static let s8:  CGFloat = 32
        public static let s10: CGFloat = 40
        public static let s12: CGFloat = 48
    }

    // MARK: Radius

    public enum Radius {
        public static let none: CGFloat = 0
        /// 6pt — chips, tooltips, botones pequeños, HUD inline.
        public static let sm:   CGFloat = 6
        /// 10pt — cards, paneles de vidrio, flyouts, barras.
        public static let md:   CGFloat = 10
        /// 14pt — modales, sheets, glass panels grandes.
        public static let lg:   CGFloat = 14
        /// 20pt — contenedor exterior del viewport (solo borde).
        public static let xl:   CGFloat = 20
        /// 999pt — píldoras, círculos, chips-pill.
        public static let full: CGFloat = 999
    }

    // MARK: Elevation

    public enum Elevation {
        case none
        /// negro 15% / radio 4 / y 1 — cards sobre bg.base.
        case level1
        /// negro 25% / radio 12 / y 3 — paneles de vidrio sobre viewport (default).
        case level2
        /// negro 35% / radio 20 / y 6 — modales, popovers.
        case level3
        /// negro 45% / radio 28 / y 8 — tooltips, menús contextuales.
        case level4

        /// (color, radius, y) listo para pasar a .shadow().
        public var shadow: (color: SwiftUI.Color, radius: CGFloat, y: CGFloat) {
            switch self {
            case .none:   return (.clear, 0, 0)
            case .level1: return (.black.opacity(0.15), 4, 1)
            case .level2: return (.black.opacity(0.25), 12, 3)
            case .level3: return (.black.opacity(0.35), 20, 6)
            case .level4: return (.black.opacity(0.45), 28, 8)
            }
        }
    }

    // MARK: Motion

    public enum Motion {

        // ── Springs ──
        /// spring(response 0.20, damping 0.60) — micro-interacciones, press, chips.
        public static let snappy  = Animation.spring(response: 0.20, dampingFraction: 0.60)
        /// spring(response 0.30, damping 0.70) — aparición de paneles, selección.
        public static let def     = Animation.spring(response: 0.30, dampingFraction: 0.70)
        /// spring(response 0.40, damping 0.80) — modales, transiciones de pantalla.
        public static let smooth  = Animation.spring(response: 0.40, dampingFraction: 0.80)
        /// spring(response 0.50, damping 0.85) — transiciones grandes (raro).
        public static let glacial = Animation.spring(response: 0.50, dampingFraction: 0.85)

        // ── Duraciones nombradas ──
        /// 0.15s easeOut — encendido de herramienta (fade-in del fill+glow).
        public static let toolIgniteDuration: Double = 0.15
        /// 0.40s easeOut — templado: glow ember→steel decae a 0. ÚNICA excepción a "todo spring".
        public static let temperDecayDuration: Double = 0.40

        /// Animación de decay del glow (easeOut, ÚNICA excepción a springs en el sistema).
        public static let temperDecay = Animation.easeOut(duration: temperDecayDuration)
        /// Animación de encendido de herramienta (fade-in, easeOut).
        public static let toolIgnite  = Animation.easeOut(duration: toolIgniteDuration)

        // ── Límites duros ──
        /// 0.20s — máximo para interacciones (snappy/default).
        public static let interactiveMax: Double = 0.20
        /// 0.35s — máximo para modales.
        public static let modalMax: Double = 0.35
        /// 0.40s — máximo para transición de pantalla.
        public static let screenTransitionMax: Double = 0.40
    }

    // MARK: Glow (firma de estado §3.4)

    public enum Glow {
        /// Color del glow en operación normal: ember #FF7A45.
        public static let colorNormal      = SwiftUI.Color(hex: "FF7A45")
        /// Color del glow en operación destructiva: ember.deep #D9541E.
        public static let colorDestructive = SwiftUI.Color(hex: "D9541E")
        /// Color del glow al confirmar (templado): steel #6FA3D0.
        public static let colorSettled     = SwiftUI.Color(hex: "6FA3D0")
        /// 0.45 — opacidad del centro del gradiente radial.
        public static let opacityCenter: Double = 0.45
        /// 24pt — blur gaussiano sobre la capa de color (nunca sobre texto).
        public static let blurPt: CGFloat = 24
        /// 16pt — el glow se derrama ~16pt fuera del borde del panel (bleed).
        public static let bleedPt: CGFloat = 16
    }

    // MARK: Typography

    /// Escala tipográfica del sistema. SF Pro (design=default) para texto,
    /// SF Mono (design=monospaced) para cifras. Toda cifra es monospaced, siempre.
    public enum Typography {
        case largeTitle  // 28pt Bold      — solo headers de onboarding
        case title1      // 20pt Semibold  — títulos de pantalla
        case title2      // 15pt Semibold  — headers de sección
        case heading     // 12pt Medium    — group labels (UPPERCASE +8% tracking)
        case body        // 13pt Regular   — cuerpo
        case caption     // 10pt Regular   — info secundaria, unidades
        case monoLarge   // 13pt Medium Monospaced — valores de dimensión en barras
        case mono        // 10pt Medium Monospaced — lecturas numéricas pequeñas
        case numberLive  // 34pt Regular Monospaced — número vivo en viewport (ember)
        case toolLabel   // 8pt Medium     — labels de icono en rail/mode bar

        public var font: Font {
            switch self {
            case .largeTitle:  return .system(size: 28, weight: .bold,     design: .default)
            case .title1:      return .system(size: 20, weight: .semibold, design: .default)
            case .title2:      return .system(size: 15, weight: .semibold, design: .default)
            case .heading:     return .system(size: 12, weight: .medium,   design: .default)
            case .body:        return .system(size: 13, weight: .regular,  design: .default)
            case .caption:     return .system(size: 10, weight: .regular,  design: .default)
            case .monoLarge:   return .system(size: 13, weight: .medium,   design: .monospaced)
            case .mono:        return .system(size: 10, weight: .medium,   design: .monospaced)
            case .numberLive:  return .system(size: 34, weight: .regular,  design: .monospaced)
            case .toolLabel:   return .system(size: 8,  weight: .medium,   design: .default)
            }
        }
    }

    /// Regla tipográfica: tracking de group labels (+8% = 0.08em).
    public static let groupLabelTracking: CGFloat = 0.08

    // MARK: Icon Sizes

    public enum Icon {
        public static let sm:  CGFloat = 12  // decorativos, indicadores
        public static let md:  CGFloat = 17  // rail / mode bar
        public static let lg:  CGFloat = 24  // acciones destacadas
        public static let xl:  CGFloat = 32  // empty states
        public static let xxl: CGFloat = 56  // onboarding
    }

    // MARK: Touch Targets

    public enum Touch {
        /// 44pt — mínimo HIG.
        public static let min: CGFloat = 44
        /// 48pt — cómodo.
        public static let comfortable: CGFloat = 48
    }

    // MARK: Chrome Layout

    public enum Chrome {
        /// 56pt — ancho del rail de herramientas (izquierda).
        public static let railWidth: CGFloat = 56
        /// 56pt — alto de la barra de modos (inferior).
        public static let modeBarHeight: CGFloat = 56
        /// 44pt — alto máximo del chrome superior.
        public static let topChromeHeight: CGFloat = 44
        /// 15% — chrome permanente ≤ 15% del área (iPad apaisado).
        public static let maxChromeAreaPct: Double = 15
    }
}

// MARK: - GlassContext

/// Contexto semántico del panel de vidrio.
/// Determina la opacidad del tinte bg.glass según §3.1 del DESIGN_SYSTEM.
public enum GlassContext {
    /// Panel flotando sobre el viewport 3D — 0.72.
    case overViewport
    /// Flyout de herramienta — 0.78.
    case flyout
    /// Barra de parámetros activa (contiene número vivo) — 0.80.
    case paramBar
    /// HUD inline (cota/dato sobre geometría) — 0.65.
    case hud
    /// Panel sobre bg.base (settings/export, sin 3D detrás) — 0.92.
    case standalone

    /// Opacidad del tinte bg.glass para este contexto.
    public var glassOpacity: Double {
        switch self {
        case .overViewport: return ForgeGlass.Opacity.glassOnViewport   // 0.72
        case .flyout:       return ForgeGlass.Opacity.glassFlyout        // 0.78
        case .paramBar:     return ForgeGlass.Opacity.glassParamBar      // 0.80
        case .hud:          return ForgeGlass.Opacity.glassInlineHud     // 0.65
        case .standalone:   return ForgeGlass.Opacity.glassOnBase        // 0.92
        }
    }

    /// Corner radius canónico para este contexto.
    public var cornerRadius: CGFloat {
        switch self {
        case .hud:      return ForgeGlass.Radius.sm  // 6pt — píldora compacta
        default:        return ForgeGlass.Radius.md  // 10pt — paneles y flyouts
        }
    }
}

// MARK: - ForgeGlassPanelModifier

/// El panel de vidrio canónico del sistema Forge Glass (§3.1 DESIGN_SYSTEM).
///
/// Nombre: ForgeGlassPanelModifier para no colisionar con GlassPanelModifier
/// de Components.swift (la implementación C10 legacy sin contexto).
/// Los agentes de UI deben consumir éste vía .glassPanel(context:).
///
/// Receta:
///   capa 1 (fondo):  bg.glass al opacity(context) — tinte bajo el material
///   capa 2 (blur):   .ultraThinMaterial            — blur del sistema (iOS adaptativo)
///   borde:           border.default 1px dentro del corner radius
///   sombra:          elevation.level2 (negro 25%, radio 12, y +3)
///   corner radius:   según GlassContext (md=10pt por defecto, sm=6pt para HUD)
///
/// Uso: `.glassPanel(context: .flyout)` o `.glassPanel()` (default: .overViewport)
public struct ForgeGlassPanelModifier: ViewModifier {
    public let context: GlassContext

    public init(context: GlassContext = .overViewport) {
        self.context = context
    }

    public func body(content: Content) -> some View {
        let r = context.cornerRadius
        let elev = ForgeGlass.Elevation.level2.shadow

        content
            .background(
                ZStack {
                    // Capa 1: tinte bg.glass con opacidad exacta del contexto
                    ForgeGlass.Color.bgGlass
                        .opacity(context.glassOpacity)
                    // Capa 2: material del sistema (blur adaptativo ~20-30pt)
                    Rectangle()
                        .fill(.ultraThinMaterial)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
            .overlay(
                // Borde 1px dentro del shape
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .stroke(ForgeGlass.Color.borderDefault, lineWidth: 1)
            )
            .shadow(color: elev.color, radius: elev.radius, y: elev.y)
    }
}

// MARK: - EmberGlowModifier

/// El glow de estado: la firma del sistema Forge Glass (§3.4 DESIGN_SYSTEM).
///
/// Cuando una operación está activa/caliente, el panel irradia un glow radial
/// desde dentro que "sangra" ~16pt fuera del borde. Se anima con la curva
/// toolIgnite (fade-in 0.15s easeOut) y el decay es temperDecay (0.40s easeOut).
///
/// PROHIBIDO: dos glows a la vez; glow sin operación activa; glow verde/azul.
///
/// Uso: `.emberGlow(active: isToolActive)` — para destructivo, usar `.emberGlow(active:, destructive: true)`
public struct EmberGlowModifier: ViewModifier {
    public let active: Bool
    public let destructive: Bool

    @State private var glowVisible: Bool = false

    public init(active: Bool, destructive: Bool = false) {
        self.active = active
        self.destructive = destructive
    }

    private var glowColor: SwiftUI.Color {
        destructive ? ForgeGlass.Glow.colorDestructive : ForgeGlass.Glow.colorNormal
    }

    public func body(content: Content) -> some View {
        content
            .overlay(
                // Gradiente radial centrado en el panel, del 45% de opacidad al 0%
                GeometryReader { geo in
                    if glowVisible {
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: glowColor.opacity(ForgeGlass.Glow.opacityCenter), location: 0),
                                .init(color: glowColor.opacity(0), location: 1)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: max(geo.size.width, geo.size.height) * 0.6
                        )
                        // blur 24pt sobre la capa de color (NUNCA sobre el texto — overlay está encima del content)
                        .blur(radius: ForgeGlass.Glow.blurPt)
                        // el glow se derrama ~16pt fuera del borde del panel
                        .padding(-ForgeGlass.Glow.bleedPt)
                        .allowsHitTesting(false)
                    }
                }
                .allowsHitTesting(false)
            )
            .onChange(of: active) { newValue in
                if newValue {
                    withAnimation(ForgeGlass.Motion.toolIgnite) {
                        glowVisible = true
                    }
                } else {
                    withAnimation(ForgeGlass.Motion.temperDecay) {
                        glowVisible = false
                    }
                }
            }
            .onAppear {
                glowVisible = active
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Aplica el panel de vidrio canónico Forge Glass al contexto indicado.
    /// Default: .overViewport (opacidad 0.72 — el más conservador sobre viewport 3D).
    public func glassPanel(context: GlassContext = .overViewport) -> some View {
        modifier(ForgeGlassPanelModifier(context: context))
    }

    /// Aplica el glow de estado brasa sobre el panel.
    /// `active: true` → fade-in 0.15s; `active: false` → decay 0.40s easeOut.
    /// `destructive: true` → usa ember.deep en lugar de ember.
    public func emberGlow(active: Bool, destructive: Bool = false) -> some View {
        modifier(EmberGlowModifier(active: active, destructive: destructive))
    }
}

// MARK: - #Preview

#if DEBUG
#Preview("ForgeGlass — Panel Contexts") {
    ZStack {
        // Fondo oscuro simulando el viewport 3D
        Rectangle()
            .fill(ForgeGlass.Color.bgCanvas)
            .ignoresSafeArea()

        // Mock de geometría 3D en el fondo
        VStack(spacing: 0) {
            LinearGradient(
                colors: [ForgeGlass.Color.steel.opacity(0.3), ForgeGlass.Color.ember.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()

        VStack(spacing: ForgeGlass.Spacing.s4) {
            // Panel 1: sobre viewport (contexto más frecuente)
            VStack(alignment: .leading, spacing: ForgeGlass.Spacing.s2) {
                Text("HERRAMIENTA ACTIVA")
                    .font(ForgeGlass.Typography.heading.font)
                    .kerning(ForgeGlass.groupLabelTracking * 12)
                    .textCase(.uppercase)
                    .foregroundColor(ForgeGlass.Color.textTertiary)
                Text("Push / Pull")
                    .font(ForgeGlass.Typography.body.font)
                    .foregroundColor(ForgeGlass.Color.textPrimary)
                Text("12.50 mm")
                    .font(ForgeGlass.Typography.numberLive.font)
                    .foregroundColor(ForgeGlass.Color.ember)
            }
            .padding(ForgeGlass.Spacing.s3)
            .glassPanel(context: .overViewport)  // opacity 0.72

            // Panel 2: flyout (opacity 0.78)
            HStack(spacing: ForgeGlass.Spacing.s3) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: ForgeGlass.Icon.md, weight: .medium))
                    .foregroundColor(ForgeGlass.Color.ember)
                Text("Flyout de herramienta")
                    .font(ForgeGlass.Typography.body.font)
                    .foregroundColor(ForgeGlass.Color.textPrimary)
            }
            .padding(ForgeGlass.Spacing.s3)
            .glassPanel(context: .flyout)  // opacity 0.78

            // Panel 3: paramBar con glow activo (opacity 0.80)
            HStack(spacing: ForgeGlass.Spacing.s3) {
                Text("Radio")
                    .font(ForgeGlass.Typography.caption.font)
                    .foregroundColor(ForgeGlass.Color.textSecondary)
                Spacer()
                Text("24.00")
                    .font(ForgeGlass.Typography.monoLarge.font)
                    .foregroundColor(ForgeGlass.Color.ember)
                Text("mm")
                    .font(ForgeGlass.Typography.caption.font)
                    .foregroundColor(ForgeGlass.Color.textTertiary)
            }
            .padding(ForgeGlass.Spacing.s3)
            .glassPanel(context: .paramBar)   // opacity 0.80
            .emberGlow(active: true)           // glow brasa activo

            // Panel 4: HUD inline (opacity 0.65)
            HStack(spacing: ForgeGlass.Spacing.s1) {
                Text("90.0°")
                    .font(ForgeGlass.Typography.mono.font)
                    .foregroundColor(ForgeGlass.Color.textPrimary)
            }
            .padding(.horizontal, ForgeGlass.Spacing.s2)
            .padding(.vertical, ForgeGlass.Spacing.s1)
            .glassPanel(context: .hud)  // opacity 0.65, radius.sm
        }
        .padding(ForgeGlass.Spacing.s6)
    }
    .preferredColorScheme(.dark)
}
#endif
