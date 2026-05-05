# AppForge Studio — GOTCHI.md
> ID: d80c1c08 | Estado: active | Actualizado: 2026-05-04
> Workspace: C:\Users\USUARIO\Projects\appforge-studio

## Descripción

App iOS nativa de pintura 3D + escultura + CAD + animación + exportación a impresión 3D.
Objetivo: superar a Nomad Sculpt ($14.99) y competir con Shapr3D ($299/año) con una sola app unificada.

## Tech Stack

- Swift 5.9+, SwiftUI (iOS 17+)
- Metal 2 — render pipeline PBR + compute shaders
- **Satin (s1ddok)** — framework Metal/Swift (Package.swift debe apuntar a s1ddok, no mattrajca)
- ModelIO / MetalKit — carga y exportación de modelos 3D
- OCCTSwift — Open CASCADE Technology para CAD booleano
- simd — matemáticas 3D

## Estructura de archivos

```
ios-app/AppForgeStudio/
├── Package.swift                          ← dependencias SPM
├── Sources/
│   ├── AnimationEngine/                   ← AnimationEngine, PlaybackController, AnimationModeView
│   ├── CADCore/                           ← CAD tools, sketch, constraints, historia
│   ├── ExportService/                     ← ExportService (5 formatos), cache, crash reporter
│   ├── RenderEngine/                      ← SatinRenderer, PBRShaders.metal, Shaders.metal,
│   │                                         todos los modelos 3D y materiales
│   ├── SculptEngine/                      ← SculptEngine + 8 deformadores
│   └── UIComponents/                      ← AppState, CanvasViewModel, todas las vistas
└── Tests/                                 ← 23+ tests unitarios
```

## Reglas de trabajo en este proyecto

1. **No compilar localmente** — Windows no tiene Swift. Verificar sintaxis con análisis estático; push a GitHub CI para compilación real.
2. **Para editar código iOS** — usar `code_agent` con rutas absolutas completas desde `C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Sources\`.
3. **Para estructuras GPU** — verificar alineación de bytes: `float3` en Metal = 16 bytes (con 4 bytes de padding), no 12. Agregar `var _pad: Float = 0` en Swift structs que mapean a float3 en Metal.
4. **Para cambios grandes** — 1 módulo a la vez, no cambiar 3 archivos en paralelo sin verificar dependencias.
5. **BRAIN.md** tiene los bugs críticos con rutas exactas — leerlo al inicio de cada sesión.

## Competidores referencia

| App | Precio | Enfoque | Debilidad |
|-----|--------|---------|-----------|
| Nomad Sculpt | $14.99 | Escultura | Sin CAD, sin animación |
| Shapr3D | $299/año | CAD | Sin escultura, precio alto |
| Feather 3D | $9.99/mes | Pintura 3D | Solo pintura, sin modelado |
| Forger | $9.99 | Escultura básica | Inferior a Nomad |

## Diferenciación

AppForge Studio unifica pintura 3D + escultura + CAD + animación + export (OBJ/STL/USDZ/GLTF/STEP) en una sola app nativa iOS. Ningún competidor hace las 5.

## Historial de decisiones clave

- Satin (Metal framework) elegido sobre SceneKit → control GPU total
- OCCTSwift para CAD booleano real (union/subtract/intersect/fillet)
- Undo/redo dual: brush-level (SculptEngine 50) + scene-level (CanvasViewModel 50)
- GitHub Actions CI/CD con macos-14 para compilar desde Windows
