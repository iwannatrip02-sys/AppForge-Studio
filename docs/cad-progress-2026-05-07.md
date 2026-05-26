# CAD Module Progress Report — 2026-05-07

## Estado actual del modulo CAD de AppForge Studio

### Phase 1 (completado previamente)
- CAD-1 a CAD-6: Core kernel parametrico, solver Gauss-Seidel, undo/redo, extrusión, sketch view

### Phase 2 bugs (APLICADOS por Atlas Coder)
- **BUG 3**: Tangent mapping corregido en GeometryConstraintManager (tangent ya no apunta a coincident)
- **BUG 4**: resolveConstraints(scene:) implementado en CADSketchEngine (itera constraints activas, llama solver, registra en historyTree)
- **BUG 1-2**: CADToolEnum.swift eliminado (contenido redundante vs CADTool.swift)
- **Package.swift**: Actualizado para incluir Sources/CADCore/ engines
- **SolverSwift**: .tangent anadido al enum SolverConstraintType + logica de evaluacion

### CAD-9: Engine Avanzados (YA COMPLETADO)
**Tools/ToolViewModel.swift** tiene executeTool() que usa **OCCTEngine** para:
- `.fillet` → occt.meshToShape → occt.fillet(radius:) → occt.shapeToMesh
- `.chamfer` → occt.meshToShape → occt.chamfer(radius:) → occt.shapeToMesh
- `.shell` → occt.meshToShape → occt.shell(thickness:) → occt.shapeToMesh
- `.loft` → occt.loft(profiles:) con 2 perfiles
- `.sweep` → occt.sweep(profile:along:) con path de 4 puntos

CADModeView.swift conecta con:
- parameterBar con sliders para filletRadius, chamferRadius, shellThickness
- Boton "Aplicar" llama executeSelectedTool() que llama toolVM.executeTool(mesh:)
- scene.models[0].meshes[0] actualizado post-ejecucion

### CAD-8: Constraint Visualization (PENDIENTE)
- Scene3D ya tiene constraintManager, vertexProvider, vertexUpdater
- parametricView muestra timeline de CADHistory pero NO overlays de constraints
- Falta implementar ConstraintOverlayView que:
  a) Lea constraints de canvasVM.scene.constraintManager
  b) Dibuje indicadores visuales (lineas coloreadas, iconos, cotas)
  c) Colores por tipo: distance=azul, angle=verde, tangent=rojo

### Proximos pasos
1. IMPLEMENTAR CAD-8: ConstraintOverlayView en parametric tab
2. CAD-10: edge selection en 3D para fillet/chamfer (ocupa cara o arista especifica)
3. CAD-11: timeline undo/redo completo con todas las operaciones parametrizadas
