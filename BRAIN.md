# AppForge Studio — BRAIN.md
> Updated: 2026-07-08

## ESTADO ACTUAL — CI VERDE 🟢 (Fase C en curso, 205 tests)

2026-07-08 — **Fase C: capacidades CAD-pro verificadas** (rama `feature/fase-c`, PR #9, run 28908052457, 205 tests 0 fallos):
- Highlight de cara + undo/redo B-rep (BRepHistory) + overlays no-tocables.
- **Drawings 2D DXF** (`DrawingExportService`): B-rep → vistas ortográficas → DXF R12 (`Exporter.writeDXF`). Shapr3D lo cobra.
- **Feature Recognition** (`FeatureRecognitionService`): agujeros/cajeras desde el B-rep vía AAG (`shape.buildAAG` → `detectPockets`/`detectHoles`).
- BUG corregido (solo detectable por CI): `BRepHistory.swapTop` llamaba `syncCounts()` en un `defer` que leía los arrays `inout` prestados → "Fatal access conflict" crasheaba 4 tests. Fix: `syncCounts()` desde `undo()`/`redo()` tras liberar el borrow.
- LECCIÓN DE PROCESO: verificar firmas de OCCTSwift contra el **TAG pineado que CI resuelve** (v1.8.8 con `from:"1.0.0"`), NO contra HEAD del clon. HEAD tenía un enum `DXFExporter` que NO existe en 1.8.8 (ahí `writeDXF` está en `extension Exporter`) → build rojo "cannot find DXFExporter in scope". Ver `mem:occtswift_api`.

## ESTADO 2026-07-07 — Primer build verde completo de la historia del repo (run 28858291026, PR #6 → main `ca2ec00`):
- Build simulador ✓ + **165 tests, 0 fallos** ✓ + archive device ✓ + IPA sin firmar empaquetada ✓
- 20 olas de iteración: ~60 errores de compilación en ~25 archivos + 6 bugs de infra CI + 9 fallos de test reales
- Causa raíz dominante: código escrito contra APIs imaginarias (propias y de OCCTSwift) porque nadie podía compilar
- Bugs de PRODUCCIÓN encontrados por los tests: exports OBJ/STL/USDZ generaban 0 geometría
  (buildMDLAsset con descriptor vacío + Vertex crudo con UUID); validador de mallas crasheaba con caras huérfanas;
  USDZ requiere SceneKit en iOS (ModelIO no escribe .usdz)
- Infra CI aprendida (NO tocar sin razón): firma ad-hoc `CODE_SIGN_IDENTITY=-` + `--deep` (metallib),
  test bundle con Info.plist propio (BNDL) y bundle ID distinto, NUNCA `type: folder` para Resources
  (un dir Resources/ dentro del .app rompe la instalación: iOS lo trata como bundle deep)
- Toolchain Swift 6.3.2 instalado en Windows: `swiftc -parse` local + sourcekit-lsp para Serena
- API real de OCCTSwift documentada en `.serena/memories/occtswift_api.md` — LEER antes de tocar CAD

## ESTADO ANTERIOR (histórico)
2026-05-27 — Verificación de integridad post-OpenCode (Gotchi):

**Disco vs Docs — discrepancias encontradas:**
- Engines: 54 archivos reales (BRAIN decía 49). 5 extras: AssemblyEngine, DynamicTopologyEngine, LODManager, Sketch2D, SDFEngine.
- Tests: 7 archivos reales con ~25-30 tests totales (BRAIN decía "49 tests" — inflado).
- Sources/ raíz: vacío. Todo el código está en Core/ (29 archivos: UI 25 + Managers 2 + ExportService 1) y Sources/ (73 archivos: Engines 54, CSG 3, CAD 2, LegacyCSG 3, RenderEngine 2, Services 11, Shaders 5, Theme 1).
- Hi-Rez-Satin/: clon COMPLETO del framework (~350 archivos). Untracked en git. Debe ser agregado como dependencia local o .gitignored si se usa remoto.
- nul: archivo basura Windows en raíz del repo. Debe eliminarse.
- GOTCHI.md: dice Satin (s1ddok) pero Package.swift usa Hi-Rez/Satin 13.0.0. Inconsistencia de docs.
- CI: remote gotchi-nano/appforge-studio no encontrado. Verificar git remote -v real.

**10 commits OpenCode**: todos CI-focused. Build #12 pendiente de verificación.

## ESTRUCTURA REAL (post-fix 2026-05-26)

```
ios-app/AppForgeStudio/
├── Package.swift                    ← SPM Hi-Rez/Satin 13.0.0, iOS 17+
├── project.yml                      ← XcodeGen config + test target
├── .github/workflows/build.yml      ← CI: build + tests + archive + IPA
├── ExportOptions.plist              ← development signing
├── Core/
│   ├── UI/          25 files        ← AppForgeStudioApp, ContentView, CanvasViewModel, etc.
│   ├── Managers/     2 files        ← CADHistoryTree, StrokeRenderer
│   └── Services/ExportService/ 1    ← ExportService (OBJ/STL/USDZ/STEP/GLTF/FBX)
├── Sources/
│   ├── Engines/     49 files        ← Animation, Sculpt (10 deformers), PBR, IBL, Morph, etc.
│   ├── CSG/          4 files        ← Shape.swift (CSG real + 13 metodos nuevos), BSPNode, CSGOperation, Polygon3D
│   ├── CAD/          2 files        ← ConstraintEngine, SnapEngine
│   ├── Shaders/      5 .metal       ← PBR, IBL, Boolean compute
│   ├── Services/     5 files        ← CrashReporter, ExportViewModel, GPUCompute, Cache, ModelLoad
│   ├── Theme/        3 files        ← AppTheme, ThemeManager
│   └── RenderEngine/ 1 file         ← RenderModeView
├── Features/         30 files       ← CADMode(20), ExportMode(3), PaintMode(2), SculptMode(2), etc.
├── Resources/
│   └── Assets.xcassets/            ← AppIcon + AccentColor
└── Tests/            7 files        ← 49 tests total
```

## BUGS CORREGIDOS (2026-05-26)

| Bug | Archivo | Fix |
|-----|---------|-----|
| Dual Mesh/Vertex | Shape.swift → Mesh.swift | Eliminado struct duplicado, usa Mesh.swift |
| 13 metodos faltantes | Shape.swift | Implementados: triangulate, volume, area, boundingBox, exportSTEP, etc. |
| deltaTime use-before-def | SatinRenderer.swift:89 | Movido arriba de su uso |
| MDLMesh API invalida | ExportService.swift:332 | Reconstruido con vertex/index buffers |
| simd_float4x4(rotation) | AnimationEngine.swift:120 | Extension agregada |
| measureBoundingBox dup | OCCTEngine.swift:222 | Duplicado eliminado |
| Satin 0.4.0 no existe | Package.swift + project.yml | Cambiado a 13.0.0 |
| Sin AppIcon | Assets.xcassets | Creado |
| LaunchScreen storyboard | project.yml Info.plist | UILaunchScreen (iOS 17+) |
| Sin test target | project.yml | Test target agregado |
| BUG3: UInt16 → UInt32 (>65k vertices) | SatinRenderer.swift + Mesh.swift | Ya corregido (pre-F0): Mesh.indices es [UInt32], stride UInt32, draw call .uint32. Verificado: `grep -n "UInt16" SatinRenderer.swift` → 0 resultados |

## BUGS CONOCIDOS PENDIENTES

| Bug | Archivo | Severidad |
|-----|---------|-----------|
| BUG1: Layout GPU PBR (float3 padding) | SatinRenderer.swift | CRITICO |
| BUG2: updateAnimation doble por frame | SatinRenderer.swift | CRITICO |
| BUG5: Normal matrix escala no-uniforme | Shaders.metal | ALTO |
| BUG7: Grab deformer direccion contraria | SculptEngine.swift | CORREGIDO F0 — usa dragDelta con fallback |
| BUG9: rebuildSceneFrom cada frame | SatinRenderer.swift | CORREGIDO F0 — transforms in-place, rebuild solo con structureChanged |

## RIESGOS (F2 wave)

### R2 — Non-PBR sculpt geometry refresh
- **Descripción:** El path de sculpt en render(in:) ahora actualiza geometría de objetos Satin non-PBR in-place via `refreshNonPBRObjectGeometry(for:)`, siguiendo el mismo patrón de asignación de propiedades que `buildObject(from:)` (geometry.vertexBuffer, geometry.indexBuffer, geometry.vertexCount, geometry.indexCount).
- **Riesgo:** Satin Geometry expone `vertexCount`/`indexCount` como computed properties y `vertexBuffers` como diccionario `[VertexBufferIndex: MTLBuffer]`, no como `vertexBuffer` singular. Las asignaciones directas usadas en `buildObject` y `refreshNonPBRObjectGeometry` dependen de que el build de CI las acepte (pasan actualmente). Si en runtime estas asignaciones no tienen efecto, los objetos non-PBR esculpidos no se refrescarán visualmente.
- **Mitigación:** Si se detecta que la geometría non-PBR no se actualiza en runtime, implementar el fallback: flag `needsNonPBRRebuild` que dispare `rebuildSceneFrom()` UNA sola vez al terminar el stroke (cuando `modifiedModelIndices` queda vacío tras haber tenido modificaciones non-PBR), no por frame.
- **Impacto en tests:** El contador `rebuildCount` (usado por RendererRegressionTests) solo se incrementa si se activa el fallback. El path normal (in-place) no lo incrementa, preservando la garantía del test.

### R1 — modelNameToObject → modelIdToObject
- **Fix:** Migrado diccionario de clave `model.name` a `model.id.uuidString`. Model ya tiene `let id: UUID`. Elimina colisiones si dos modelos comparten nombre. Verificado: 0 referencias a `modelNameToObject` en el código.

## BLOQUEOS
- Sin Mac → no compilar localmente
- Sin Apple Developer → no firmar/deployar
- Satin repo archivado (ultimo tag 13.0.0, Abril 2025)

## HISTORIAL
- 2026-06-10 — F2 wave: R1 (modelIdToObject), R2 (non-PBR sculpt refresh + riesgo documentado)
- 2026-05-26 04:30 UTC — Fix de 7 bugs de compilacion + assets + CI + tests + Satin 13.0.0
- 2026-05-25 23:30 UTC — Limpieza masiva: .git anidado eliminado, 100+ archivos huerfanos borrados, estructura Sources/ unificada
- 2026-05-12 — CSG real implementado (BSP tree en Shape.swift)
- 2026-05-11 — Migracion de estructura, morph targets, CAD constraint overlay
- 2026-05-07 — IBL pipeline verificado, analisis competitivo
