import SwiftUI

// MARK: - Color Extensions

extension Color {
    /// Hex string initializer: "#4DA3FF" or "4DA3FF", optionally "FF4DA3FF" (ARGB)
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: Double
        switch hex.count {
        case 6: // RGB
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
            a = 1.0
        case 8: // ARGB or RGBA
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
            a = Double((int >> 24) & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// UInt hex initializer (backward compat): 0x4DA3FF
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

// MARK: - AppForge Design System v2 — "Acero & Brasa" (docs/IDENTIDAD_FORGE.md)
// v1 (C10) unificó los tokens pero heredó el alma de Shapr3D (su azul #4DA3FF).
// v2 define identidad propia: el taller es frío (acero/grafito), lo que trabajas
// está al rojo (brasa). El color comunica ESTADO, jamás decora:
//   brasa  = activo/editándose ahora (solo UNA brasa a la vez en pantalla)
//   acero  = material exacto (B-rep vivo): edges, badges, cotas
//   arcilla = material libre (malla esculpible)
// Principios v1 que se conservan: dark-first OLED + un solo material de vidrio +
// 4pt grid + SF Pro (cifras SIEMPRE monospaced) + springs ≤400ms.

struct AppTheme {

    // ── Instance properties (varies by dark/light, backward compat) ──

    var background: Color
    var surface: Color
    var surfaceSecondary: Color
    var textPrimary: Color
    var textSecondary: Color
    var accent: Color
    var border: Color
    var destructive: Color
    var success: Color
    var warning: Color
    var error: Color
    var metalBackground: UIColor

    // ── Static Palette — "taller de noche" (fríos, OLED) ──

    static let bgCanvas    = Color(hex: "0A0B10")   // viewport: el negro más profundo — el modelo es el héroe
    static let bgBase      = Color(hex: "12141A")   // superficies principales
    static let bgRaised    = Color(hex: "1A1D26")   // cards, paneles elevados
    static let bgOverlay   = Color(hex: "222630")   // hover, estados activos
    static let bgGlass     = Color(hex: "1B1E28")   // base de paneles vidrio (pre-blur)

    // ── BRASA (accent propio — reemplaza el azul heredado de Shapr3D) ──
    // Calor = "esto está siendo modificado AHORA". Nada decorativo lleva brasa.

    static let accentColor   = Color(hex: "FF7A45")   // ember: acción activa, selección, foco
    static let accentMuted   = Color(hex: "D9541E")   // ember profunda: destructivo-intencional (pocket, subtract, hornear)
    static let accentGlow    = Color(hex: "FFA06B")   // glow de presionado / gradiente cálido

    // ── MATERIALES (la dualidad de la app hecha color) ──

    static let steel       = Color(hex: "6FA3D0")   // material exacto (B-rep): edges, badges ⬡, cotas
    static let steelBright = Color(hex: "8FBCE4")   // acero enfatizado (cara exacta seleccionada)
    static let clay        = Color(hex: "C79A6B")   // material libre (malla esculpible): badge 〰, tint selección

    // ── Static Semantic ──

    static let successColor  = Color(hex: "34D399")
    static let warningColor  = Color(hex: "FBBF24")
    static let errorColor    = Color(hex: "F87171")
    static let destructiveColor = Color(hex: "F87171")
    static let axisX = Color(hex: "F87171")   // Red
    static let axisY = Color(hex: "34D399")   // Green
    static let axisZ = Color(hex: "4DA3FF")   // Blue

    // ── Static Text (instrumento, no protagonista) ──

    static let textPrimaryColor   = Color(hex: "F0F1F5")
    static let textSecondaryColor = Color(hex: "9AA0B0")
    static let textTertiary       = Color(hex: "5A5F6E")

    // ── Static Borders ──

    static let borderColor      = Color(hex: "2A2E3A")
    static let borderLightColor = Color(hex: "1E212E")

    // ── Light mode counterparts (for accessibility) ──

    static let lightBgCanvas    = Color(hex: "F2F2F7")
    static let lightBgBase      = Color(hex: "FFFFFF")
    static let lightBgRaised    = Color(hex: "F9F9FB")
    static let lightBgOverlay   = Color(hex: "E5E5EA")
    static let lightTextPrimary = Color(hex: "1C1C1E")
    static let lightTextSecond  = Color(hex: "636366")
    static let lightTextTert    = Color(hex: "AEAEB2")
    static let lightBorder      = Color(hex: "C6C6C8")

    // ── Typography (SF Pro, NOT SF Pro Rounded) ──

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

    // ── Corner Radii (geometric progression) ──

    static let radiusNone: CGFloat = 0
    static let radiusSM:   CGFloat = 6    // Chips, tooltips, small buttons
    static let radiusMD:   CGFloat = 10   // Cards, panels, sheets
    static let radiusLG:   CGFloat = 14   // Modals, glass panels
    static let radiusXL:   CGFloat = 20   // Viewport container (solo borde exterior)
    static let radiusFull: CGFloat = 999  // Pills, circles

    // ── Icon Sizes ──

    static let iconSM:  CGFloat = 12  // Decorativos, indicadores
    static let iconMD:  CGFloat = 17  // Toolbar buttons
    static let iconLG:  CGFloat = 24  // Featured actions
    static let iconXL:  CGFloat = 32  // Empty states
    static let iconXXL: CGFloat = 56  // Onboarding

    // ── Touch Targets (HIG mínimo: 44pt) ──

    static let touchMin: CGFloat = 44
    static let touchComfortable: CGFloat = 48

    // ── Elevation (shadow presets) ──

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

    // ── Animation Presets ──

    static let animDefault = Animation.spring(response: 0.30, dampingFraction: 0.70)
    static let animSnappy  = Animation.spring(response: 0.20, dampingFraction: 0.60)
    static let animSmooth  = Animation.spring(response: 0.40, dampingFraction: 0.80)
    static let animGlacial = Animation.spring(response: 0.50, dampingFraction: 0.85)

    // ── Backward-compat computed properties (old theme API) ──

    var titleFont: Font { AppTheme.Typography.title1.font }
    var bodyFont: Font { AppTheme.Typography.body.font }
    var captionFont: Font { AppTheme.Typography.caption.font }

    var cornerRadiusSmall: CGFloat { AppTheme.radiusSM }
    var cornerRadiusMedium: CGFloat { AppTheme.radiusMD }
    var cornerRadiusLarge: CGFloat { AppTheme.radiusLG }

    var elevation: CGFloat { 2 }

    var iconSizeSmall: CGFloat { AppTheme.iconSM }
    var iconSizeMedium: CGFloat { AppTheme.iconMD }
    var iconSizeLarge: CGFloat { AppTheme.iconLG }

    // Legacy spacing aliases (8pt grid → 4pt grid mapping)
    var spXXS: CGFloat { 2 }
    var spXS: CGFloat { AppTheme.space1 }
    var spSM: CGFloat { AppTheme.space2 }
    var spMD: CGFloat { AppTheme.space3 }
    var spLG: CGFloat { AppTheme.space4 }
    var spXL: CGFloat { AppTheme.space6 }
    var spXXL: CGFloat { AppTheme.space8 }

    // Legacy radii aliases
    var rSM: CGFloat { AppTheme.radiusSM }
    var rMD: CGFloat { AppTheme.radiusMD }
    var rLG: CGFloat { AppTheme.radiusLG }
    var rXL: CGFloat { AppTheme.radiusXL }

    // ── Dark instance (default, OLED-first) ──

    static let dark = AppTheme(
        background: AppTheme.bgCanvas,
        surface: AppTheme.bgBase,
        surfaceSecondary: AppTheme.bgOverlay,
        textPrimary: AppTheme.textPrimaryColor,
        textSecondary: AppTheme.textSecondaryColor,
        accent: AppTheme.accentColor,
        border: AppTheme.borderColor,
        destructive: AppTheme.destructiveColor,
        success: AppTheme.successColor,
        warning: AppTheme.warningColor,
        error: AppTheme.errorColor,
        metalBackground: .darkGray
    )

    // ── Light instance (accessibility) ──

    static let light = AppTheme(
        background: AppTheme.lightBgCanvas,
        surface: AppTheme.lightBgBase,
        surfaceSecondary: AppTheme.lightBgOverlay,
        textPrimary: AppTheme.lightTextPrimary,
        textSecondary: AppTheme.lightTextSecond,
        accent: AppTheme.accentColor,
        border: AppTheme.lightBorder,
        destructive: AppTheme.destructiveColor,
        success: AppTheme.successColor,
        warning: AppTheme.warningColor,
        error: AppTheme.errorColor,
        metalBackground: .lightGray
    )

    // ── Convenience ──

    func color(for scheme: ColorScheme) -> AppTheme {
        switch scheme {
        case .dark: return .dark
        case .light: return .light
        @unknown default: return .dark
        }
    }

    static func theme(for scheme: ColorScheme) -> AppTheme {
        switch scheme {
        case .dark: return .dark
        case .light: return .light
        @unknown default: return .dark
        }
    }
}
