# SPEC — Ola GestureProbe: engranaje por gestos reales + fábrica de tutoriales
> 2026-07-15 · Hechos: `docs/specs/RECON_GESTUREPROBE_2026-07-15.md`. Pedido de Andrés:
> simular gestos naturales (dedos + pencil) en CI modelando un ENGRANAJE técnico,
> capturando cada paso y cada herramienta para (1) verificación a máximo detalle y
> (2) tutoriales automáticos gratis en video. Ejecutan G-A (Opus, infra/tests) y
> G-B (Sonnet, app-side) con propiedad DISJUNTA.

## Verdades de alcance (honestidad)
- XCUITest sintetiza toques REALES del sistema (tap/drag/2-dedos/pinch) sobre la UI real.
- Pencil: SIN API pública de presión/stylus en simulador → shim honesto `-UIProbeForcePencil`
  (fuerza la clasificación pencil en el seam `MetalView.swift:307`); el trazo es real, la
  presión no. El feel de presión se calibra solo en device.
- Engranaje v1 = disco (cilindro h==r, "grueso") + diente caja + patrón circular + unión
  (si el patrón no fusiona, unir lo posible; n−1 booleans es aceptable v1) + agujero (Hole).
  Involuta real llegará con arcos de sketch. Cero fingir.

## CONTRATO — accessibility identifiers (frontera G-A ↔ G-B)
G-B los ASIGNA en la UI; G-A los CONSUME en los tests. Strings EXACTOS (ninguno existe hoy):
```
home.newProject          → botón crear proyecto (galería Home)
cad.tool.select | cad.tool.move | cad.tool.rotate | cad.tool.scale
cad.tool.sketch | cad.tool.extrude | cad.tool.hole
cad.primitives.menu      → flyout/menú de primitivas
cad.primitive.box | cad.primitive.cylinder
cad.selection.body       → botón "Cuerpo" del selectionBar (escala selección cara→cuerpo;
                           precondición del menú de patrón: bodyIndex != nil)
cad.pattern.menu         → botón Patrón ○ del selectionBar (abre POPOVER de parámetros —
                           era Menu, pero UIMenu descarta los Stepper)
cad.pattern.circular.count | cad.pattern.circular.apply
cad.pattern.linear.menu | cad.pattern.linear.count | cad.pattern.linear.spacing | cad.pattern.linear.apply
cad.boolean.union | cad.boolean.subtract
cad.numeric.field        → NumericField genérico (el activo)
cad.export.button        → botón Exportar del chrome CAD
transform.hud            → TransformHUD (el número vivo)
```
Regla G-B: identifier NO cambia el label español visible (accesibilidad real intacta).
Regla G-A: NUNCA localizar por texto español; solo por identifier o coordenada normalizada del viewport.

## Carril G-A — infra XCUITest + tutoriales (Opus)
**Dueño exclusivo:** `ios-app/AppForgeStudio/project.yml` (¡delicado! leer memoria `ci_infra`),
`ios-app/AppForgeStudio/UITests/` (NUEVO), `.github/workflows/ui-probe.yml`, `scripts/ui-probe/`.
PROHIBIDO: build.yml y todo el código fuente de la app.
1. Target XcodeGen `AppForgeStudioUITests` (`type: bundle.ui-testing`): plist propio
   (patrón del test target existente, BNDL), bundle id `com.appforgestudio.app.uitests`,
   firma ad-hoc idéntica (`CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- OTHER_CODE_SIGN_FLAGS=--deep`).
2. `UITests/GearScenarioTests.swift`: el escenario del ENGRANAJE con gestos reales, cada paso:
   (a) `os_log "GESTURE-STEP N: <herramienta> — <acción>"`, (b) screenshot XCTAttachment,
   (c) assert verificable (existe el cuerpo nuevo, el panel cambió, etc. — vía accessibility).
   Pasos: nuevo proyecto → crear cilindro (disco) → crear caja (diente) → mover diente al borde
   (drag de gizmo por coordenadas) → seleccionar (cara) → Cuerpo (escalar a cuerpo) →
   patrón circular count=5 (presupuesto CI: el sim por software de los runners colapsa
   con 9 cuerpos; en device el barrido usará 8+) → aplicar → unión
   (lo alcanzable) → Hole en el centro de la cara superior → órbita 1-dedo en vacío + pinch zoom
   (inspección final). Launch args: `-UIProbeSkipOnboarding` (reusar el sello de onboarding
   existente de UIProbeMode) y `-UIProbeTouchViz` (visualizador de G-B).
3. Workflow: step nuevo en ui-probe.yml (después del probe actual, `continue-on-error: false`):
   `xcodebuild test -only-testing:AppForgeStudioUITests` con el MISMO simulador ya booteado
   (destination por UDID) + recordVideo de la sesión en paralelo. Extraer attachments del
   .xcresult (xcresulttool; fallback xcparse vía brew) a `artifacts/gesture-steps/`.
4. Tutoriales: `scripts/ui-probe/segment_video.py` — parsea los timestamps de `GESTURE-STEP N`
   del log + el inicio del video → corta con ffmpeg (brew) clips por paso:
   `artifacts/tutorials/NN-<slug-herramienta>.mp4`. Manifest `tutorials.json` (paso, herramienta,
   rango de tiempo, archivo). Upload como artifact `ui-probe-tutorials`.
5. Si el runner no puede (ffmpeg/xcresulttool fallan): degradar con gracia (video completo +
   manifest igual suben; el corte se puede hacer local después).

## Carril G-B — app-side (Sonnet)
**Dueño exclusivo:** `Features/CADMode/CADModeView.swift` (edits ADITIVOS mínimos),
`Core/UI/MetalView.swift`, `Core/UI/AppForgeStudioApp.swift`, `Sources/Services/UIProbeMode.swift`,
`Core/UI/TouchVisualizer.swift` (NUEVO), tests ligeros.
1. Asignar TODOS los identifiers del contrato (arriba) a sus controles reales (el RECON B
   tiene file:línea de cada botón). `.accessibilityIdentifier(...)`, sin tocar labels.
2. Pencil-shim: en `MetalView.swift:307` (`gestureRecognizer(_:shouldReceive:)`):
   `lastTouchWasPencil = (touch.type == .pencil) || UIProbeMode.forcePencil` donde
   `forcePencil` = launch-arg `-UIProbeForcePencil` (en UIProbeMode, patrón existente).
   SOLO evaluado si el arg está (cero costo en producción).
3. `TouchVisualizer.swift`: overlay debug-only (activado por `-UIProbeTouchViz`): UIWindow/passthrough
   view que dibuja círculos ember en los puntos de toque activos (para que los tutoriales muestren
   los dedos). Cero hit-testing (userInteractionEnabled=false), cero efecto sin el flag.
4. Test ligero: sin flags, `forcePencil==false` y el visualizador no se instala (blindaje producción).

## Criterios de aceptación
**CI (ui-probe.yml):** GearScenarioTests verde con el engranaje construido por toques reales;
attachments por paso en artifacts; clips de tutorial (o video+manifest si degradó) en artifacts.
**Revisión (Sonnet visión):** capturas de cada paso muestran la herramienta correcta en uso;
el engranaje final tiene dientes visibles + agujero central.
**Producción intacta:** sin flags, cero efecto (tests de blindaje).

## Fuera de alcance
Presión real de Pencil (device); engranaje involuto (necesita arcos de sketch); publicar los
tutoriales (solo generarlos); voice-over/subtítulos de los clips.
