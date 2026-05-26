# AppForge Studio — BRAIN.md
> v1 | Updated: 2026-05-25 23:30 UTC | Post-limpieza y unificación

## ESTADO ACTUAL
Proyecto unificado en una sola estructura bajo `ios-app/AppForgeStudio/`. 130+ archivos Swift/Metal reales. Sin .git anidado, sin backups huérfanos, sin duplicados. Package.swift y project.yml coherentes con Satin Hi-Rez 0.4.0. Pendiente: hacer que compile en CI (xcodegen exit 74).

## ESTRUCTURA REAL (verificado en disco 2026-05-25)

```
ios-app/AppForgeStudio/
├── Package.swift                    ← SPM, Hi-Rez/Satin 0.4.0
├── project.yml                      ← XcodeGen config
├── Core/
│   ├── UI/          25 files        ← AppForgeStudioApp, ContentView, CanvasViewModel, AppState, etc.
│   └── Managers/     2 files        ← CADHistoryTree, StrokeRenderer
├── Sources/
│   ├── Engines/     49 files        ← Animation, Sculpt (8 deformers), PBR, IBL, Morph, CSG, CAD tools
│   ├── CSG/          4 files        ← BSPNode, CSGOperation, Polygon3D, Shape (BSP tree REAL)
│   ├── CAD/          2 files        ← ConstraintEngine, SnapEngine
│   ├── Shaders/      5 .metal       ← PBR, IBL diffuse/specular/BRDF, Boolean compute
│   ├── Services/     5 files        ← ExportService (STEP+OBJ+STL+USDZ+GLTF), CrashReporter, GPUCompute, Cache
│   ├── Theme/        3 files        ← AppTheme, ThemeManager
│   └── RenderEngine/ 1 file         ← RenderModeView
├── Features/
│   ├── CADMode/     20 files        ← CADModeView, CADSketchEngine, GeometryConstraintManager, Tools (7)
│   ├── ExportMode/   3 files        ← ExportView, ExportViewModel
│   ├── PaintMode/    2 files        ← PaintRenderer, PincelRenderer
│   ├── SculptMode/   2 files        ← SculptModeView, BrushEngine
│   ├── AnimationMode/1 file
│   ├── HybridMode/   1 file
│   └── RenderMode/   1 file
└── Tests/            7 files        ← AnimationEngine, ExportService, ModelCache, ConstraintManager tests
```

## ENTIDADES CLAVE

| Entidad | Tipo | Notas |
|---------|------|-------|
| Satin (Hi-Rez) | framework | Swift/Metal 3D — 0.4.0, repo oficial activo |
| Metal 2 | tech | GPU rendering + compute shaders |
| ModelIO/MetalKit | tech | Import/export modelos 3D |
| simd | tech | Matemáticas 3D (SIMD3, SIMD4, quaternion) |
| Shape.swift (BSP) | código | CSG booleano REAL con BSP tree nativo |
| IBLPipeline | código | Diffuse irradiance + specular prefilter + BRDF LUT |
| GitHub Actions | CI/CD | macOS runner, Xcode 16.0, xcodegen |

## BUGS CONOCIDOS (verificados en código)

| Bug | Archivo | Severidad | Estado |
|-----|---------|-----------|--------|
| BUG1: Layout GPU PBR (float3 padding) | SatinRenderer.swift | CRÍTICO | Pendiente |
| BUG2: updateAnimation doble por frame | SatinRenderer.swift | CRÍTICO | Pendiente |
| BUG3: UInt16 → UInt32 (>65k vértices) | SatinRenderer.swift | ALTO | Pendiente |
| BUG5: Normal matrix escala no-uniforme | Shaders.metal | ALTO | Pendiente |
| BUG7: Grab deformer dirección contraria | SculptEngine.swift | MEDIO | Pendiente |
| BUG9: rebuildSceneFrom cada frame | SatinRenderer.swift | ALTO | Pendiente |

## BLOQUEOS

1. Sin Mac → no se puede compilar localmente
2. Sin Apple Developer → no se puede firmar/deployar
3. CI falla: xcodegen exit code 74 (project.yml paths no coinciden con estructura)

## PRÓXIMAS ACCIONES
1. Corregir project.yml para que xcodegen encuentre todos los paths
2. Push a GitHub → ejecutar CI → ver errores reales de compilación
3. Iterar fixes de compilación desde Windows hasta que CI pase
4. Investigar sideloading gratuito (AltStore, 7 días) vs Apple Developer

## HISTORIAL
- 2026-05-25 23:30 UTC — Limpieza masiva: .git anidado eliminado, 100+ archivos huérfanos borrados, estructura unificada, Satin unificado, TODO.md y BRAIN.md reconstruidos con verdad verificada
- 2026-05-12 — CSG real implementado (BSP tree en Shape.swift), ExportServiceSTEP
- 2026-05-11 — Migración de estructura, morph targets, CAD constraint overlay
- 2026-05-07 — IBL pipeline verificado, análisis competitivo, diagnóstico PBR
