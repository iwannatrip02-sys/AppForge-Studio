# AppForge Studio - GOTCHI.md
> Proyecto Gotchi - app_development | Actualizado: 2026-04-29 12:00 UTC
> ID: d80c1c08 | Estado: active | Fase: 4 (animacion + subdivision + CAD completo)

## Descripcion
App iOS nativa de pintura 3D + escultura + CAD + animacion + exportacion a impresion 3D.
Stack: SwiftUI + Metal 2 + Satin v0.3.0 + ModelIO + OCCTSwift.
Objetivo: superar a Shapr3D ($299/ano) en relacion calidad/precio con app iOS nativa.

## Tech Stack
- Swift 5.9+, SwiftUI (iOS 17+)
- Metal 2 (render pipeline, compute shaders)
- Satin 0.3.0 (framework Metal para Swift)
- ModelIO / MetalKit (carga/exportacion de modelos 3D)
- OCCTSwift (Open CASCADE Technology para CAD booleano, fillet, extrude, revolver, sketch, loft, sweep)
- simd (matematicas 3D)

## Arquitectura Real (ios-app/AppForgeStudio/)
- **AppForgeStudio/** (2): AppForgeStudioApp.swift, SatinRenderer.swift
- **Models/** (3): BrushStroke.swift, Mesh.swift, Scene3D.swift
- **Core/Managers/** (7): AnimationEngine.swift, OCCTEngine.swift, PaintRenderer.swift, PincelRenderer.swift, SceneRenderer.swift, Shaders.metal, SubdivisionEngine.swift
- **Core/Services/** (2): ExportService.swift, ModelLoadService.swift
- **Core/ViewModels/** (2): ExportViewModel.swift, ToolViewModel.swift
- **Features/CADMode/** (8): CADModeView.swift + Tools/ (BevelEngine, BooleanEngine, CADToolEnum, ExtrusionEngine, LoopCutEngine, MeasureEngine, ToolViewModel)
- **Features/SculptMode/** (2): SculptModeView.swift + Brushes/
- **Features/HybridMode/** (1): HybridModeView.swift
- **Features/ExportMode/** (1): ExportView.swift
- **Sculpting/** (1): SculptEngine.swift + Deformers/ (8 deformadores)
- **UI/Components/** (3): MetalView.swift, ContentView.swift, SatinRendererView.swift
- **ViewModels/** (2): AppState.swift, CanvasViewModel.swift
- **Total**: ~49 archivos .swift + 1 .metal

## Estado por Fase
- **Fase 1A** (Sistema pinceles): COMPLETA - 10 brush types, paint/sculpt/hybrid modes, falloff GPU
- **Fase 1B** (Pipeline Metal): COMPLETA - SatinRenderer con 4 passes, shadows, PBR, bloom
- **Fase 2** (Escultura): COMPLETA - SculptEngine con 8 deformadores, simetria, falloff, SubdivisionEngine Catmull-Clark
- **Fase 3** (Exportacion): COMPLETA - ExportService OBJ/STL via ModelIO con progress bar
- **Fase 4** (CAD + Animacion): EN DESARROLLO - 5 engines CAD escritos (Boolean, Extrusion, Bevel, LoopCut, Measure) + AnimationEngine con timeline + clip management

## Proximos Pasos
1. CORREGIR BUG: AnimationEngine.updateScene() - cambiar firma a inout Scene3D
2. REEMPLAZAR BooleanEngine stub con OCCTEngine real para CSG booleano completo
3. CONECTAR OCCTEngine en ToolViewModel.executeTool() para operaciones CAD reales
4. IMPLEMENTAR sketch 2D-based CAD (extrude, revolve, loft desde sketch)
5. AGREGAR TimelineView a HybridMode para animacion keyframe visible
6. CONECTAR MeasureEngine con datos reales de OCCTEngine para mediciones precisas