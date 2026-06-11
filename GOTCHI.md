# AppForge Studio — GOTCHI.md
> ID: d80c1c08 | Estado: active | Actualizado: 2026-06-10
> Workspace: C:\Users\USUARIO\Projects\appforge-studio

## Descripcion

App iOS nativa de pintura 3D + escultura + CAD + animacion + exportacion a impresion 3D.
Objetivo: superar a Nomad Sculpt ($14.99) y competir con Shapr3D ($299/ano) con una sola app unificada.

## Tech Stack

- Swift 5.9+, SwiftUI (iOS 17+)
- Metal 2 — render pipeline PBR + compute shaders
- **Satin (Hi-Rez/Satin 13.0.0)** — framework Metal/Swift via SPM
- ModelIO / MetalKit — carga y exportacion de modelos 3D
- simd — matematicas 3D

## Estructura canonica (post-limpieza jun-2026)

- **Docs canonicos SOLO en raiz**: BRAIN.md, TODO.md, DECISIONS.md, GOTCHI.md
- **Codigo SOLO en ios-app/AppForgeStudio/{Core,Features,Sources,Tests}**
- **Info.plist** vive en `ios-app/AppForgeStudio/AppForgeStudio/` y lo referencia `project.yml` (NO mover)
- **Workflow CI** unicamente `.github/workflows/build.yml` de la raiz
- **vendor/Satin/**: clon 13.0.0 para vendorizacion futura (fase FR). SPM sigue usando paquete oficial.

## Estructura de archivos

```
ios-app/AppForgeStudio/
├── Package.swift                          ← dependencias SPM
├── Sources/
│   ├── Engines/                           ← Animation, Sculpt (10 deformers), PBR, IBL, Morph, etc.
│   ├── CSG/                               ← Shape.swift (CSG real BSP), BSPNode, CSGOperation, Polygon3D
│   ├── CAD/                               ← ConstraintEngine, SnapEngine
│   ├── Shaders/      5 .metal             ← PBR, IBL, Boolean compute
│   ├── Services/                          ← CrashReporter, ExportViewModel, GPUCompute, Cache, ModelLoad
│   ├── Theme/                             ← AppTheme, ThemeManager
│   └── RenderEngine/                      ← RenderModeView
├── Core/
│   ├── UI/              25 files          ← AppForgeStudioApp, ContentView, CanvasViewModel, etc.
│   ├── Managers/         2 files          ← CADHistoryTree, StrokeRenderer
│   └── Services/ExportService/ 1          ← ExportService (OBJ/STL/USDZ/STEP/GLTF/FBX)
├── Features/             30 files         ← CADMode(20), ExportMode(3), PaintMode(2), SculptMode(2), etc.
├── Resources/
│   └── Assets.xcassets/                  ← AppIcon + AccentColor
└── Tests/                 7 files         ← ~25-30 tests
```

## Reglas de trabajo en este proyecto

1. **No compilar localmente** — Windows no tiene Swift. Verificar sintaxis con analisis estatico; push a GitHub CI para compilacion real.
2. **Para editar codigo iOS** — usar `code_agent` con rutas absolutas completas desde `C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Sources\`.
3. **Para estructuras GPU** — verificar alineacion de bytes: `float3` en Metal = 16 bytes (con 4 bytes de padding), no 12. Agregar `var _pad: Float = 0` en Swift structs que mapean a float3 en Metal.
4. **Para cambios grandes** — 1 modulo a la vez, no cambiar 3 archivos en paralelo sin verificar dependencias.
5. **BRAIN.md** tiene los bugs criticos con rutas exactas — leerlo al inicio de cada sesion.
6. **`Scene3D` es struct** — pasar por `inout` cuando se muta desde un engine (ver TODO.md → bug AnimationEngine).
7. **Cambios al pipeline Metal**: validar con Xcode antes de marcar como hechos.
8. **Backup de Sources legacy** en `../Sources_backup.zip` por si algo falta tras la migracion del 2026-04-28.

## Competidores referencia

| App | Precio | Enfoque | Debilidad |
|-----|--------|---------|-----------|
| Nomad Sculpt | $14.99 | Escultura | Sin CAD, sin animacion |
| Shapr3D | $299/ano | CAD | Sin escultura, precio alto |
| Feather 3D | $9.99/mes | Pintura 3D | Solo pintura, sin modelado |
| Forger | $9.99 | Escultura basica | Inferior a Nomad |

## Diferenciacion

AppForge Studio unifica pintura 3D + escultura + CAD + animacion + export (OBJ/STL/USDZ/GLTF/STEP) en una sola app nativa iOS. Ningun competidor hace las 5.

## Historial de decisiones clave

- Satin (Metal framework) elegido sobre SceneKit → control GPU total
- CSG booleano real con BSP tree nativo en Shape.swift (sin dependencia OCCT)
- Undo/redo dual: brush-level (SculptEngine 50) + scene-level (CanvasViewModel 50)
- GitHub Actions CI/CD con macos-14 para compilar desde Windows
- Open-source con monetizacion por publicidad no intrusiva + modelo open-core
