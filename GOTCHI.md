# AppForge Studio - GOTCHI.md
> Proyecto Gotchi - app_development | Actualizado: 2026-05-01 07:28 UTC
> ID: d80c1c08 | Estado: active | Fase: 7 cache + mejoras UI/UX

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
- **Core/Services/** (3): ExportService.swift, ModelLoadService.swift, ModelCacheService.swift
- **Core/ViewModels/** (2): ExportViewModel.swift, ToolViewModel.swift
- **Features/CADMode/** (8): CADModeView.swift + Tools/ (BevelEngine, BooleanEngine, CADToolEnum, ExtrusionEngine, LoopCutEngine, MeasureEngine, ToolViewModel)
- **Features/SculptMode/** (2): SculptModeView.swift + Brushes/
- **Features/HybridMode/** (1): HybridModeView.swift
- **Features/ExportMode/** (1): ExportView.swift
- **Sculpting/** (1): SculptEngine.swift + Deformers/ (8 deformadores)
- **UI/Components/** (3): MetalView.swift, ContentView.swift, SatinRendererView.swift
- **ViewModels/** (2): AppState.swift, CanvasViewModel.swift
- **Total**: ~50 archivos .swift + 1 .metal

## Estado por Fase
- **Fase 1A** (Sistema pinceles): COMPLETA - BrushStroke, PaintRenderer, Shaders.metal con 4 tipos de pincel
- **Fase 1B** (PincelRenderer): COMPLETA - PincelRenderer con GPU compute, pinceles circulares/cuadrados/textura
- **Fase 2** (Escultura): COMPLETA - SculptEngine + 8 Deformers (inflate, grab, smooth, flatten, pinch, twist, crease, drag)
- **Fase 3** (CAD): COMPLETA - OCCTEngine con extrude, revolve, boolean ops, bevel, chamfer, fillet, sketch, loft, sweep
- **Fase 4** (Animacion): COMPLETA - AnimationEngine con timeline, keyframes, interpolacion, evaluate(at:) + deltaTime
- **Fase 5** (Exportacion): COMPLETA - ExportService con OBJ/STL/USDZ/STEP/GLTF + ExportView + Confetti
- **Fase 6** (Tests): COMPLETA - 12 AnimationEngineTests, 6 ExportServiceTests, 5 ModelCacheServiceTests
- **Fase 7** (Cache): COMPLETA - ModelCacheService (NSCache 50/128MB + disco JSON) + integrado en ModelLoadService
- **Mejoras UI/UX**: En progreso - modo oscuro, pantalla de carga 3D, validacion tests

## Conventions
- SwiftUI views con @State/@Binding/@EnvironmentObject para estado
- Metal shaders en archivo Shaders.metal separado
- Servicios como singletons con static shared
- Tests con XCTest, nombrados [Modulo]Tests
- Commits con prefijo: feat:, fix:, docs:, refactor:, test:
