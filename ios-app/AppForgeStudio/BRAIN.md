# AppForge Studio — BRAIN.md
> Updated: 2026-05-29

## ESTADO ACTUAL
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
| BUG7: Grab deformer direccion contraria | SculptEngine.swift | MEDIO |
| BUG9: rebuildSceneFrom cada frame | SatinRenderer.swift | ALTO |

## BLOQUEOS
- Sin Mac → no compilar localmente
- Sin Apple Developer → no firmar/deployar
- Satin repo archivado (ultimo tag 13.0.0, Abril 2025)

## HISTORIAL
- 2026-05-26 04:30 UTC — Fix de 7 bugs de compilacion + assets + CI + tests + Satin 13.0.0
- 2026-05-25 23:30 UTC — Limpieza masiva: .git anidado eliminado, 100+ archivos huerfanos borrados, estructura Sources/ unificada
- 2026-05-12 — CSG real implementado (BSP tree en Shape.swift)
- 2026-05-11 — Migracion de estructura, morph targets, CAD constraint overlay
- 2026-05-07 — IBL pipeline verificado, analisis competitivo
