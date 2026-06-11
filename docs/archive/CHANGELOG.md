# AppForge Studio — Changelog

## v2.0 (target) — Shapr3D Open-Source Competitor
### Kernel
- **Added**: OCCTSwift 1.0.0 (Open CASCADE 8.0.0) — professional B-rep CAD kernel
- **Added**: Real Boolean ops (union, subtract, intersect) with B-rep fidelity
- **Added**: Real fillet, chamfer, shell, draft via OCCT TKOffset
- **Added**: Real extrude, revolve, sweep, loft via OCCT TKTopAlgo
- **Added**: STEP import/export AP203/AP214/AP242 via OCCTSwiftIO
- **Added**: IGES import/export
- **Removed**: Legacy Shape.swift (triangle-based CSG)
- **Removed**: Legacy BSPNode, CSGOperation, Polygon3D (BSP tree)

### Viewport
- **Added**: 3D gizmos (translate arrows, rotate arcs, scale handles)
- **Added**: GPU picking (Metal imageblock, bodyID + faceID)
- **Added**: ViewCube navigation
- **Added**: Adaptive grid with logarithmic subdivision
- **Added**: Edge rendering pass
- **Added**: Ground shadow projection
- **Added**: Camera presets with SLERP animation
- **Added**: Clip planes (section views)

### UI
- **Refactored**: CADModeView split from 923-line god view to MVVM
- **Added**: Touch handling in MetalView (orbit/pan/zoom/raycast)
- **Added**: Professional sketch with live constraint inference
- **Added**: Freehand PencilKit → constrained geometry conversion
- **Added**: Dimension input (editable measurements)
- **Added**: Import button (fileImporter for .step/.iges/.stl/.obj)
- **Added**: Drag-and-drop import from Files app
- **Fixed**: CanvasViewModel duplicate AppMode
- **Fixed**: Silent binding failure on selectedTransform
- **Unified**: Undo/redo system (CADHistoryTree + CanvasVM)

### Sculpt
- **Added**: CAD→sculpt bridge (select face → deform → re-integrate)
- **Added**: Local subdivision (Catmull-Clark at brush area)
- **Added**: Real-time symmetry mirror
- **Added**: Brush cursor preview with radius
- **Added**: Pressure sensitivity in sculpt mode

### Export
- **Fixed**: Real export progress (not fake animation)
- **Added**: STEP/IGES export with B-rep fidelity
- **Added**: Export presets (3D print, CAD precision, game asset)

### Documentation
- **Added**: MODULE_STATUS.md (auto-updated checklist)
- **Added**: ARCHITECTURE.md (layer diagram, data flow)
- **Added**: BUILD_GUIDE.md (CI, sideloading, dependencies)
- **Added**: CHANGELOG.md (this file)
- **Added**: project_doc_sync tool (Gotchi) for auto-refresh

---

## v1.1 (2026-05-26) — Compilation Fix

### Fixed
- Dual Mesh/Vertex definitions (Shape.swift → Mesh.swift unified)
- 13 missing methods in Shape (triangulate, volume, area, boundingBox, exportSTEP, etc.)
- deltaTime use-before-definition (SatinRenderer)
- MDLMesh invalid API (ExportService → vertex/index buffers)
- simd_float4x4(rotation) missing extension (AnimationEngine)
- Duplicate measureBoundingBox (OCCTEngine)
- Satin 0.4.0 → 13.0.0 (Package.swift + project.yml)

### Added
- AppIcon + AccentColor in Assets.xcassets
- UILaunchScreen (iOS 17+, no storyboard needed)
- Test target in project.yml
- CI: xcodebuild test + archive + IPA export
- Operators Shape. - and .& fixed (use CSGOperation)

---

## v1.0 (2026-05-25) — Structural Cleanup

### Removed
- Nested .git in ios-app/AppForgeStudio/
- GitHub token in remote URL
- 100+ orphan files (backup_sources/, backup_sources_cadcore/, Build/backup/, _archive/)
- Sources/CADCore/ (duplicated)
- CI workflow duplication (3→1)

### Fixed
- Structure: 68 files consolidated from Core/ to Sources/
- Package.swift: exclusions cleaned, Satin unified
- project.yml: paths match real structure, Satin source unified
- TODO.md: honest (no fake "done" markers)
- BRAIN.md: verified file inventory

### Added
- project_health_check tool (Gotchi)
- Write-guard (detects writes outside workspace)
- R-PROJECT system prompt rule
- Bridge project_open ↔ registry
- Session bootstrap with workspace TODO.md

---

## v0.9-pre (before cleanup) — Pre-unification

- Built on Satin + custom triangle mesh CSG
- 130+ Swift files, 5 Metal shaders, 49 tests
- Features: CAD sketch, sculpt, PBR, animation, export
- Known: uncompileable due to 7 bugs, dual git repos, 100+ orphan files
