# Diagnóstico de Reorganización — AppForge Studio
> 2026-04-27 19:30 UTC

## Resumen de la reorganización

### Problemas encontrados
1. **Triple ubicación de código fuente**: El proyecto tenía código esparcido en `ios-app/AppForgeStudio/AppForgeStudio/`, `ios-app/Sources/`, y `ios-app/AppForgeStudio/Core|Features|Models|UI/`
2. **3 archivos duplicados**: BrushEngine, ExportService y ModelLoader existían en dos versiones incompatibles
3. **Package.swift apuntando a la subcarpeta incorrecta**: path: "AppForgeStudio" en lugar de "."
4. **GOTCHI.md desactualizado**: Describía una estructura ideal que no existía
5. **Carpeta raíz AppForgeStudio/ vacía**: Solo contenía 3 subcarpetas sin archivos

### Acciones realizadas

**ELIMINADOS (3 archivos duplicados):**
- `AppForgeStudio/AppForgeStudio/BrushEngine.swift` — Versión simple (5 brush types, undo básico). Reemplazado por Features/SculptMode/Brushes/BrushEngine.swift (10 types, undo/redo 50 stacks)
- `AppForgeStudio/AppForgeStudio/ExportService.swift` — Versión que usaba Satin.Mesh. Reemplazado por Core/Services/ExportService.swift (usa Model, MTLDevice, MDLMesh completo)
- `AppForgeStudio/AppForgeStudio/ModelLoader.swift` — Versión que usaba Satin.Mesh. Reemplazado por Core/Services/ModelLoadService.swift (creates desde MDLMesh + 5 primitivas)

**MOVIDOS (3 archivos de Sources/ al target principal):**
- `Sources/ContentView.swift` → `UI/Components/ContentView.swift`
- `Sources/Shaders.metal` → `Resources/Shaders/Shaders.metal`
- `Sources/Renderer/PincelRenderer.swift` → `Core/Managers/PincelRenderer.swift`

**ACTUALIZADOS (4 documentos):**
- `Package.swift`: path cambiado de "AppForgeStudio" a "."
- `STRUCTURE.md`: Nuevo documento con árbol definitivo del proyecto
- `GOTCHI.md`: Reescrito con estructura real, archivos clave y convenciones
- `ESTADO_ACTUAL.md`: Actualizado con rutas reales y estructura

### Estado actual del código (17 archivos Swift)

**AppForgeStudio/ (2 archivos)**
- `AppForgeStudioApp.swift` — Entry point SwiftUI con 4 modos (CAD, Sculpt, Hybrid, Render) + selector en HStack
- `SatinRenderer.swift` — Wrapper de Satin Renderer con scene/camera

**Core/Managers/ (3 archivos)**
- `PaintRenderer.swift` — Pipeline Metal completo (render + compute), paintTexture 2048x2048, depth state
- `PincelRenderer.swift` — StrokeRenderer GPU-based con billboard quads (heredado de Sources)
- `Shaders.metal` — Shaders del core

**Core/Services/ (2 archivos)**
- `ExportService.swift` — Exportación STL/OBJ funcional vía ModelIO (MDLAsset + MDLMesh con vertex descriptor completo)
- `ModelLoadService.swift` — Carga de modelos desde archivo + 5 primitivas (box, sphere, cylinder, plane, torus)

**Features/ (3 archivos + 1 anidado)**
- `CADMode/CADModeView.swift` — 9 herramientas (Select, Move, Rotate, Scale, Extrude, Loop Cut, Bevel, Boolean, Measure)
- `SculptMode/SculptModeView.swift` — 9 brush options con sliders (radius, hardness, opacity) + undo/redo UI
- `SculptMode/Brushes/BrushEngine.swift` — 10 brush types, undo/redo 50 stacks, paint + sculpt + deformación
- `HybridMode/HybridModeView.swift` — Switch entre CAD/Sculpt/Paint con capas

**Models/ (3 archivos)**
- `BrushStroke.swift` — BrushPoint, BrushType (10: round, flat, textured, airbrush, clay, inflate, pinch, smooth, crease, grab), StrokeMode, BrushStroke, StrokeSegment
- `Mesh.swift` — Vertex (position, normal, uv, color), Mesh (with uploadToGPU), Model
- `Scene3D.swift` — Scene3D, Camera (position, target, up, fov), Lighting (ambient + directional)

**UI/Components/ (2 archivos)**
- `MetalView.swift` — UIViewRepresentable con pipeline Metal completo, perspective_fov, lookAt, rayTriangleIntersect
- `ContentView.swift` — Cámara orbital con quaternions, MagnificationGesture, touch 3D handler

### Pendiente
- Verificar compilación tras cambios
- Eliminar carpeta AppForgeStudio/ raíz
- Eliminar ios-app/Sources/AppForgeStudioApp.swift (duplicado)
