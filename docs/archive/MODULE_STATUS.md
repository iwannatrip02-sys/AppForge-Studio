# AppForge Studio — Module Status
> Auto-generated baseline: 2026-05-26. Updated after every phase.
> Run `project_doc_sync` to auto-refresh against disk.

## Rendering (SatinRenderer)

| Module | Files | Status | Notes |
|--------|-------|--------|-------|
| SatinRenderer | Sources/Engines/SatinRenderer.swift (843 lines) | WORKS | PBR+IBL, Metal pipeline, scene update loop |
| PBR Material | Sources/Engines/PBRMaterial.swift, PBRMaterialUniforms.swift | WORKS | Textures, uniforms, IBL setup |
| IBL Pipeline | Sources/Engines/IBLPipeline.swift | WORKS | Diffuse irradiance + specular prefilter + BRDF LUT |
| Shaders | Sources/Shaders/ (5 .metal) | WORKS | PBR, IBL, Boolean compute |
| Metal View | Core/UI/MetalView.swift | **BROKEN** | No touch handling, no camera gestures |

## Sculpt Engine

| Module | Files | Status | Notes |
|--------|-------|--------|-------|
| SculptEngine | Sources/Engines/SculptEngine.swift | WORKS | 10 deformers, symmetry, undo/redo |
| Deformers | Sources/Engines/CreaseDeformer, FlattenDeformer, GrabDeformer, InflateDeformer, MoveDeformer, PinchDeformer, SmoothDeformer, TwistDeformer, BendDeformer, ShearDeformer | WORKS | All 10 implemented |
| Brush Engine | Sources/Engines/BrushEngine.swift | WORKS | Color, radius, opacity |
| Touch pipeline | MetalView → SculptEngine.apply() | **MISSING** | No input reaches the engine |

## CAD Kernel (pre-OCCT, legacy)

| Module | Files | Status | Notes |
|--------|-------|--------|-------|
| Shape (triangles) | Sources/CSG/Shape.swift | **DEPRECATED** | Replaced by OCCTSwift in Phase 1 |
| CSG BSP | Sources/CSG/BSPNode, CSGOperation, Polygon3D | **DEPRECATED** | OCCT provides B-rep booleans |
| OCCTEngine wrapper | Sources/Engines/OCCTEngine.swift | **STUB** | Wraps Shape, not real OCCT |
| BooleanEngine | Sources/Engines/BooleanEngine.swift | **STUB** | Delegates to OCCTEngine → Shape stubs |

## CAD Kernel (OCCTSwift) — PENDING Phase 1

| Module | Files | Status | Notes |
|--------|-------|--------|-------|
| OCCTSwift integration | Package.swift | **ADDED** | SPM dependency active |
| OCCT Bridge | Sources/Services/OCCTBridge.swift | **NOT CREATED** | Phase 1: Shape→Mesh conversion |
| Boolean ops | via OCCTSwift operators | **PENDING** | +, -, & on B-rep shapes |
| Fillet/Chamfer | via OCCTSwift TKOffset | **PENDING** | Real analytic edge operations |
| Extrude/Revolve/Sweep | via OCCTSwift TKTopAlgo | **PENDING** | Full parametric operations |
| STEP import/export | via OCCTSwiftIO | **PENDING** | B-rep fidelity AP203/AP214/AP242 |

## CAD UI (Sketch + Modeling)

| Module | Files | Status | Notes |
|--------|-------|--------|-------|
| CADModeView | Features/CADMode/CADModeView.swift (923 lines) | WORKS | **NEEDS REFACTOR** (Phase 2) |
| CADSketchView | Features/CADMode/CADSketchView.swift | WORKS | Grid, entities, constraints |
| CADSketchEngine | Features/CADMode/CADSketchEngine.swift | WORKS | RDP, corner detection, shape recognition |
| PencilKit | Features/CADMode/PencilSketchView.swift | WORKS | PKCanvasView, PKToolPicker |
| ExtrusionEngine | Features/CADMode/Tools/ExtrusionEngine.swift | WORKS | Profile→3D extrusion |
| MeasureEngine | Features/CADMode/Tools/MeasureEngine.swift | WORKS | Distance, radius, angle |
| ConstraintEngine | Sources/CAD/ConstraintEngine.swift | WORKS | Inference: parallel, perpendicular, tangent |
| SnapEngine | Sources/CAD/SnapEngine.swift | WORKS | Vertex, midpoint, center, grid |
| Solver | Sources/Engines/SolverSwift.swift (307 lines) | WORKS | Newton-Raphson, 11 constraint types |
| Gizmos 3D | N/A | **MISSING** | Phase 3: translate/rotate/scale arrows |
| ViewCube | N/A | **MISSING** | Phase 3: navigation cube |

## Animation + Morph

| Module | Files | Status | Notes |
|--------|-------|--------|-------|
| AnimationEngine | Sources/Engines/AnimationEngine.swift (541 lines) | WORKS | Keyframes, lerp/slerp, easing, playback |
| MorphEngine | Sources/Engines/MorphEngine.swift | WORKS | Morph targets, blends |
| AnimationPlayback | Sources/Engines/AnimationPlaybackController.swift | WORKS | Timeline control |

## Export

| Module | Files | Status | Notes |
|--------|-------|--------|-------|
| ExportService | Core/Services/ExportService/ExportService.swift | WORKS | OBJ, STL, USDZ, GLTF, FBX |
| ExportViewModel | Sources/Services/ExportViewModel.swift | WORKS | Format selection, progress |
| ExportView | Features/ExportMode/ExportView.swift | **BROKEN** | Fake progress bar, no real export trigger |
| STEP Export | via ExportServiceSTEP | **DEPRECATED** | Replace with OCCTSwiftIO in Phase 1 |

## Services

| Module | Files | Status | Notes |
|--------|-------|--------|-------|
| ModelCacheService | Sources/Services/ModelCacheService.swift | WORKS | NSCache 50obj/128MB |
| ModelLoadService | Sources/Services/ModelLoadService.swift | WORKS | OBJ, STL, USDZ loader |
| GPUComputeService | Sources/Services/GPUComputeService.swift | WORKS | IBL compute, boolean compute |
| CrashReporter | Sources/Services/CrashReporter.swift | WORKS | OSLog-based |
| ThemeManager | Sources/Theme/ThemeManager.swift | WORKS | Dark/light, accent color |

## UI Components

| Module | Files | Status | Notes |
|--------|-------|--------|-------|
| AppState | Core/UI/AppState.swift | WORKS | **Needs refactor — no DI, no router** |
| CanvasViewModel | Core/UI/CanvasViewModel.swift | WORKS | **Duplicate AppMode, silent binding bug** |
| ToolbarView | Core/UI/ToolbarView.swift | **PARTIAL** | Missing import/export/undo/redo buttons |
| HybridModeView | Features/HybridMode/HybridModeView.swift | **STUB** | Empty button closures |
| LayerPanelView | Core/UI/LayerPanelView.swift | **PARTIAL** | No grouping, no opacity, no thumbnails |
| TransformationGizmo | Core/UI/TransformationGizmoView.swift | **2D ONLY** | Not a real 3D gizmo |
| OnboardingView | Core/UI/OnboardingView.swift | WORKS | 5 pages, needs UX polish |
| TimelineView | Core/UI/TimelineView.swift | **PARTIAL** | Keyframes show, no graph editor |

## Tests

| Module | Tests | Status |
|--------|-------|--------|
| AnimationEngine | 8 | PASS (logically) |
| AnimationPlayback | 8 | PASS |
| CSG Operations | 7 | PASS (triangle-level, pre-OCCT) |
| SolverSwift | 5 | PASS |
| ModelCacheService | 5 | PASS |
| ExportService | 6 | PASS |
| GeometryConstraint | 10 | PASS |
| **Total** | **49 tests** | |

## Known Bugs

| ID | File | Severity | Fixed? |
|----|------|----------|--------|
| BUG1 | SatinRenderer.swift — float3 padding | CRITICAL | No |
| BUG2 | SatinRenderer.swift — doble updateAnimation | CRITICAL | No |
| BUG3 | SatinRenderer.swift — UInt16→UInt32 | HIGH | No |
| BUG5 | Shaders.metal — normal matrix | HIGH | No |
| BUG7 | SculptEngine.swift — grab direction | MEDIUM | No |
| BUG9 | SatinRenderer.swift — rebuildScene | HIGH | No |
| BUG-DUP1 | CanvasViewModel — duplicate AppMode | MEDIUM | No |
| BUG-BIND1 | CanvasViewModel — silent binding fail | MEDIUM | No |
