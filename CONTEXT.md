# CONTEXT — Lenguaje común de AppForge Studio

> El glosario y las decisiones difíciles del proyecto. Léelo antes de codear.
> Objetivo del producto: **reemplazar a Shapr3D por completo** en iPad (ver
> `docs/ARQUITECTURA_MAESTRA.md`). Regla de oro: **nada se declara hecho sin
> verificar en device**; cero botones falsos.

## Vocabulario (usar estos términos en código, commits y specs)

- **Workspace** — un modo de la app sobre UN documento compartido: CAD, Sculpt,
  Paint, Animation, Render, Manufacture. No se "exporta" entre workspaces.
- **SceneDocument** (`.appforge`) — el documento único. Contiene `models[]`
  (B-rep + malla + materiales), `cadHistory` (DAG), animación, config.
- **Sketch entity** (`SketchController.Entity`) — una figura 2D dibujada:
  `polyline` (cerrada o abierta), `rect`, `circle`, `polygonEnt`, `spline`.
  Viven en `SketchController.entities`, **no** son `scene.models`.
- **Perfil cerrado** (`isClosedProfile`) — entity que encierra área → extruible.
- **Región** — área cerrada formada por intersección de varios segmentos
  (grafo planar), no un solo perfil. Debe volverse tocable → 3D. HOY INCOMPLETO.
- **Plano de trabajo** (`WorkPlane`) — origen + ejes u/v + normal donde se
  dibuja. El piso (`.floor`) es el caso por defecto.
- **Feature tree / DAG** (`CADHistoryTree`) — historial paramétrico con
  snapshots B-rep por nodo. Más general que el timeline lineal de Shapr3D.
- **B-rep** — geometría exacta OCCT (`model.cadShape`). Fuente de verdad de
  ingeniería. La **malla** (`model.meshes`) es su teselado para render.
- **GeometryActor** (planeado) — toda op OCCT pesada fuera del main thread.
- **Rayo de cámara** (`CameraRay.from`) — convierte un toque de pantalla a rayo
  mundo. DEBE coincidir con `SatinRenderer.projectionMatrix` o el toque se
  desfasa (ver ADR-0001).

## Deuda arquitectónica conocida (NO empeorar; preferir consolidar)

1. **Doble sistema de sketch**: `SketchController` (el que dibuja en vivo, el
   bueno) y `CADSketchEngine` (usado solo por el timeline). Consolidar hacia
   `SketchController`. El `CADHistoryTree` del timeline vive en `CADSketchEngine`.
2. **Tres enums de modo duplicados**: `AppState.AppMode`,
   `CanvasViewModel.AppMode`, `WorkspaceToolViewModel.ActiveMode`. Unificar en
   un `Workspace` canónico (tarea F-WS-0).
3. **Capa de interacción del sketch frágil**: el overlay visible tiene
   `allowsHitTesting(false)`; toda entrada pasa por el raycast del `MetalView`.
   La selección directa sobre figuras en el lienzo aún no es buena.

## Cómo se verifica el trabajo (feedback loops)

- Sin Mac local: `swiftc -parse` (toolchain 6.3.2) atrapa sintaxis; el
  **typecheck completo y los tests corren en CI** (`build.yml`, ~15 min).
- El único workflow válido es `.github/workflows/build.yml` → artifact
  `AppForgeStudio-unsigned-ipa`. Verde = compila + 41 tests + IPA.
- Verificación final: el usuario instala el IPA vía AltStore (botón `+`) y
  prueba en iPad Pro M1. Device loop con `pymobiledevice3` disponible.
- **TDD (skill `tdd`)**: para lógica pura (proyección, selección, detección de
  regiones, solver) escribir el test que falla ANTES del fix. Ya atrapó 6 bugs.

## Mapa de archivos clave del CAD

- `Sources/Services/SketchController.swift` — dibujo 2D, entities, drag de puntos.
- `Sources/Services/ScenePicking.swift` — `CameraRay`, hit-test de escena.
- `Core/UI/MetalView.swift` — gestos, raycast toque→plano (`planePoint`).
- `Features/CADMode/CADModeView.swift` — la vista: overlays, gestos, panel Elementos.
- `Core/Managers/CADHistoryTree.swift` — feature tree DAG.
- `Sources/Engines/SolverSwift.swift` — solver de constraints (Newton + Gauss).
- `Sources/Engines/SatinRenderer.swift` — matrices de cámara y render Metal.
