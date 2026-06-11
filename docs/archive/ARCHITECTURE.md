# AppForge Studio — Architecture
> v3 | Updated: 2026-05-26 | iOS 17+, OCCTSwift, SatinRenderer

## Layer Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ UI Layer (SwiftUI + UIKit gestures)                          │
│ ┌─────────┐ ┌─────────┐ ┌──────────┐ ┌──────────┐          │
│ │CAD Mode │ │Sculpt   │ │Export    │ │Animation │          │
│ │Views    │ │Mode View│ │Mode View │ │Mode View │          │
│ └────┬────┘ └────┬────┘ └────┬─────┘ └────┬─────┘          │
│      │           │           │             │                 │
│ ┌────┴───────────┴───────────┴─────────────┴──────┐        │
│ │ AppState + CanvasViewModel + ToolViewModel       │        │
│ │ (ObservableObject, @MainActor)                   │        │
│ └──────────────────────┬───────────────────────────┘        │
├────────────────────────┼────────────────────────────────────┤
│ Bridge Layer           │                                    │
│ ┌──────────────────────┴──────────────────────────┐        │
│ │ OCCTBridge: OCCTSwift.Shape → Mesh → MTLBuffer  │        │
│ │ GestureHandler: touch → rayhit → tool dispatch  │        │
│ └─────────────────────────────────────────────────┘        │
├────────────────────────────────────────────────────────────┤
│ Kernel Layer                                                │
│ ┌────────────┐ ┌────────────┐ ┌──────────┐ ┌───────────┐ │
│ │OCCTSwift   │ │SculptEngine│ │SDFEngine │ │MorphEngine│ │
│ │(B-rep CAD) │ │(10 def.)   │ │(vol.ops) │ │(targets)  │ │
│ └──────┬─────┘ └─────┬──────┘ └────┬─────┘ └─────┬─────┘ │
│        │              │             │              │        │
│ ┌──────┴──────────────┴─────────────┴──────────────┴─────┐ │
│ │ AnimationEngine (keyframes, lerp/slerp, playback)      │ │
│ └────────────────────────────────────────────────────────┘ │
├────────────────────────────────────────────────────────────┤
│ Render Layer                                                │
│ ┌────────────────────────────────────────────────────┐     │
│ │ SatinRenderer (PBR + IBL + Metal compute)         │     │
│ │ ┌──────────┐ ┌───────────┐ ┌───────────────────┐ │     │
│ │ │PBR Shader│ │IBL Pipeline│ │Boolean Compute    │ │     │
│ │ │(5 .metal)│ │(irradiance)│ │(GPU CSG, future)  │ │     │
│ │ └──────────┘ └───────────┘ └───────────────────┘ │     │
│ └────────────────────────────────────────────────────┘     │
│ Satin (Hi-Rez, 13.0.0) — Metal/Swift 3D framework          │
└────────────────────────────────────────────────────────────┘
```

## Data Flow

```
Touch (UIKit gestures)
    │
    ▼
GestureHandler
    ├─ orbit/pan/zoom → Camera → SatinRenderer.updateCamera()
    ├─ sketch draw → CADSketchEngine → CADSketchView
    ├─ sculpt → hitTest() → SculptEngine.apply() → MTLBuffer
    ├─ gizmo drag → Transform → SatinRenderer.updateTransform()
    └─ object select → hitTest() → CanvasViewModel.selectedIndex

CAD Operations:
    OCCTSwift.Shape → Boolean/Fillet/Extrude
        │
        ▼
    OCCTBridge.shapeToMesh() → Mesh (triangulated)
        │
        ▼
    SatinRenderer.createBuffersFromMeshes() → MTLBuffer
        │
        ▼
    draw(in:) → Metal pipeline → framebuffer

Export:
    OCCTSwiftIO.Exporter.writeSTEP(shape, to: url) → .step
    OCCTSwiftIO.Exporter.writeSTL(shape, to: url)  → .stl
    ExportService.buildOBJ/sceneToUSDZ/writeGLTF     → .obj/.usdz/.gltf
```

## State Architecture

```
AppState (@MainActor, @StateObject, app root)
├── @Published selectedMode: AppMode
├── @Published isLoading: Bool
├── @Published showExport: Bool
├── canvasVM: CanvasViewModel (@Published scene: Scene3D)
├── toolVM: ToolViewModel
├── exportVM: ExportViewModel
├── animationVM: AnimationEngine
├── subdivisionVM: SubdivisionEngine
├── themeManager: ThemeManager
├── modelCache: ModelCacheService
├── modelLoader: ModelLoadService
└── satinRenderer: SatinRenderer

Scene3D (struct, @Published in CanvasViewModel)
├── models: [Model] (meshes, transforms, materials)
├── camera: Camera (position, target, fov)
├── lights: [Light] (directional, point, ambient)
└── grid: Grid (size, subdivisions)
```

## Dependency Graph

```
AppForgeStudio
├── Satin (Metal/Swift 3D framework, Hi-Rez 13.0.0)
└── OCCTSwift (B-rep CAD kernel, gsdali 1.0.0+)
    └── OCCT.xcframework (pre-compiled, iOS arm64, ~190 MB)
```

## Key Design Decisions

1. **SatinRenderer over OCCTSwiftViewport**: OCCTSwiftViewport requires iOS 18+. We maintain SatinRenderer for iOS 17+ compatibility and implement viewport features (gizmos, viewcube, picking) directly in Metal.

2. **OCCTSwift for CAD only**: The kernel handles geometry (B-rep operations). Rendering stays in Satin/Metal. Bridge layer converts B-rep → mesh for display.

3. **MVVM + ObservableObject**: SwiftUI reactive state at UI layer. Metal rendering is imperative (direct MTLBuffer manipulation). Bridge syncs via `@Published scene: Scene3D`.

4. **Free pipeline**: GitHub Actions CI (public repo) → unsigned .ipa → Sideloadly (Windows) → iPad. No Mac required, no Apple Developer account required.
