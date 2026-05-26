# Que tenemos y que falta — AppForge Studio iOS
> 2026-05-11 | Verificacion directa de disco

## QUE TENEMOS — 3 capas funcionales

### Capa 1: Entry point y UI shell (FUNCIONAL)
- `Core/UI/AppForgeStudioApp.swift`: @main con AppRootView, OnboardingView, LoadingScreenView, NavigationStack
- `Core/UI/ContentView.swift`: MetalView + SatinRenderer + BrushEngine + CanvasViewModel + Undo/Redo + multi-touch
- `Core/UI/CanvasViewModel.swift`: maneja scene, strokes, animationEngine, undo/redo, currentMode
- `Core/UI/AppState.swift`: isLoading, canvasVM, toolVM, themeManager, modeManager
- ThemeManager, ToolbarView, ColorPickerView, HapticService — todos existen

### Capa 2: Motores 3D (47 engines en Core/Engines/)
**Render**: SatinRenderer, PBRMaterial, IBLPipeline, SceneRenderer, LODManager
**Escultura**: SculptEngine + 8 deformers (Inflate, Flatten, Smooth, Grab, Pinch, Crease, Twist, Move)
**Animacion**: AnimationEngine, AnimationPlaybackController, MorphEngine
**CAD**: AssemblyEngine, BevelEngine, BooleanEngine, ChamferEngine, CSGEngine, ExtrusionEngine, FilletEngine, LoftEngine, MeasureEngine, OCCTEngine, SDFEngine, ShellEngine, Sketch2D, SolverSwift, SubdivisionEngine, SweepEngine
**Pintura**: BrushEngine, BrushStroke, PincelRenderer
**Mallas**: SatinMesh, Mesh, Model3D, Scene3D, MaterialData, MaterialEditorView, MaterialPresets

### Capa 3: Modulos SPM y Features (6 modulos + 7 modos)
- Sources/: AnimationEngine, CADCore, ExportService, RenderEngine, SculptEngine, UIComponents
- Features/: AnimationMode, CADMode, ExportMode, HybridMode, PaintMode, RenderMode, SculptMode
- Tests/: 6 archivos de test (AnimationEngineTests, AnimationPlaybackTests, ExportServiceTests, etc.)

## QUE FALTA — 3 brechas criticas

### Brecha 1: Package.swift sin verificar
No sabemos si Package.swift tiene targets correctos apuntando a Sources/ (modulos SPM) Y a Core/ (archivos sueltos). Si la app no compila puede ser por targets mal definidos o dependencias faltantes (Satin, MetalKit).

### Brecha 2: backup_sources/ puede tener codigo no integrado
backup_sources/ tiene 67 archivos. backup_sources_cadcore/ puede tener logica CAD duplicada o adicional. Hay que comparar si falta algo que no esta en Core/Engines/ o Features/.

### Brecha 3: Shaders Metal (.metal) no verificados
Core/Shaders/ existe pero no se ha listado su contenido. Si faltan shaders Metal, el pipeline de render falla al compilar.

## ORDEN DE TRABAJO RECOMENDADO

1. **Leer Package.swift** (5 min) — confirmar targets, dependencias, deployment target
2. **Listar Core/Managers/ y Core/Shaders/** (5 min) — ver que hay
3. **Comparar backup_sources vs estructura activa** (15 min) — ver si falta algo
4. **Intentar swift build** (30 min) — ver si compila, diagnosticar errores
5. **Ejecutar tests** (10 min) — ver cuantos pasan

Despues de eso sabremos exactamente que parchar para tener una app compilable y funcional.