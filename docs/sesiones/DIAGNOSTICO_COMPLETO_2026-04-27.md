# Diagnóstico Completo — AppForge Studio
> 2026-04-27 | Verificación post-exploración

## Resumen de Archivos

### Rama A — `ios-app/Sources/` (4 archivos, plana)
| Archivo | Estado | Notas |
|---------|--------|-------|
| AppForgeStudioApp.swift | OK | 3 modos (CAD, Sculpt, Hybrid), generateSphereVertices inline |
| ContentView.swift | OK | Cámara orbital, handleTouch, gestos drag/magnificación |
| Renderer/PincelRenderer.swift | OK | StrokeRenderer con billboard quads |
| Shaders.metal | PARCIAL | Solo strokeVertex y strokeFragment básicos (sin vertex_main/fragment_main) |

### Rama B — `ios-app/AppForgeStudio/` (22+ archivos, estructura completa)
| Archivo | Estado | Notas |
|---------|--------|-------|
| Package.swift | OK | Satin 0.3.0, iOS 17, target path "." |
| AppForgeStudio/AppForgeStudioApp.swift | OK | 4 modos (CAD, Sculpt, Hybrid, Render), botón exportación |
| AppForgeStudio/SatinRenderer.swift | OK | Wrapper Satin framework (no conectado) |
| Models/Scene3D.swift | OK | Camera, Lighting, modelos, strokes |
| Models/Mesh.swift | OK | Vertex struct, uploadToGPU |
| Models/BrushStroke.swift | OK | 10 brush types, StrokeMode, interpolación |
| Core/Managers/PaintRenderer.swift | OK | Pipeline Metal con vertex_main/fragment_main, compute pipeline |
| Core/Managers/PincelRenderer.swift | OK | StrokeRenderer con stroke shaders |
| Core/Managers/Shaders.metal | COMPLETO | vertex_main, fragment_main con iluminación, strokeVertex/StrokeFragment con billboard quads |
| Core/Services/ExportService.swift | OK | Exportación OBJ/STL vía ModelIO |
| Core/Services/ModelLoadService.swift | OK | Carga de modelos + 5 primitivas |
| Features/CADMode/CADModeView.swift | OK | 9 herramientas CAD, grid snap, mediciones |
| Features/CADMode/Tools/ | DIR | Vacío (herramientas sin implementar) |
| Features/SculptMode/SculptModeView.swift | OK | 9 brush options, modo paint/sculpt, sliders |
| Features/SculptMode/Brushes/BrushEngine.swift | OK | 10 brush types, applyDeformation, undo/redo 50 niveles |
| Features/HybridMode/HybridModeView.swift | OK | 3 submodos (CAD/Sculpt/Paint), capas |
| Features/ExportMode/ExportView.swift | OK | UI exportación con formato selector, progress, success/error |
| UI/Components/ContentView.swift | OK | Cámara orbital, handleTouch con raycast |
| UI/Components/MetalView.swift | OK | Metal pipeline, MTKView, ray-triangle intersection, touch handling |

### Rama C — `AppForgeStudio/` raíz (3 carpetas VACÍAS)
| Carpeta | Estado |
|---------|--------|
| MetalEngine/ | VACÍA |
| Services/ | VACÍA |
| Views/ | VACÍA |

## Problemas Detectados

### 🔴 CRÍTICO — Duplicación de código
- **Shaders.metal** existe en 2 lugares: `Sources/Shaders.metal` (solo stroke shaders) y `Core/Managers/Shaders.metal` (completo con vertex/fragment + stroke). El de Sources/ NO tiene vertex_main/fragment_main, lo que haría fallar PaintRenderer en runtime.
- **PincelRenderer.swift** existe en `Sources/Renderer/` y `Core/Managers/` — mismo contenido.
- **AppForgeStudioApp.swift** existe en `Sources/` (3 modos) y `AppForgeStudio/AppForgeStudio/` (4 modos con export). Son diferentes.
- **ContentView.swift** existe en `Sources/` y `UI/Components/` — la de Sources/ no tiene MetalView import.

### 🟡 MEDIO — Arquitectura
- **Package.swift** apunta target path a "." — no refleja la estructura real de carpetas.
- **SatinRenderer** existe pero no está conectado al entry point. Decisión pendiente desde Fase 2.
- **Faltan ViewModels**: CanvasViewModel, ToolViewModel, ExportViewModel no existen como archivos.
- **SculptEngine** no existe como clase separada — la lógica de deformación está en BrushEngine.applyDeformation().
- **Faltan Deformers/**: inflate, pinch, smooth, crease, grab como clases separadas.

### 🟢 BAJO — Mejoras
- Carpeta raíz `AppForgeStudio/` está vacía y sobra (3 subcarpetas sin archivos).
- La documentación (ROADMAP.md, ESTADO_ACTUAL.md) describe la estructura de la Rama B pero referencias a SatinRenderer como existente en rutas incorrectas.
- No hay archivo .xcodeproj — solo se puede abrir desde Package.swift.

## Lo que FUNCIONA (verificado)

✅ **Shaders Metal**: Core/Managers/Shaders.metal tiene vertex_main (transformación MVP + iluminación), fragment_main (diffuse lighting), strokeVertex (billboard quads con offsets), strokeFragment (alpha blending + falloff)
✅ **PaintRenderer**: Pipeline Metal completo con depth testing, compute pipeline, paint texture 2048×2048
✅ **StrokeRenderer**: Render de strokes con billboard quads, blending alpha, MVP matrix
✅ **ExportService**: Exportación OBJ via MDLAsset.export(), STL via export con fileType, meshToMDL completo
✅ **BrushEngine**: 10 brush types, applyDeformation, undo/redo 50 niveles, saveState/undo/redo
✅ **Scene3D**: Cámara con position/target/up/fov, Lighting con ambient + directional
✅ **Mesh/Vertex**: Struct con position/normal/uv/color, uploadToGPU a MTLBuffer
✅ **MetalView**: MTKView con Coordinator, rayTriangleIntersect, perspective_fov, lookAt, touch handling con raycast 3D
✅ **ContentView**: Cámara orbital con quaternions, DragGesture, MagnificationGesture, handleTouch
✅ **CADModeView**: 9 herramientas (select, move, rotate, scale, extrude, loopCut, bevel, boolean, measure) + grid snap
✅ **SculptModeView**: 9 brush options, modo paint/sculpt, sliders radius/hardness/opacity/color, symmetry toggle
✅ **HybridModeView**: 3 submodos, layer system UI
✅ **ExportView**: Selector formato (STL/OBJ), botón exportar con progress, éxito/error
✅ **ModelLoadService**: Carga de modelos desde URL, 5 primitivas (box, sphere, cylinder, plane, torus)
✅ **SatinRenderer**: Wrapper funcional (no conectado)

## Fase Siguiente Recomendada

### Fase 3A — LIMPIEZA Y UNIFICACIÓN (urgente)
1. Eliminar carpeta raíz vacía `AppForgeStudio/`
2. Sincronizar Shaders.metal: unificar en Core/Managers/Shaders.metal (el completo)
3. Unificar AppForgeStudioApp: usar la de AppForgeStudio/AppForgeStudio/ (4 modos + export) 
4. Unificar ContentView: usar la de UI/Components/ (tiene binding a MetalView)
5. Consolidar Package.swift con paths correctos

### Fase 3B — VIEWMODELS + ARQUITECTURA MVVM
- Crear CanvasViewModel (gestión escena, cámara, selección)
- Crear ToolViewModel (estado herramientas, propiedades)
- Crear ExportViewModel (lógica exportación)

### Fase 3C — MOTOR DE ESCULTURA COMPLETO
- Crear SculptEngine.swift (deformadores independientes)
- Crear Deformers/ con clases: InflateDeformer, PinchDeformer, SmoothDeformer, CreaseDeformer, GrabDeformer
- Subdivisión de malla dinámica (Catmull-Clark)

### Fase 4 — CAD COMPLETO
- Extrusión de caras, Loop Cut, Bevel, Boolean operations
- Sistema de mediciones funcional

### Fase 5 — PREPARACIÓN PARA BUILD
- Generar .xcodeproj
- Configurar signing para iPad
- Build & Run en simulador/dispositivo
