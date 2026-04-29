# AppForge Studio — Análisis de Estado Actual
> 2026-04-29 16:05 UTC-5 | Basado en lectura de ~20 archivos clave

## Resumen
Proyecto en Fase 4 con 49 archivos .swift + 1 .metal. Código unificado en `ios-app/AppForgeStudio/`. Source legacy eliminado con backup.

## Arquitectura Confirmada (por capas)

### Entry Point
- `AppForgeStudioApp.swift`: Entry point con Onboarding + Navigation por modos (CAD/Esculpir/Hybrid/Render) + Botón Export
- `SatinRenderer.swift`: Wrap de Satin Renderer con `updateScene(_:)` que sincroniza Scene3D con la escena de Metal

### Estado Global
- `AppState.swift`: ObservableObject central con canvasVM, toolVM, exportVM, animationVM, subdivisionVM, satinRenderer
- `CanvasViewModel.swift`: Scene3D + undo/redo (50 stacks) + selección de modelo
- `ToolViewModel.swift`: Brush params (radius, hardness, opacity, color, symmetry) + BrushEngine factory

### Modelos
- `Scene3D.swift`: Struct con models, strokes, camera, lighting, CADHistoryTree, GeometryConstraintManager
- `Mesh.swift`: Malla con vertices/indices + uploadToGPU()
- `Model.swift`: Contenedor de meshes con nombre
- `BrushStroke.swift`: Datos de pincelada
- `CADHistory.swift`: Árbol de historial CAD
- `Model3D.swift`: Modelo 3D adicional (posible duplicado con Model.swift)

### Core/Managers (7 archivos)
- `AnimationEngine.swift`: Keyframes, Easing (linear/easeInOutQuad/easeInOutCubic/etc.), AnimationClip, reproducción por modelo
- `OCCTEngine.swift`: Singleton con Shape.box/cylinder/sphere/torus/cone + boolean operations (union/subtract/intersect) + fillet/chamfer/shell/extrude/revolve/sweep/loft
- `SubdivisionEngine.swift`: Catmull-Clark (hasta 4 niveles) + preview rápido (smooth solo vértices)
- `PaintRenderer.swift`: Pipeline Metal para pintura 3D
- `PincelRenderer.swift`: Stroke rendering con billboard quads + blending
- `SceneRenderer.swift`: Pipeline Metal completo con vertex/fragment shaders, depth testing, blending
- `Shaders.metal`: Código Metal de shaders

### Core/Services
- `ExportService.swift`: Export a OBJ/STL/STEP/USDZ usando ModelIO + OCCT
- `ModelLoadService.swift`: Carga de modelos 3D

### Features
- `CADMode/`: 8 archivos incluyendo BevelEngine, BooleanEngine, CADToolEnum, ExtrusionEngine, LoopCutEngine, MeasureEngine
- `SculptMode/`: SculptModeView + Brushes/
- `HybridMode/`: HybridModeView con 3 submodos (CAD/Sculpt/Paint) + boton capas
- `ExportMode/`: ExportView con selector formato (STL/OBJ/STEP/USDZ/GLTF), file picker, progreso

### UI/Components (7 archivos)
- `MetalView.swift`: UIViewRepresentable con MTKView, funciones perspective_fov/lookAt/rayTriangleIntersect, delegate Coordinator
- `TimelineView.swift`: Timeline de animación
- `ToolbarView.swift`: Toolbar contextual
- `OnboardingView.swift`: Tutorial inicial
- `ContentView.swift`, `SatinRendererView.swift`, `ColorPickerView.swift`

---

## Problemas Detectados

### 1. AnimationEngine.init(self) — FALLA DE COMPILACIÓN
- **Archivo**: `AppState.swift` línea 24: `self.animationVM = AnimationEngine(appState: self)`
- **Archivo**: `AnimationEngine.swift` espera `init(appState:)`
- **Causa raíz**: AnimationEngine fue refactorizado para recibir appState (probablemente para acceder a Scene3D durante reproducción), pero el initializer se implementó en una versión y AppState quedó desincronizado con otra
- **Solución**: Leer AnimationEngine completo para ver la firma exacta del init

### 2. ExportView recibe Model directamente — VIOLA MVVM
- **Archivo**: `ExportView.swift` línea: `struct ExportView: View { let model: Model`
- **Problema**: ExportView recibe un modelo como parámetro directo en lugar de usar solo exportVM, rompiendo el patrón MVVM
- **Solución**: ExportView debería obtener el modelo desde exportVM.model o desde AppState.canvasVM.modeloSeleccionado

### 3. Model.swift vs Model3D.swift — POSIBLE DUPLICADO
- **Archivos**: `Models/Model.swift` y `Models/Model3D.swift`
- **Problema**: Ambos parecen definir un contenedor de meshes. Model3D fue migrado de Sources legacy pero Model ya existe en la estructura unificada
- **Solución**: Verificar si Model3D tiene funcionalidad extra (normals, UVs, materiales) y unificar

### 4. SceneRenderer usa makeDefaultLibrary() — SIN RUTA EXPLÍCITA
- **Archivo**: `SceneRenderer.swift` línea: `guard let library = device.makeDefaultLibrary()`
- **Problema**: makeDefaultLibrary() asume que el .metal está en el mismo bundle que el ejecutable. En Swift Packages puede fallar
- **Solución**: Usar device.makeLibrary(filepath:) con ruta absoluta o incluir Shaders.metal como recurso del package

### 5. Archive/ contiene planes legacy no migrados
- **Archivos**: `archive/plan_desarrollo.md`, `PLAN_ESTRATEGICO.md`, `STRUCTURE_PLAN.md`
- **Problema**: No están integrados en GOTCHI.md ni BRAIN.md

---

## Próximas Acciones (priorizadas)

1. **CRÍTICO**: Corregir `AnimationEngine.init(appState:)` — leer firma exacta y sincronizar con AppState
2. **ALTA**: Refactorizar ExportView para usar solo exportVM (MVVM)
3. **MEDIA**: Unificar Model.swift y Model3D.swift
4. **BAJA**: Mover contenido relevante de archive/ a GOTCHI.md y BRAIN.md
5. **INFORMATIVO**: SceneRenderer.makeDefaultLibrary() puede fallar en Swift Package — monitorear
