# RECON GestureProbe — 2026-07-15

Rama: `feature/fase-c`. Solo lectura. Alimenta la ola "GestureProbe" (XCUITest target).

---

## A. Infra de Targets

### project.yml (ios-app/AppForgeStudio/project.yml)

Targets actuales:

| Target | type | bundle id | INFOPLIST_FILE |
|--------|------|-----------|----------------|
| `AppForgeStudio` | `application` | `com.appforgestudio.app` | `AppForgeStudio/Info.plist` |
| `AppForgeStudioTests` | `bundle.unit-test` | `com.appforgestudio.app.tests` | `AppForgeStudioTests-Info.plist` (propio) |

El test target tiene `TEST_HOST` implícito por dependencia `- target: AppForgeStudio` (project.yml:100).

### Cómo instala/usa xcodegen el CI

- `build.yml` instala via `brew install xcodegen` (sin versión pinned → última de Homebrew).
- `ui-probe.yml` replica exactamente el mismo paso.
- Ambos corren `xcodegen generate` y luego `xcodebuild` con `-scheme AppForgeStudio` (no `-only-testing`).
- Destination de tests: `platform=iOS Simulator,name=iPad Pro 13-inch (M4)` (build.yml línea ~run-tests).
- Xcodegen reciente (>=2.x) soporta `bundle.ui-testing`; no hay evidencia de versión antigua.

### Invariantes ci_infra aplicados a un UI-test target (Serena memory)

1. **Info.plist PROPIO**: el nuevo target UI necesita su propio plist (`AppForgeStudioUITests-Info.plist`) con `CFBundlePackageType=BNDL`.
2. **Bundle ID distinto**: debe ser `com.appforgestudio.app.uitests` (ni igual al app ni al unit-test — compartirlo rompe la instalación en simulador con el engañoso "Missing bundle ID").
3. **Firma simulador**: `CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- OTHER_CODE_SIGN_FLAGS=--deep` — mismos flags que app y unit-test target, pasados en el `xcodebuild test` del CI.
4. **type `bundle.ui-testing`**: XcodeGen genera el `XCUITest` runner correctamente; requiere `TEST_HOST` vacío (el runner se inyecta solo) y `BUNDLE_LOADER` vacío — distinto al unit-test.
5. **Resources**: nunca `type: folder`. Solo paths individuales (misma regla que la app).

---

## B. Accessibility — Inventario

### Controles con `.accessibilityLabel` existentes

| Control | Label / String | Archivo:línea |
|---------|---------------|---------------|
| Toolbar superior — Deshacer | `"Deshacer"` | Core/UI/ContentView.swift:103 |
| Toolbar superior — Rehacer | `"Rehacer"` | Core/UI/ContentView.swift:109 |
| Toolbar superior — Resetear vista | `"Resetear vista"` | Core/UI/ContentView.swift:116 |
| Toolbar superior — Re-encuadrar | `"Re-encuadrar"` | Core/UI/AppForgeStudioApp.swift:219 |
| Toolbar superior — Volver a proyectos | `"Volver a proyectos (guarda)"` | Core/UI/AppForgeStudioApp.swift:265 |
| Panel de elementos (sidebar) | `"Panel de elementos"` | Features/CADMode/CADModeView.swift:796 |
| Botones de grupo del rail (tab) | `group.rawValue` (e.g. "Dibujo","Formar","Combinar","Primitivas") | CADModeView.swift:1598 |
| Botones de herramienta del flyout | `tool.displayName` (e.g. "Unir","Restar","Agujero","Extruir","Push/Pull") | CADModeView.swift:1647 |
| Sketch — Deshacer punto | `"Deshacer punto"` | CADModeView.swift:951 |
| Sketch — Borrar boceto | `"Borrar boceto"` | CADModeView.swift:955 |
| Sketch — Plano suelo | `"Plano de boceto: suelo"` | CADModeView.swift:963 |
| Selección — Deseleccionar entidad | `"Deseleccionar entidad"` | CADModeView.swift:1061 |
| Selección — Deseleccionar (barra) | `"Deseleccionar"` | CADModeView.swift:1448 |
| Medida — Reiniciar | `"Reiniciar medición"` | CADModeView.swift:1866 |
| Archivo (toolbar) | `"Archivo"` | CADModeView.swift:1954 |
| Agrupar ensamblaje | `"Agrupar ensamblaje"` | CADModeView.swift:1965 |
| Modo rayos X | `"Modo rayos X"` | CADModeView.swift:2031 |
| TransformHUD — Aplicar valor | `"Aplicar valor"` | Views/TransformHUD.swift:72 |
| TransformHUD — Medida viva | `"Medida viva"` | Views/TransformHUD.swift:84 |
| Timeline — Borrar historial | `"Borrar todo el historial"` | Views/CADTimelineView.swift:66 |

**Nota importante**: ninguno usa `.accessibilityIdentifier`. Solo `.accessibilityLabel`.

### Controles que FALTAN accessibility id/label (para añadir)

| Control | Archivo:línea del botón | Label sugerida (para referencia del implementador) |
|---------|------------------------|--------------------------------------------------|
| Rail izquierdo — botones de grupo (los tabs que expanden flyout) | CADModeView.swift:1595-1600 | Ya tiene `.accessibilityLabel(group.rawValue)` pero SIN `.accessibilityIdentifier` |
| Botones de primitiva: Caja | CADModeView.swift:1617-1619 (flyoutButton con prim.id="Box") | `accessibilityIdentifier` = `"tool.primitive.box"` |
| Botones de primitiva: Cilindro | CADModeView.swift:1617-1619 (prim.id="Cylinder") | `accessibilityIdentifier` = `"tool.primitive.cylinder"` |
| flyoutButton genérico (Agujero, Extruir, Unir, Restar) | CADModeView.swift:1651-1668 | Ningún `.accessibilityIdentifier` ni `.accessibilityLabel` propios — solo heredan `.accessibilityLabel(tool.displayName)` (línea 1647) |
| NumericField (radio/prof de Hole) | CADModeView.swift:892-896 | Sin id — `"hole.diameter"`, `"hole.depth"` |
| Botón "Aplicar patrón circular" (dentro del Menu) | CADModeView.swift:1365 | Sin id — `"pattern.circular.apply"` |
| Botón "Exportar..." / "Exportar STEP" | CADModeView.swift:1936-1941 | Sin id — `"export.step"`, `"export.sheet"` |
| selectionBar — "Reflejar" | CADModeView.swift:1336 | Sin id |
| selectionBar — Menu "Patrón ↹" label | CADModeView.swift:1356 | Sin id |
| selectionBar — Menu "Patrón ○" label | CADModeView.swift:1366 | Sin id — **CRÍTICO para el engranaje** |
| Toolbar — "Archivo" Menu completo e hijos | CADModeView.swift:1954 | Archivo tiene label pero hijos no tienen id |

---

## C. Gestos del Viewport (MetalView.swift)

Archivo: `Core/UI/MetalView.swift`

### Registradores instalados (todos en `makeUIView` vía `Coordinator`)

| Gesto | Clase | Configuración | Línea |
|-------|-------|---------------|-------|
| Pan general (1 o 2 dedos) | `UIPanGestureRecognizer` | `maximumNumberOfTouches = 2`, `#selector(handlePan)` | 252-255 |
| Pinch (zoom) | `UIPinchGestureRecognizer` | `#selector(handlePinch)` | 257-259 |
| Roll (2 dedos torsión) | `UIRotationGestureRecognizer` | `#selector(handleRoll)` | 263-265 |
| Tap simple (selección/hit) | `UITapGestureRecognizer` | 1 toque, `#selector(handleTap)` | 267-269 |
| Doble tap (re-encuadrar) | `UITapGestureRecognizer` | `numberOfTapsRequired=2`, `#selector(handleDoubleTap)` | 284-287 |
| Undo tap (2 dedos) | `UITapGestureRecognizer` | `numberOfTouchesRequired=2`, `#selector(handleUndoTap)` | 274-277 |
| Redo tap (3 dedos) | `UITapGestureRecognizer` | `numberOfTouchesRequired=3`, `#selector(handleRedoTap)` | 279-282 |
| Pan 2 dedos extruir | `UIPanGestureRecognizer` | `#selector(handlePinchExtrude)`, min 2 touches | 481 |

### Clasificación pencil vs dedo — `lastTouchWasPencil`

- Declarado: `private var lastTouchWasPencil = false` (MetalView.swift:221)
- **Quién lo setea**: el delegate `gestureRecognizer(_:shouldReceive:)` en MetalView.swift:307-308:
  ```swift
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                          shouldReceive touch: UITouch) -> Bool {
      lastTouchWasPencil = (touch.type == .pencil)
  ```
- `touch.type == .pencil` es la única fuente. También lee `touch.maximumPossibleForce` y `touch.force` para `strokePressure` (líneas 309-312).
- Efecto: cuando `lastTouchWasPencil == true`, el pan de 1 dedo no orbita (MetalView.swift:367, 386, 391).

### Seam para `-UIProbeForcePencil`

El seam más limpio es **el guard de `shouldReceive` en MetalView.swift:307**. En modo debug se podría añadir una propiedad `var forcePencilInDebug = false` en `Coordinator` y hacer:
```swift
lastTouchWasPencil = forcePencilInDebug || (touch.type == .pencil)
```
Activarlo con el launch-argument `-UIProbeForcePencil` desde `UIProbeMode` (que ya existe y tiene el patrón de launch-args). No requiere subclase de MTKView.

---

## D. Ventana / Overlay

### App lifecycle (AppForgeStudioApp.swift)

- **`WindowGroup` puro** (AppForgeStudioApp.swift:48) — no hay `UIApplicationDelegateAdaptor`.
- Acceso a `UIWindowScene` ya existe en la app: `UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first` (AppForgeStudioApp.swift:36-39), llamado en `requestLandscapeOrientation()` bajo `UIProbeMode`.
- No hay `UIWindow` subclasificada ni propiedad expuesta explícitamente.

### UIProbeMode — acceso a escena/ventana

- `UIProbeMode` ya accede a `UIWindowScene` a través del mismo patrón en `requestLandscapeOrientation()`.
- Para un overlay de puntos de toque debug-only: el lugar más limpio es un `ZStack` debug-only sobre `WindowGroup` body, controlado por `UIProbeMode.isActive`. La window existe como `UIWindowScene.windows.first` desde el código ya escrito.
- **No hay UIWindow subclasificada** — el overlay tendría que inyectarse como overlay SwiftUI (`.overlay`) sobre el root del `WindowGroup`, o mediante un `UIWindow` secundario creado programáticamente en el delegate.

---

## E. Herramientas para el Engranaje

### Crear disco (cilindro plano) / diente (caja)

| Herramienta | Botón en UI | Acción | Archivo:línea |
|-------------|-------------|--------|---------------|
| Crear Caja | Rail izq → tab "Primitivas" → flyout "Caja" | `performAddPrimitive("Box")` → `occt.box(width:height:depth:)` | CADModeView.swift:1619, 2840-2842 |
| Crear Cilindro | Rail izq → tab "Primitivas" → flyout "Cilindro" | `performAddPrimitive("Cylinder")` → `occt.cylinder(radius:height:)` | CADModeView.swift:1619, 2846-2848 |

### Mover con gizmo

- Herramienta `.move` en tab "Modelo" del rail, luego arrastrar el gizmo de flechas sobre el modelo seleccionado. Gizmo existe vía `GizmoBuilder` (CADModeView.swift:233-245).

### Patrón circular con parámetros

| Elemento | Descripción | Archivo:línea |
|----------|-------------|---------------|
| Trigger | Seleccionar cuerpo → `selectionBar` aparece (requiere `selectionController.hasSelection` && tool in [.select,.move,.rotate,.scale]) | CADModeView.swift:327-329 |
| Control | `Menu { Stepper("Copias: \(patternCircularCount)", in: 2...36); Button("Aplicar patrón circular") }` | CADModeView.swift:1362-1369 |
| Acción | `applyCircularPattern(modelIndex:)` → `BRepModeling.circularPattern(of:count:axisOrigin:axisDirection:)` | CADModeView.swift:1311, BRepModeling.swift:222 |
| Motor | Siempre 360° sobre eje Y por el origen. Sin control de ángulo parcial (honestidad doc). | BRepModeling.swift:217-221 |

**GAP CRÍTICO**: El `selectionBar` (y por tanto el Menu de Patrón ○) solo aparece cuando `selectionController.hasSelection == true` Y la herramienta seleccionada es `.select`, `.move`, `.rotate` o `.scale`. Si el usuario tiene `.hole` u otra herramienta activa, el patrón circular NO es visible.

### Boolean unión/resta

| Herramienta | Botón | Acción | Archivo:línea |
|-------------|-------|--------|---------------|
| Boolean Unión | Rail → tab "Combinar" → flyout "Unir" → tocar cuerpo A → tocar cuerpo B → botón "Ejecutar" | `activate(.booleanUnion)` → toque define A y B | CADModeView.swift:424-440 |
| Boolean Resta | Rail → tab "Combinar" → flyout "Restar" | Mismo patrón que Unión | CADModeView.swift:424-440 |

### Herramienta Hole

| Elemento | Descripción | Archivo:línea |
|----------|-------------|---------------|
| Botón | Rail → tab "Formar" → flyout "Agujero" | `activate(.hole)` | CADModeView.swift:1623-1626 |
| Panel contextual | `holeBar` aparece cuando `selectedTool == .hole` | CADModeView.swift:334-335 |
| Parámetros | `NumericField` radio (Ø) y profundidad (0=pasante) | CADModeView.swift:892-896 |
| Acción | Tocar cara del modelo → `BRepModeling.drill(model, at:direction:radius:depth:)` | CADModeView.swift:397-398 |

### Export

| Botón | Acción | Archivo:línea |
|-------|--------|---------------|
| "Exportar STEP" | `exportToSTEP()` | CADModeView.swift:1936-1938 |
| "Exportar..." | `showExport = true` → sheet `ExportView` | CADModeView.swift:1940-1941 |

### ¿La secuencia disco→diente→patrón circular→unión→agujero es alcanzable?

1. **disco**: crear Cilindro (flat disk si height << radius — pero el cilindro base tiene h=size igual al radio; no hay parámetros de aspect ratio en la UI) — **GAP PARCIAL**: el disco necesita h distinto de r pero `primitiveSize` controla ambos con un slider (no hay controles separados de radio y altura para cilindro).
2. **diente (caja)**: crear Caja — OK, `performAddPrimitive("Box")`.
3. **mover diente al borde del disco**: herramienta `.move` + gizmo — OK.
4. **patrón circular del diente**: seleccionar la caja → tool debe ser `.select/.move/.rotate/.scale` → `selectionBar` muestra Menu "Patrón ○" → Stepper copias → "Aplicar" — OK, pero contexto-dependiente.
5. **unión booleana (dientes → disco)**: `.booleanUnion`, tocar disco (A), tocar cada diente-copia (B), ejecutar. Cada copia es un cuerpo independiente — **GAP**: la unión es binaria (un A + un B); para n dientes requiere n-1 operaciones de unión en secuencia.
6. **agujero central**: `.hole` → tocar cara — OK.

---

## GAPS

| ID | Descripción | Impacto para GestureProbe |
|----|-------------|--------------------------|
| G-1 | **Zero `accessibilityIdentifier`** en toda la app. XCUITest localiza elementos por `accessibilityIdentifier`; sin ellos solo se puede usar `.label` (frágil, en español) o coordenadas. | BLOQUEANTE para XCUITest estable |
| G-2 | **Patrón circular condicional**: el Menu "Patrón ○" solo aparece en `selectionBar`, que requiere `hasSelection==true` y tool en {select,move,rotate,scale}. El test debe garantizar esa condición antes de buscar el botón. | Requiere precondición explícita en el script de test |
| G-3 | **Cilindro no tiene control de aspect ratio**: el slider `primitiveSize` controla un único escalar; radio y altura son iguales. Un disco CAD real (h << r) no es alcanzable desde la UI actual sin editar los parámetros post-creación. | El engranaje v1 puede usar un cilindro "cuadrado" como disco; no es ideal pero funcional |
| G-4 | **Unión booleana es binaria**: n dientes = n-1 pasos de unión sucesivos. Para el test, el engranaje v1 puede usar patternCircular y luego fusionar de a pares. | El test necesita un loop de uniones |
| G-5 | **No hay `bundle.ui-testing` target**: no existe aún. Añadirlo a project.yml requiere plist propio + bundle id + ajuste de firma. El CI no tiene un paso `-only-testing:AppForgeStudioUITests`. | Trabajo de infra requerido antes de GestureProbe |
| G-6 | **Pencil-shim**: el seam existe en MetalView.swift:307 (`shouldReceive`) pero es `private` dentro de `Coordinator`. Para testear el shim desde un XCUITest se necesita exponer una vía (launch-arg o UserDefaults) que `Coordinator` lea en su init — actualmente no existe. | Requiere ~5 líneas en Coordinator + wiring desde UIProbeMode |
| G-7 | **UIProbeMode no ejerce gestos táctiles reales**: documenta honestamente que el arnés actual opera sobre VM/controllers directamente. Un XCUITest real sí inyecta gestos en el simulador (XCUIElement.tap / swipe). Ambos son complementarios. | El XCUITest target es el paso correcto para gestos reales |
