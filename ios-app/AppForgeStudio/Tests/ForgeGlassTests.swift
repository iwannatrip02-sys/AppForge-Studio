// ForgeGlassTests.swift
// AppForge Studio
//
// Congela la correspondencia JSON ↔ Swift del Design System Forge Glass.
// El JSON (docs/design/design_tokens.json v1.0) NO está en el bundle de la app
// durante las pruebas, por lo que los valores clave se copian aquí como literales
// esperados. Si el JSON cambia, este test se romperá: ESO ES INTENCIONAL.
// Protocolo: actualizar JSON primero → luego las constantes Swift → luego estos tests.

import XCTest
import SwiftUI
@testable import AppForgeStudio

// MARK: - Helpers

/// Compara dos Color SwiftUI extrayendo sus componentes sRGB.
/// Tolerancia ±0.002 para redondeos de enteros 0-255.
private func assertColorHex(
    _ color: Color,
    hex expectedHex: String,
    file: StaticString = #file,
    line: UInt = #line
) {
    guard let resolved = resolveColor(color) else {
        XCTFail("No se pudo resolver el color", file: file, line: line)
        return
    }
    guard let expected = resolveColor(Color(hex: expectedHex)) else {
        XCTFail("No se pudo resolver el hex esperado \(expectedHex)", file: file, line: line)
        return
    }
    let tol = 0.002
    XCTAssertEqual(resolved.red,   expected.red,   accuracy: tol, "R de \(expectedHex)", file: file, line: line)
    XCTAssertEqual(resolved.green, expected.green, accuracy: tol, "G de \(expectedHex)", file: file, line: line)
    XCTAssertEqual(resolved.blue,  expected.blue,  accuracy: tol, "B de \(expectedHex)", file: file, line: line)
}

private struct RGBA { var red, green, blue, alpha: Double }

private func resolveColor(_ color: Color) -> RGBA? {
    #if canImport(UIKit)
    let ui = UIColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
    return RGBA(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
    #else
    return nil
    #endif
}

// MARK: - ForgeGlassColorTests

/// JSON key: color.ember.base.value = "#FF7A45"
/// JSON key: color.material.steel.value = "#6FA3D0"
/// JSON key: color.semantic.success.value = "#34D399"
/// JSON key: color.text.primary.value = "#F0F1F5"
/// JSON key: color.border.default.value = "#2A2E3A"
/// JSON key: color.bg.glass.value = "#1B1E28"
final class ForgeGlassColorTests: XCTestCase {

    func testEmberMatchesJSON() {
        // JSON: color.ember.base.value = "#FF7A45"
        assertColorHex(ForgeGlass.Color.ember, hex: "FF7A45")
    }

    func testEmberGlowMatchesJSON() {
        // JSON: color.ember.glow.value = "#FFA06B"
        assertColorHex(ForgeGlass.Color.emberGlow, hex: "FFA06B")
    }

    func testEmberDeepMatchesJSON() {
        // JSON: color.ember.deep.value = "#D9541E"
        assertColorHex(ForgeGlass.Color.emberDeep, hex: "D9541E")
    }

    func testSteelMatchesJSON() {
        // JSON: color.material.steel.value = "#6FA3D0"
        assertColorHex(ForgeGlass.Color.steel, hex: "6FA3D0")
    }

    func testSuccessMatchesJSON() {
        // JSON: color.semantic.success.value = "#34D399"
        assertColorHex(ForgeGlass.Color.success, hex: "34D399")
    }

    func testTextPrimaryMatchesJSON() {
        // JSON: color.text.primary.value = "#F0F1F5"
        assertColorHex(ForgeGlass.Color.textPrimary, hex: "F0F1F5")
    }

    func testBorderDefaultMatchesJSON() {
        // JSON: color.border.default.value = "#2A2E3A"
        assertColorHex(ForgeGlass.Color.borderDefault, hex: "2A2E3A")
    }

    func testBgGlassMatchesJSON() {
        // JSON: color.bg.glass.value = "#1B1E28"
        assertColorHex(ForgeGlass.Color.bgGlass, hex: "1B1E28")
    }

    func testAxisZEqualsSteelPerConvention() {
        // JSON: color.axis.z == color.material.steel (convención universal)
        assertColorHex(ForgeGlass.Color.axisZ, hex: "6FA3D0")
    }
}

// MARK: - ForgeGlassOpacityTests

/// Congela las 5 opacidades de vidrio del JSON.
/// JSON key: opacity.glass.*
final class ForgeGlassOpacityTests: XCTestCase {

    func testGlassOnViewportOpacity() {
        // JSON: opacity.glass.onViewport.value = 0.72
        XCTAssertEqual(ForgeGlass.Opacity.glassOnViewport, 0.72, accuracy: 0.001)
    }

    func testGlassFlyoutOpacity() {
        // JSON: opacity.glass.flyout.value = 0.78
        XCTAssertEqual(ForgeGlass.Opacity.glassFlyout, 0.78, accuracy: 0.001)
    }

    func testGlassParamBarOpacity() {
        // JSON: opacity.glass.paramBar.value = 0.80
        XCTAssertEqual(ForgeGlass.Opacity.glassParamBar, 0.80, accuracy: 0.001)
    }

    func testGlassOnBaseOpacity() {
        // JSON: opacity.glass.onBase.value = 0.92
        XCTAssertEqual(ForgeGlass.Opacity.glassOnBase, 0.92, accuracy: 0.001)
    }

    func testGlassInlineHudOpacity() {
        // JSON: opacity.glass.inlineHud.value = 0.65
        XCTAssertEqual(ForgeGlass.Opacity.glassInlineHud, 0.65, accuracy: 0.001)
    }

    func testGlowCenterOpacity() {
        // JSON: opacity.state.glowStart.value = 0.45
        XCTAssertEqual(ForgeGlass.Opacity.glowCenter, 0.45, accuracy: 0.001)
    }
}

// MARK: - ForgeGlassSpacingTests

/// JSON key: spacing.grid = 4 (grid base 4pt)
final class ForgeGlassSpacingTests: XCTestCase {

    func testGridBase() {
        // JSON: spacing.grid = 4
        XCTAssertEqual(ForgeGlass.Spacing.gridBase, 4)
    }

    func testSpacingScale() {
        // JSON: spacing.1 = 4, .2 = 8, .3 = 12, .4 = 16, .6 = 24
        XCTAssertEqual(ForgeGlass.Spacing.s1, 4)
        XCTAssertEqual(ForgeGlass.Spacing.s2, 8)
        XCTAssertEqual(ForgeGlass.Spacing.s3, 12)
        XCTAssertEqual(ForgeGlass.Spacing.s4, 16)
        XCTAssertEqual(ForgeGlass.Spacing.s6, 24)
        XCTAssertEqual(ForgeGlass.Spacing.s8, 32)
        XCTAssertEqual(ForgeGlass.Spacing.s12, 48)
    }

    func testAllSpacingValuesAreMultiplesOfGrid() {
        // Invariante del sistema: todo valor de spacing es múltiplo de 4
        let values: [CGFloat] = [
            ForgeGlass.Spacing.s0,
            ForgeGlass.Spacing.s1, ForgeGlass.Spacing.s2, ForgeGlass.Spacing.s3,
            ForgeGlass.Spacing.s4, ForgeGlass.Spacing.s5, ForgeGlass.Spacing.s6,
            ForgeGlass.Spacing.s8, ForgeGlass.Spacing.s10, ForgeGlass.Spacing.s12
        ]
        for v in values {
            XCTAssertEqual(v.truncatingRemainder(dividingBy: 4), 0,
                           "\(v) no es múltiplo del grid base 4pt")
        }
    }
}

// MARK: - ForgeGlassRadiusTests

/// JSON key: radius.*
final class ForgeGlassRadiusTests: XCTestCase {

    func testRadiiMatchJSON() {
        // JSON: radius.sm=6, md=10, lg=14, xl=20, full=999
        XCTAssertEqual(ForgeGlass.Radius.none, 0)
        XCTAssertEqual(ForgeGlass.Radius.sm,   6)
        XCTAssertEqual(ForgeGlass.Radius.md,   10)
        XCTAssertEqual(ForgeGlass.Radius.lg,   14)
        XCTAssertEqual(ForgeGlass.Radius.xl,   20)
        XCTAssertEqual(ForgeGlass.Radius.full, 999)
    }
}

// MARK: - ForgeGlassElevationTests

/// JSON key: elevation.*
final class ForgeGlassElevationTests: XCTestCase {

    func testLevel2IsDefaultForGlassPanels() {
        // JSON: elevation.level2 = { opacity: 0.25, radius: 12, y: 3 }
        let shadow = ForgeGlass.Elevation.level2.shadow
        XCTAssertEqual(shadow.radius, 12)
        XCTAssertEqual(shadow.y, 3)
    }

    func testLevel1() {
        // JSON: elevation.level1 = { opacity: 0.15, radius: 4, y: 1 }
        let shadow = ForgeGlass.Elevation.level1.shadow
        XCTAssertEqual(shadow.radius, 4)
        XCTAssertEqual(shadow.y, 1)
    }

    func testLevel4() {
        // JSON: elevation.level4 = { opacity: 0.45, radius: 28, y: 8 }
        let shadow = ForgeGlass.Elevation.level4.shadow
        XCTAssertEqual(shadow.radius, 28)
        XCTAssertEqual(shadow.y, 8)
    }
}

// MARK: - ForgeGlassMotionTests

/// JSON key: duration.spring.* y duration.named.*
final class ForgeGlassMotionTests: XCTestCase {

    func testTemperDecayDuration() {
        // JSON: duration.named.temperDecay.value = 0.40
        XCTAssertEqual(ForgeGlass.Motion.temperDecayDuration, 0.40, accuracy: 0.001)
    }

    func testToolIgniteDuration() {
        // JSON: duration.named.toolIgnite.value = 0.15
        XCTAssertEqual(ForgeGlass.Motion.toolIgniteDuration, 0.15, accuracy: 0.001)
    }

    func testInteractiveMaxLimit() {
        // JSON: duration.limits.interactiveMax = 0.20
        XCTAssertEqual(ForgeGlass.Motion.interactiveMax, 0.20, accuracy: 0.001)
    }

    func testScreenTransitionMaxLimit() {
        // JSON: duration.limits.screenTransitionMax = 0.40
        XCTAssertEqual(ForgeGlass.Motion.screenTransitionMax, 0.40, accuracy: 0.001)
    }
}

// MARK: - ForgeGlassContextTests

/// Verifica que GlassContext mapea las opacidades correctas del JSON.
final class ForgeGlassContextTests: XCTestCase {

    func testOverViewportOpacity() {
        XCTAssertEqual(GlassContext.overViewport.glassOpacity, 0.72, accuracy: 0.001)
    }

    func testFlyoutOpacity() {
        XCTAssertEqual(GlassContext.flyout.glassOpacity, 0.78, accuracy: 0.001)
    }

    func testParamBarOpacity() {
        XCTAssertEqual(GlassContext.paramBar.glassOpacity, 0.80, accuracy: 0.001)
    }

    func testHudOpacity() {
        XCTAssertEqual(GlassContext.hud.glassOpacity, 0.65, accuracy: 0.001)
    }

    func testStandaloneOpacity() {
        XCTAssertEqual(GlassContext.standalone.glassOpacity, 0.92, accuracy: 0.001)
    }

    func testHudUsesSmallRadius() {
        // HUD es compacto: radius.sm (6pt)
        XCTAssertEqual(GlassContext.hud.cornerRadius, ForgeGlass.Radius.sm)
    }

    func testFlyoutUsesMediumRadius() {
        // Flyouts y paneles: radius.md (10pt)
        XCTAssertEqual(GlassContext.flyout.cornerRadius, ForgeGlass.Radius.md)
    }
}

// MARK: - ForgeGlassGlowTests

/// JSON key: glow.*
final class ForgeGlassGlowTests: XCTestCase {

    func testGlowBlurMatchesJSON() {
        // JSON: glow.blurPt = 24
        XCTAssertEqual(ForgeGlass.Glow.blurPt, 24)
    }

    func testGlowBleedMatchesJSON() {
        // JSON: glow.bleedPt = 16
        XCTAssertEqual(ForgeGlass.Glow.bleedPt, 16)
    }

    func testGlowOpacityCenterMatchesJSON() {
        // JSON: glow.opacityCenter = 0.45
        XCTAssertEqual(ForgeGlass.Glow.opacityCenter, 0.45, accuracy: 0.001)
    }

    func testGlowNormalColorIsEmber() {
        // JSON: glow.colorNormal = "#FF7A45" (= color.ember.base)
        assertColorHex(ForgeGlass.Glow.colorNormal, hex: "FF7A45")
    }

    func testGlowSettledColorIsSteel() {
        // JSON: glow.colorSettled = "#6FA3D0" (= color.material.steel)
        assertColorHex(ForgeGlass.Glow.colorSettled, hex: "6FA3D0")
    }
}
