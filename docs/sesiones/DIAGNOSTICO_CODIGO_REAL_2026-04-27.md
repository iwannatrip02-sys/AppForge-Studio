# AppForge Studio — Diagnostico de Codigo Real
> Fecha: 2026-04-27 | Basado en inspeccion directa del disco

## Archivos Existentes

### `ios-app/Sources/AppForgeStudioApp.swift`
- `@main` entry point con `@StateObject private var appState = AppState()`
- Navegacion superior con 5 modos: CAD, Sculpt, Paint, Hybrid, Render (AppState.AppMode.allCases)
- Boton Export (square.and.arrow.up) que activa `appState.showExport = true`
- Referencia a `appState.canvasVM.scene.models.isEmpty` para habilitar export
- Switch principal sobre `appState.selectedMode` que renderiza diferentes vistas

### `ios-app/Sources/ContentView.swift`
- `@Binding var scene: Scene3D` y `@Binding var strokes: [BrushStroke]`
- `brushEngine: BrushEngine?` opcional
- `isPaintMode: Bool` para diferenciar modo pintura vs navegacion
- DragGesture: orbit (minDistance 20) con quaternion rotation alrededor de target
- MagnificationGesture: zoom (push/pull camera along forward vector)
- Paint mode: minDistance 2, crea currentStroke en onChanged
- handleTouch callback para detectar punto 3D

### `ios-app/Sources/Renderer/PincelRenderer.swift`
- `class StrokeRenderer` con device MTLDevice
- Pipeline: strokeVertex + strokeFragment desde Metal library
- Blending: sourceAlpha + oneMinusSourceAlpha
- maxQuads: 65536
- render() con encoder, mvp matrix, batching

### `ios-app/Sources/Shaders.metal`
- VertexIn: position, normal, uv, color (attribute 0-3)
- VertexOut: position, worldNormal, uv, color, worldPosition
- Uniforms: modelMatrix, viewMatrix, projectionMatrix, ambientColor, lightDirection, lightColor, lightIntensity
- vertex_main: transforma a world space, calcula normal, pasa uv/color
- fragment_main: iluminacion difusa basica (N dot L), ambient + light * intensity * diff
- StrokeVertexIn: position, color, size (attribute 0-2)
- strokeVertex: point sprite con 6 vertices offsets (billboard)
- strokeFragment: pasa color

### `ios-app/Sources/Package.swift`
- swift-tools-version:5.9
- iOS 17+
- Dependencia: Satin 0.3.0 (github.com/mattrajca/Satin.git)
- executableTarget con path "."

## Lo que NO existe (pero el project brain menciona)

| Componente | Mencionado | Real |
|---|---|---|
| AppState struct | Si (referenciado) | NO existe en disco |
| Scene3D struct | Si (Binding) | NO existe en disco |
| BrushStroke struct | Si (array) | NO existe en disco |
| BrushEngine class | Si (opcional) | NO existe en disco |
| MetalView struct | Si (ContentView) | NO existe en disco |
| ExportService.swift | Si (project brain) | NO existe en disco |
| ModelLoadService.swift | Si (project brain) | NO existe en disco |
| ToolViewModel.swift | Si (project brain) | NO existe en disco |
| CADModeView.swift | Si (project brain) | NO existe en disco |
| SculptModeView.swift | Si (project brain) | NO existe en disco |
| ExportView.swift | Si (project brain) | NO existe en disco |
| HybridModeView.swift | Si (project brain) | NO existe en disco |
| PaintRenderer.swift | Si (project brain) | NO existe en disco |
| AppForgeStudio/Views/ | Si (GOTCHI.md) | NO existe en disco |
| AppForgeStudio/Core/ | Si (GOTCHI.md) | Solo carpeta vacia |
| AppForgeStudio/Features/ | Si (GOTCHI.md) | NO existe en disco |

## Lo que existe pero vacio
- `AppForgeStudio/MetalEngine/` — carpeta vacia
- `AppForgeStudio/Services/` — carpeta vacia
- `AppForgeStudio/Views/` — carpeta vacia

## Resumen
El proyecto tiene un esqueleto funcional pero minimo: 4 archivos Swift + 1 Metal shader. 
La app muestra navegacion por 5 modos, renderiza una escena 3D con iluminacion basica, 
y permite strokes basicos. Pero TODOS los componentes clave (AppState, Scene3D, BrushStroke,
BrushEngine, MetalView, todos los Services, ViewModels, y Views de Features) 
NO estan implementados. El project brain describe una arquitectura que no existe en disco.

Para que funcione en iPad: hay que crear ~15-20 archivos desde cero.
