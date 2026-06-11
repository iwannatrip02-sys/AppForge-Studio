# Sprint Fase 8-10: Diagnóstico y Avances

## Hallazgo #1: Arquitectura Real vs Brain Desactualizado

El brain.md y TODO.md describian una estructura fantasma `Sources/CADCore/` que NO existe.
La estructura REAL del proyecto (descubierta con python_exec recursivo):

- **Core/Engines/** (46 archivos): AnimationEngine, BevelEngine, BooleanEngine, BrushEngine,
  ChamferEngine, CreaseDeformer, CSGEngine, ExtrusionEngine, FilletEngine, GrabDeformer,
  IBLPipeline, InflateDeformer, LODManager, LoftEngine, MaterialData, Mesh, Model3D,
  MorphEngine, OCCTEngine, PBRMaterial, PincelRenderer, SatinRenderer, Scene3D,
  SceneRenderer, SculptEngine, SDFEngine, ShellEngine, Sketch2D, SolverSwift,
  SubdivisionEngine, SweepEngine, TwistDeformer, y mas.
- **Core/UI/** (25 archivos): AppState, CanvasViewModel, ContentView, MetalView,
  ModeSelectorView, ThemeManager, ToolbarView, TimelineView, etc.
- **Core/CAD/**: ConstraintEngine.swift, SnapEngine.swift
- **Core/Shaders/**: 4 archivos .metal (IBLComputeShaders, IBLShaders, PBRShaders, Shaders)
- **Features/CADMode/** (18 archivos + Tools/ + Views/)
- **Package.swift**: swift-tools-version:6.0, iOS 17+, target sources=[Core/, Features/, Sources/]

BACKUP DUPLICADO: 67 archivos en `backup_sources/` y 16 en `backup_sources_cadcore/`
(NO activos, excluidos en Package.swift)

## Hallazgo #2: CAD-10 COMPLETADO — Apple Pencil + PencilKit

Archivos creados/modificados (todos verificados con read_file + grep):

1. **PencilSketchView.swift** (NUEVO, 81 lines, 3086 bytes)
   - UIViewRepresentable wrapping PKCanvasView
   - PKToolPicker integrado con toggle visible/invisible
   - drawingPolicy: .anyInput (soporta finger + pencil)
   - Coordinator delegate importa strokes al engine

2. **CADSketchEngine.swift** (modificado, 489 lines, 20302 bytes)
   - `import PencilKit` agregado
   - `@Published var pencilMode: Bool = false`
   - `func importPencilKitStrokes(_ strokes: [PKStroke]) -> [SketchEntity]`
   - Shape detection: linea recta (<5% desviacion), circulo/arco, rectangulo
   - `setStrokeWidth(_ pressure: CGFloat)` para grosor por presion

3. **CADSketchView.swift** (modificado, 267 lines, 12130 bytes)
   - Boton `pencil.tip` SF Symbol en toolbar
   - Canvas condicional: PencilSketchView vs touch canvas original
   - Pressure indicator en bottom bar

4. **GestureHandler.swift** (modificado, 142 lines, 4752 bytes)
   - `var onPencilForce: ((CGFloat, CGPoint) -> Void)?` callback
   - `UIPencilInteraction` para iOS 17+
   - CoalescedTouches para extraer fuerza del Apple Pencil

## Hallazgo #3: Engines Existentes Listos para Conectar

OCCTEngine.swift ya existe en Core/Engines/ con:
- createBox, createCylinder, createSphere, createTorus, createCone
- union, subtract, intersect (boolean operations)
- fillet, chamfer, shell
- extrude(profile:direction:distance:)
- revolve(profile:angle:), sweep(profile:along:)
- Depende de OCCTSwift (SPM package)

ExtrusionEngine.swift DUPLICADO en:
- Core/Engines/ExtrusionEngine.swift (Mesh-based, 76 lines)
- Features/CADMode/Tools/ExtrusionEngine.swift (Mesh-based, 83 lines)

## Pendientes Priorizados

1. [ACTUAL] Fase 8: Conectar OCCTEngine + ExtrusionEngine al UI de CAD mode
2. Fase 8: Timeline parametrico DAG con undo/redo
3. Fase 8: Diseño UI estetica completa (AppTheme, tipografia, iconografia profesional)
4. Fase 9: Gestos intuitivos (pinch-to-extrude, tap-drag selection)
5. Fase 9: Benchmark metrics vs Shapr3D
6. Fase 10: Boolean GPU compute shaders + Assemblies

## Roadmap Técnico vs Shapr3D

| Feature | Shapr3D | AppForge (actual) | Ventaja |
|---------|---------|-------------------|---------|
| Apple Pencil | Touch basico | PencilKit nativo + force | AppForge |
| Sketch 2D | Propietario | SketchPoints+Lines+Arcs | Empate |
| Constraints | Si | GeometryConstraintManager | Empate |
| Extrusion | Si | OCCTEngine+ExtrusionEngine | Empate |
| Boolean | Si | OCCTEngine union/subtract | Empate |
| Metal Render | No | Satin PBR Metal | AppForge |
| Sculpt | No | SculptEngine+8 deformers | AppForge |
| Animation | No | AnimationEngine | AppForge |
| STL/STEP/OBJ | Solo STEP | 5 formatos | AppForge |
| Precio | $299/ano | TBD | AppForge |
