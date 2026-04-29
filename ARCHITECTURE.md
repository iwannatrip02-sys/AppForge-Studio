# AppForge Studio - Architecture Document
> 2026-04-27 18:32 UTC-5 | Creacion inicial

## Stack Tecnologico
- **Swift 5.9+** con SwiftUI (iOS 17+)
- **Metal 2** para pipeline de render GPU
- **Satin 0.3.0** (github.com/mattrajca/Satin) - framework Swift para Metal
- **ModelIO** y **MetalKit** para import/export de assets 3D
- **simd** para operaciones matematicas SIMD

## Arquitectura por Capas

### Capa 1: Entry Point
`AppForgeStudioApp.swift` -> crea `AppState` (ObservableObject) con:
- canvasVM (CanvasViewModel) - escena 3D + undo/redo
- toolVM (ToolViewModel) - herramientas activas + brush params
- exportVM (ExportViewModel) - exportacion async con progreso
- 4 modos via Picker: CAD, Sculpt, Hybrid, Render
- Boton Export que muestra ExportView

### Capa 2: ViewModels (Estado)
- **AppState**: selectedMode, showExport, scene, strokes
- **CanvasViewModel**: scene, selectedModelIndex, undo/redo scene-level (50 stacks), CRUD modelos
- **ToolViewModel**: activeMode (5), activeTool (10), brush params, symmetry, snap, transformSpace, presets
- **ExportViewModel**: @MainActor, exportModel() async, progreso 0.0-1.0, error handling, success alert

### Capa 3: Views (UI)
- **CADModeView**: toolbar 9 herramientas, toggle snap, boton mediciones
- **SculptModeView**: Picker esculpir/pintar, selector 9 brushes, slider radio, toggle simetria, undo/redo
- **HybridModeView**: 3 submodos (CAD/Sculpt/Paint), boton capas
- **ExportView**: selector formato (STL/OBJ), file picker, progreso, alerta

### Capa 4: Render (Metal)
- **MetalView**: UIViewRepresentable con MTKView, delegate Coordinator
  - Funciones de matriz: perspective_fov(), lookAt()
  - Interseccion ray-triangulo: rayTriangleIntersect()
  - Pipeline: vertex_main + fragment_main shaders
  - Depth testing, clear color
- **PaintRenderer**: pipeline Metal completo, paint texture 2048x2048
- **StrokeRenderer (PincelRenderer)**: strokeVertex/strokeFragment con billboard quads, blending
- **SatinRenderer**: ObservableObject wrappeando Satin.Renderer, updateScene()

### Capa 5: Logica de Modelado
- **BrushEngine**: 10 brush types, paintStroke() GPU, sculptStroke() deformacion, symmetry
- **SculptEngine**: deformadores (Pinch, Inflate, Smooth, Grab, Crease, Flatten)
- **CAD Tools**:
  - ExtrusionEngine: extrude face + lateral faces
  - BevelEngine: edge bevel con interpolacion segmentada
  - BooleanEngine: CSG (union funcional, diff/intersection requieren BSP)
  - LoopCutEngine: edge subdivision en 4 triangulos
  - MeasureEngine: distancia, area, volumen (teorema divergencia)

### Capa 6: Servicios
- **ExportService**: exportToOBJ() / exportToSTL() via MDLAsset
- **ModelLoadService**: loadModel(url), createPrimitive(box/sphere/cylinder/plane/torus) via MDLMesh

### Capa 7: Modelos de Datos
- **Vertex**: position(SIMD3), normal, uv, color
- **Mesh**: vertices + indices + buffers GPU
- **Model**: meshes + transform(mat4x4) + name
- **Scene3D**: models + strokes + Camera + Lighting
- **BrushPoint**: position, normal, pressure, tilt
- **BrushStroke**: points + BrushType + StrokeMode + params

## Flujo de Datos
1. Touch -> MetalView (touchesBegan/Moved) -> raycast 3D -> BrushEngine
2. BrushEngine -> deforma vertices en Mesh -> UploadToGPU()
3. CanvasViewModel.saveState() -> undo stack
4. MetalView.draw() -> pipeline Metal -> framebuffer
5. Export: ExportView -> ExportViewModel.exportModel() -> ExportService.exportToOBJ/STL()

## Decisiones de Arquitectura
- **Package.swift** con SPM y Satin 0.3.0 como unica dependencia externa
- **Undo/Redo dual**: BrushEngine para vertices, CanvasViewModel para escena completa
- **Render directo Metal** en lugar de SceneKit para control GPU total
- **Satin como ObservableObject** separado del pipeline directo de MetalView
- **Export via ModelIO** nativo (MDLAsset) en lugar de escritura manual de archivos

## Issues Arquitectonicos
1. SatinRenderer no es el pipeline activo (MetalView usa pipeline directo)
2. HybridMode no comparte estado de deformacion entre submodos
3. BooleanEngine incompleto (sin BSP tree)
4. Sources/ duplicado en raiz del proyecto