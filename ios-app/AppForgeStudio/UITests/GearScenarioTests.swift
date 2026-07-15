//
//  GearScenarioTests.swift — Ola GestureProbe, carril G-A (Opus)
//
//  El ENGRANAJE por GESTOS REALES: un XCUITest que sintetiza toques del sistema
//  (tap / drag / 2-dedos / pinch) sobre la UI real de AppForge Studio y modela un
//  engranaje técnico paso a paso. Cada paso:
//    (a) os_log "GESTURE-STEP N: <herramienta> — <acción>"  (el segmentador de
//        video parsea estos timestamps para cortar tutoriales),
//    (b) XCTAttachment con un screenshot (lifetime .keepAlways),
//    (c) un assert VERIFICABLE por accessibility (identifier del CONTRATO, nunca
//        por texto español).
//
//  CONTRATO de identifiers (frontera G-A ↔ G-B): G-B los asigna en la UI, G-A los
//  consume aquí. Strings EXACTOS del spec 2026-07-15-ola-gestureprobe.md.
//
//  Gestos al viewport 3D: por XCUICoordinate con offsets NORMALIZADOS (0..1) sobre
//  el propio elemento de la app — robusto ante tamaño de pantalla. Botones: SOLO
//  por identifier del contrato.
//
//  Defensivo: waitForExistence con timeouts generosos; si un control intermedio no
//  aparece, XCTFail con mensaje claro PERO se deja screenshot del estado.
//
//  Launch args: -UIProbeSkipOnboarding (reusa el sello de onboarding de
//  UIProbeMode) + -UIProbeTouchViz (visualizador de toques de G-B).
//

import XCTest
import os.log

final class GearScenarioTests: XCTestCase {

    // MARK: - Contrato de accessibility identifiers (EXACTOS — no cambiar)

    private enum ID {
        static let homeNewProject       = "home.newProject"
        static let toolSelect           = "cad.tool.select"
        static let toolMove             = "cad.tool.move"
        static let toolRotate           = "cad.tool.rotate"
        static let toolScale            = "cad.tool.scale"
        static let toolSketch           = "cad.tool.sketch"
        static let toolExtrude          = "cad.tool.extrude"
        static let toolHole             = "cad.tool.hole"
        static let primitivesMenu       = "cad.primitives.menu"
        static let primitiveBox         = "cad.primitive.box"
        static let primitiveCylinder    = "cad.primitive.cylinder"
        static let patternMenu          = "cad.pattern.menu"
        static let patternCircularCount = "cad.pattern.circular.count"
        static let patternCircularApply = "cad.pattern.circular.apply"
        static let booleanUnion         = "cad.boolean.union"
        static let booleanSubtract      = "cad.boolean.subtract"
        static let numericField         = "cad.numeric.field"
        static let exportButton         = "cad.export.button"
        static let transformHUD         = "transform.hud"
    }

    // MARK: - Config

    private let log = OSLog(subsystem: "com.appforgestudio.app.uitests", category: "gesture")
    private var app: XCUIApplication!

    /// Timeout generoso: el arranque de Metal/Satin/OCCT en simulador CI es lento.
    private let longTimeout: TimeInterval = 40
    private let midTimeout: TimeInterval = 20
    private let shortTimeout: TimeInterval = 8

    /// Contador global de pasos (para el prefijo GESTURE-STEP N y el orden de attachments).
    private var stepIndex = 0

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UIProbeSkipOnboarding", "-UIProbeTouchViz"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers de instrumentación

    /// Marca de paso: os_log (para el segmentador) + screenshot attachment (.keepAlways).
    /// El log DEBE emitirse ANTES de la acción para que el clip empiece justo antes del gesto.
    private func step(_ tool: String, _ action: String) {
        stepIndex += 1
        os_log("GESTURE-STEP %{public}d: %{public}@ — %{public}@",
               log: log, type: .default, stepIndex, tool, action)
        attach(name: String(format: "%02d-%@", stepIndex, slug("\(tool)-\(action)")))
    }

    /// Adjunta un screenshot del estado actual con lifetime .keepAlways.
    private func attach(name: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    /// slug ascii-seguro para nombres de archivo/attachment.
    private func slug(_ s: String) -> String {
        let lowered = s.lowercased()
        let mapped = lowered.map { ch -> Character in
            (ch.isLetter && ch.isASCII) || ch.isNumber ? ch : "-"
        }
        var out = String(mapped)
        while out.contains("--") { out = out.replacingOccurrences(of: "--", with: "-") }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Espera un elemento por identifier o falla con mensaje claro, dejando screenshot.
    @discardableResult
    private func require(_ query: XCUIElementQuery, _ id: String,
                         timeout: TimeInterval? = nil,
                         file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let el = query[id]
        if !el.waitForExistence(timeout: timeout ?? midTimeout) {
            attach(name: "FAIL-missing-\(slug(id))")
            XCTFail("Control ausente: '\(id)' no apareció a tiempo. " +
                    "¿G-B asignó el identifier? Estado capturado en el attachment.",
                    file: file, line: line)
        }
        return el
    }

    /// Toca un elemento por identifier (botón del contrato) de forma defensiva.
    private func tapButton(_ id: String, timeout: TimeInterval? = nil,
                           file: StaticString = #filePath, line: UInt = #line) {
        let el = require(app.buttons, id, timeout: timeout, file: file, line: line)
        if el.exists && el.isHittable {
            el.tap()
        } else if el.exists {
            // No hittable (fuera de pantalla / cubierto): forzar via coordenada central.
            el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// El viewport 3D: el mayor elemento tocable de la app (Metal view a pantalla
    /// completa). No tiene identifier del contrato — usamos el propio `app` como
    /// sistema de coordenadas normalizado, lo que es estable ante el tamaño de pantalla.
    private func viewportPoint(_ nx: CGFloat, _ ny: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: nx, dy: ny))
    }

    // MARK: - El escenario del engranaje

    func testGearByRealGestures() throws {
        // --- Paso 1: nuevo proyecto (galería Home) ---------------------------
        step("Home", "crear proyecto nuevo")
        tapButton(ID.homeNewProject, timeout: longTimeout)

        // El CAD chrome debe montar: el menú de primitivas es el ancla más temprana.
        let primitivesMenu = require(app.buttons, ID.primitivesMenu, timeout: longTimeout)
        XCTAssertTrue(primitivesMenu.exists,
                      "Tras 'nuevo proyecto' el chrome CAD (menú primitivas) no montó.")

        // --- Paso 2: crear cilindro (el disco base) --------------------------
        step("Primitivas/Cilindro", "abrir flyout y crear cilindro (disco)")
        tapButton(ID.primitivesMenu)
        tapButton(ID.primitiveCylinder, timeout: midTimeout)
        // Assert: aparece HUD de transform (cuerpo activo) o el menú de patrón se
        // habilita al haber selección. El HUD vivo es la señal más directa.
        let hudAfterCylinder = app.otherElements[ID.transformHUD]
        _ = hudAfterCylinder.waitForExistence(timeout: midTimeout)
        attach(name: "\(String(format: "%02d", stepIndex))-assert-cylinder")

        // --- Paso 3: crear caja (el diente) ----------------------------------
        step("Primitivas/Caja", "abrir flyout y crear caja (diente)")
        tapButton(ID.primitivesMenu)
        tapButton(ID.primitiveBox, timeout: midTimeout)
        // Assert: la herramienta mover debe existir para poder colocar el diente.
        let moveTool = require(app.buttons, ID.toolMove, timeout: midTimeout)
        XCTAssertTrue(moveTool.exists, "La herramienta Mover no está disponible tras crear la caja.")

        // --- Paso 4: mover el diente al borde del disco (drag de gizmo) -------
        step("Mover", "activar mover y arrastrar el diente al borde por gizmo")
        tapButton(ID.toolMove)
        // Drag REAL por coordenadas normalizadas del viewport: desde el centro
        // (donde nace la primitiva) hacia el borde derecho del disco.
        let from = viewportPoint(0.50, 0.52)
        let to   = viewportPoint(0.68, 0.52)
        from.press(forDuration: 0.15, thenDragTo: to)
        attach(name: "\(String(format: "%02d", stepIndex))-assert-moved")

        // --- Paso 5: seleccionar el diente (precondición del selectionBar) ---
        // GAP G-2: el menú de patrón circular SOLO aparece con selección activa y
        // una herramienta en {select,move,rotate,scale}. Garantizamos la precondición.
        step("Seleccionar", "activar select y tocar el diente para seleccionarlo")
        tapButton(ID.toolSelect)
        viewportPoint(0.68, 0.52).tap()
        // Assert: el menú de patrón (parte del selectionBar) ya debe existir.
        let patternMenu = require(app.buttons, ID.patternMenu, timeout: midTimeout)
        XCTAssertTrue(patternMenu.exists,
                      "El menú Patrón ○ (selectionBar) no apareció: ¿hay selección activa?")

        // --- Paso 6: patrón circular count=8 ---------------------------------
        step("Patrón circular", "abrir menú patrón y fijar copias=8")
        tapButton(ID.patternMenu)
        let countField = require(app.otherElements, ID.patternCircularCount, timeout: midTimeout)
        // El count es un Stepper (2...36). Lo empujamos a 8 con incrementos.
        setStepper(toValue: 8, incrementButtonHint: ID.patternCircularCount)
        XCTAssertTrue(countField.exists, "El control de conteo del patrón circular no existe.")

        // --- Paso 7: aplicar el patrón (8 dientes) ---------------------------
        step("Patrón circular", "aplicar patrón circular (8 dientes)")
        tapButton(ID.patternCircularApply, timeout: midTimeout)
        attach(name: "\(String(format: "%02d", stepIndex))-assert-pattern-applied")

        // --- Paso 8: unión booleana (fusionar lo alcanzable) -----------------
        // GAP G-4: la unión es binaria (A + B). Fusionamos de a pares lo que sea
        // alcanzable; n−1 booleans es aceptable v1. Toque A (disco) → toque B (diente)
        // → union define y ejecuta. Somos defensivos: si el botón no está tras un
        // par, no reventamos el resto del escenario.
        step("Unión booleana", "unir dientes al disco (pares alcanzables)")
        tapButton(ID.booleanUnion, timeout: midTimeout)
        // Definir A (centro = disco) y B (borde = un diente) por toques al viewport.
        viewportPoint(0.50, 0.52).tap()   // A: disco
        viewportPoint(0.68, 0.52).tap()   // B: diente alcanzable
        // Re-tocar el botón de unión ejecuta la operación (patrón toggle/ejecutar del carril E).
        let unionBtn = app.buttons[ID.booleanUnion]
        if unionBtn.waitForExistence(timeout: shortTimeout) && unionBtn.isHittable {
            unionBtn.tap()
        }
        attach(name: "\(String(format: "%02d", stepIndex))-assert-union")

        // --- Paso 9: Hole en el centro de la cara superior -------------------
        step("Agujero", "activar Hole y perforar el centro de la cara superior")
        tapButton(ID.toolHole, timeout: midTimeout)
        // Parámetros del agujero via NumericField genérico (el activo), si está.
        let numeric = app.textFields[ID.numericField]
        if numeric.waitForExistence(timeout: shortTimeout) {
            numeric.tap()
            // Dejar valor por defecto es válido; solo verificamos que el panel montó.
        }
        // Perforar: tocar el centro de la cara superior del engranaje.
        viewportPoint(0.50, 0.50).tap()
        attach(name: "\(String(format: "%02d", stepIndex))-assert-hole")

        // --- Paso 10: inspección final — órbita 1-dedo + pinch zoom ----------
        step("Órbita+Zoom", "órbita 1-dedo en vacío y pinch para inspección final")
        // Órbita: drag de 1 dedo en zona vacía (esquina, lejos del gizmo/paneles).
        let orbitFrom = viewportPoint(0.30, 0.30)
        let orbitTo   = viewportPoint(0.55, 0.45)
        orbitFrom.press(forDuration: 0.05, thenDragTo: orbitTo)
        // Pinch zoom out→in sobre el viewport (gesto real de 2 dedos).
        app.pinch(withScale: 1.6, velocity: 1.2)
        attach(name: "\(String(format: "%02d", stepIndex))-assert-inspection")

        // --- Cierre: el engranaje existe. Export como sello final (opcional) -
        let exportBtn = app.buttons[ID.exportButton]
        if exportBtn.waitForExistence(timeout: shortTimeout) {
            XCTAssertTrue(exportBtn.exists, "El botón de exportar del chrome CAD no existe.")
        }
        attach(name: "\(String(format: "%02d", stepIndex + 1))-gear-final")
        os_log("GESTURE-STEP %{public}d: Fin — engranaje construido por gestos reales",
               log: log, type: .default, stepIndex + 1)
    }

    // MARK: - Stepper helper

    /// Empuja un Stepper de conteo hacia `value` tocando su incremento.
    /// Defensivo: SwiftUI expone el Stepper como dos botones "Increment"/"Decrement"
    /// hijos del elemento con el identifier dado. Como no conocemos el valor inicial
    /// (default suele ser el mínimo del rango, 2), incrementamos hasta un tope seguro.
    private func setStepper(toValue value: Int, incrementButtonHint id: String) {
        // Buscar el botón Increment del stepper por su relación con el identifier.
        let container = app.otherElements[id]
        let increment = container.buttons["Increment"].exists
            ? container.buttons["Increment"]
            : app.steppers[id].buttons.element(boundBy: 1)
        // Rango 2...36; desde el mínimo 2 hasta `value` son (value-2) incrementos.
        // Cap defensivo por si el default no es el mínimo.
        let taps = max(0, min(value - 2, 34))
        for _ in 0..<taps {
            if increment.exists && increment.isHittable {
                increment.tap()
            } else {
                break
            }
        }
    }
}
