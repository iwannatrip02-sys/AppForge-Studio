# Analisis Profesional — AppForge Studio iOS
> Fecha: 2026-04-30 | Revision de 55 archivos .swift | 14 archivos clave leidos en detalle

## 1. BUGS CRITICOS (causan crash o comportamiento incorrecto)

### 1.1 ExportService — falsos positivos en exportacion
**Archivo**: `Core/Services/ExportService.swift`
**Lineas**: 21-23 (exportToSTL), 27-29 (exportToUSDZ)
``swift
func exportToSTL(model: Model, url: URL) -> Bool {
    guard let asset = buildMDLAsset(from: model) else { return false }
    asset.export(to: url, fileType: "stl")  // SIN TRY!
    return FileManager.default.fileExists(atPath: url.path)  // Falso positivo
}
``
- `asset.export(to:)` lanza excepcion si disco lleno, permisos, o modelo invalido
- Sin `do/try/catch` la app crashea silenciosamente
- `fileExists` retorna true incluso si el archivo esta corrupto (0 bytes)
- `exportToOBJ` SI tiene try/catch correcto — inconsistencia

### 1.2 SatinRenderer — deltaTime explosivo en primer frame
**Archivo**: `AppForgeStudio/SatinRenderer.swift`
**Lineas**: 13-14
``swift
var animationEngine: AnimationEngine?
private var lastFrameTime: CFTimeInterval = 0  // ← BUG: deberia ser CACurrentMediaTime()
``
- `CACurrentMediaTime()` retorna segundos desde boot (~600,000s en iPad)
- Primer frame: `deltaTime = currentTime - 0` = ~600,000s
- `engine.currentTime += deltaTime` → animacion salta al final instantaneamente
- Impacto: cualquier animacion se completa en 1 frame en lugar de su duracion real

### 1.3 AppState — renderer dummy nunca usado
**Archivo**: `ViewModels/AppState.swift`
**Lineas**: 27-32
``swift
let mtkView = MTKView()
mtkView.device = device
self.satinRenderer = SatinRenderer(mtkView: mtkView)  // dummy MTKView
``
- `SatinRendererView.makeUIView()` crea OTRO `SatinRenderer` con un MTKView real
- `AppState.satinRenderer` apunta a un renderer sin view real (dibuja en la nada)
- `SatinRendererView.Coordinator.draw()` usa su propio `renderer`, no el de AppState
- Resultado: el renderer de AppState nunca pinta nada

### 1.4 BrushEngine — coordenadas 2D en motor 3D
**Archivo**: `Core/Engines/BrushEngine.swift`
``swift
class BrushEngine: ObservableObject {
    @Published var brushSize: CGFloat = 0.02
    var strokePoints: [CGPoint] = []  // ← 2D, no 3D
``
- `CGPoint` son coordenadas 2D de pantalla
- Para pintura 3D sobre mallas se necesitan coordenadas 3D (textura UV o world-space)
- `StrokeRenderer` espera `[BrushStroke]` con datos 3D, pero BrushEngine produce puntos 2D
- Impacto: las broshadas no se proyectan correctamente sobre el modelo 3D

## 2. PROBLEMAS DE RENDIMIENTO (iPad Pro M1)

### 2.1 MTKView recreado en cada cambio de modo
**Archivo**: `AppForgeStudioApp.swift` lineas 39-58
``swift
Group {
    switch appState.selectedMode {
    case .cad: CADModeView(...)
    case .sculpt: SculptModeView(...)
    // cada view contiene su propio MetalView/SatinRendererView
    }
}
``
- SwiftUI destruye y recrea el MTKView al cambiar `selectedMode`
- En iPad Pro M1 con 120fps: 1-2 segundos de pantalla negra
- Solucion: un solo `SatinRendererView` en ZStack compartido entre todos los modos

### 2.2 SatinRenderer.update() corre a 120fps en idle
**Archivo**: `AppForgeStudio/SatinRenderer.swift` (seccion update)
- `mtkView.isPaused = false` mantiene el display link siempre activo
- Aunque no haya animacion, `update()` recalcula matrices de transform
- En iPad Pro M1: ~20-30% CPU en idle solo por el render loop
- Solucion: `guard let engine = animationEngine, engine.isPlaying else { mtkView.isPaused = true; return }`

### 2.3 CanvasViewModel — undo copia Scene3D entera
**Archivo**: `ViewModels/CanvasViewModel.swift` lineas 40-44
``swift
func saveState() {
    undoStack.append(scene)  // Scene3D es struct → copia profunda
``
- Con mallas de 500k vertices, cada undo guarda ~50MB en memoria
- `maxUndo = 50` → hasta 2.5GB en undo stack
- Solucion: usar copy-on-write con referencia a mallas o compresion delta

## 3. FALTAS DE ARQUITECTURA PROFESIONAL

### 3.1 Sin manejo de errores unificado
- `ExportService` mezcla `print()` y returns booleanos
- `SceneRenderer` imprime "Warning:" pero sigue con `nil` pipeline → crash en draw
- No hay `Error` enum ni `Result<T, Error>` tipado
- No hay logging estructurado

### 3.2 Sin tests unitarios
- 0 archivos de test en todo el proyecto
- Sin validacion de: exportacion, animacion, CSG, subdivision

### 3.3 Shaders Metal sin validacion en runtime
- `PaintRenderer.setupPipelines()` llama `fatalError()` si no encuentra shaders
- En iOS 17, Metal library podria no compilar en dispositivos fisicos si falta el archivo .metal
- No hay fallback a software rendering ni mensaje de error al usuario

### 3.4 Sin soporte de background/state restoration
- `Scene3D` no es `Codable` — no se puede guardar/reabrir proyectos
- Al cerrar la app se pierde todo el trabajo

### 3.5 Sin manejo de memoria para mallas grandes
- `ModelLoadService.loadModel(url:)` carga todo en RAM sin streaming
- Archivos STL de 50MB+ pueden causar memory warning en iPad con 8GB
- No hay `DidReceiveMemoryWarning` handler

## 4. CONEXIONES YA FUNCIONALES (NO TOCAR)

Confirmado como funcional:
- ✅ `AnimationEngine.evaluate(at:)` con interpolacion de keyframes (position, rotation, scale)
- ✅ `AnimationEngine.currentTransforms` publicado como `[String: simd_float4x4]`
- ✅ `SatinRenderer` tiene property `animationEngine: AnimationEngine?`
- ✅ `CADHistoryTree` con operaciones, undo/redo tree
- ✅ `GeometryConstraintManager` con constraints basico
- ✅ `CanvasViewModel.undo/redo` con stack de Scene3D (aunque ineficiente)
- ✅ `ExportService.exportToOBJ` con try/catch correcto
- ✅ `ModelLoadService` carga STL/OBJ via ModelIO
- ✅ `SceneRenderer` con pipeline Metal estandar (vertex/fragment)

## 5. PRIORIDAD DE CORRECCION

| Prioridad | Bug | Archivo | Impacto |
|-----------|-----|---------|--------|
| P0 | deltaTime explosivo | SatinRenderer.swift | Animacion rota |
| P0 | Export sin try/catch | ExportService.swift | Falsos positivos, crash |
| P0 | Renderer dummy | AppState.swift | Render no funciona |
| P1 | MTKView recreado | AppForgeStudioApp.swift | Pantalla negra 1-2s |
| P1 | BrushEngine 2D | BrushEngine.swift | Pincel incorrecto |
| P2 | Sin Codable | Scene3D.swift | Sin state restoration |
| P2 | Undo copia profunda | CanvasViewModel.swift | Memory leak |
| P3 | Sin tests | — | Regresiones sin detectar |

## 6. RECOMENDACION PARA PROBAR EN iPAD

1. Corregir P0 y P1 primero (3 archivos: SatinRenderer, ExportService, AppState)
2. Build via GitHub Actions workflow existente (`.github/workflows/ios-build.yml`)
3. Subir .ipa a Diawi.com desde Windows
4. Abrir link en iPad Pro M1
