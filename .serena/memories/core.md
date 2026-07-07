# AppForge Studio — Core

App iOS nativa (Swift/SwiftUI/Metal) de escultura 3D + CAD + pintura + animación + export. Objetivo: competir con Nomad Sculpt/Shapr3D. Se desarrolla desde Windows: **no hay compilación local**, todo se verifica en GitHub Actions (macOS runner).

## Mapa de código (todo bajo `ios-app/AppForgeStudio/`)
- `Sources/Engines/` — 50+ engines: Sculpt (10 deformers), Animation, PBR/IBL, Mesh, Model3D, Scene3D, SatinRenderer (render principal), SubdivisionEngine, VoxelRemesh, etc.
- `Sources/CSG/Shape.swift` — CSG real vía BSP tree; `Sources/LegacyCSG/` (BSPNode, CSGOperation, Polygon3D).
- `Sources/CAD/` — ConstraintEngine, SnapEngine. `Sources/Services/` — CADProfessionalEngine, GPUCompute, ModelLoad, export VM.
- `Sources/Shaders/` — 5 .metal (PBR, IBL, Boolean compute).
- `Core/UI/` — app entry (AppForgeStudioApp), ContentView, CanvasViewModel (estado central de escena). `Core/Managers/` — CADHistoryTree, StrokeRenderer. `Core/Services/ExportService/` — export OBJ/STL/USDZ/STEP/GLTF/FBX.
- `Features/` — vistas por modo: CADMode (la mayor), SculptMode, PaintMode, AnimationMode, HybridMode, ExportMode.
- `Tests/` — ~14 archivos XCTest.

## Docs canónicos (raíz del repo, mantener al día)
GOTCHI.md (reglas de trabajo), BRAIN.md (bugs/riesgos con rutas), TODO.md, DECISIONS.md. Leer BRAIN.md al inicio de sesión.

## Invariantes críticos
- `Scene3D` es struct → pasar `inout` al mutar desde engines.
- Structs Swift que mapean a Metal: `float3` = 16 bytes → agregar `var _pad: Float = 0`.
- `Mesh.indices` es `[UInt32]` (no UInt16) — soporta >65k vértices.
- Satin (Hi-Rez/Satin 13.0.0, repo archivado) vía SPM pineado a revisión exacta; espejo en `vendor/Satin/`; CI aplica un patch a Satin antes de compilar.

Estado: CI VERDE desde 2026-07-07; Fase A B-rep completa (179 tests). `Model.cadShape` = B-rep OCCT fuente de verdad; TODA operación de ingeniería va vía `BRepModeling` (Sources/Services) — booleanos entre modelos, fillet/chamfer/shell(cara abierta), pushPullFace (boss/pocket), exportSTEP real — con fallback a malla si no hay B-rep. Tests con oráculos de volumen exactos en BRepModelingTests. Fase B (manipulación directa): picking unificado en `Sources/Services/ScenePicking.swift` (CameraRay/ScenePicker/BRepFacePicker — NO duplicar raycast en vistas), `PushPullController` para el flujo tap-cara→boss/pocket, `docs/DISENO_INTERFAZ.md` = doc canónico de UI (regla: tocar geometría actúa, tocar vacío orbita) — leerlo antes de tocar UI. Invariantes de CI/firma/bundle que NO deben tocarse: `mem:ci_infra`.
API del kernel CAD: `mem:occtswift_api` (firmas reales verificadas de OCCTSwift — leer ANTES de escribir código que use Shape/Face/Exporter).

Ver `mem:tech_stack` (stack y dependencias), `mem:suggested_commands` (CI desde Windows), `mem:task_completion` (definición de done sin Mac), `mem:conventions` (estilo Swift del proyecto).
