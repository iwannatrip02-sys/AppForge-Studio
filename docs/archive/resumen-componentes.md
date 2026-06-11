# Resumen de componentes — AppForge Studio
> 2026-05-12

## Estado real verificado

### Core/CSG/ — COMPLETO
- BSPNode.swift, CSGOperation.swift, Polygon3D.swift, Shape.swift con box/sphere/cylinder/cone/torus/plane
- Operaciones: union, difference, intersection via BSP binario

### Features/CADMode/ — COMPLETO (UI conectada)
- CADModeView.swift (331 lines): toolbar con 7 tools (select/line/circle/rectangle/arc/boolean/constraint + extrude/loft/bevel/fillet/chamfer/shell/sweep/measure)
- BooleanToolView integrado con CSGBooleanMode (union/difference/intersection)
- ExportButton con showStepExportAlert para STEP export via ExportServiceSTEP
- Tools/: CADBooleanTool.swift, CADExtrudeTool.swift, CADFilletTool.swift, CADBevelTool.swift
- Views/: BooleanToolView.swift

### AnimationEngine — COMPLETO + TESTS
- Core/Engines/AnimationEngine.swift (178 lines): keyframes genericos, 7 easing types (linear/easeIn/easeOut/easeInOut/quadratic/cubic/sine), clips, evaluateAnimation con deltaTime
- Tests/AnimationEngineTests.swift: 7 tests XCTest (initialState, play/stop, togglePlayPause, addKeyframe, addClip, evaluateAnimation)

### ExportServiceSTEP — IMPLEMENTADO, SIN TESTS
- Features/ExportMode/ExportServiceSTEP.swift: genera STEP ISO-10303-21
- Entidades: CARTESIAN_POINT, DIRECTION, VECTOR, LINE, EDGE_CURVE, ORIENTED_EDGE, EDGE_LOOP, FACE_OUTER_BOUND, ADVANCED_FACE, CLOSED_SHELL, MANIFOLD_SOLID_BREP
- Toma sketchLines como input, output a URL

### Tests de integracion render+animacion — NO EXISTEN
- grep de IntegrationTest|RenderTest|AnimationTest en workspace: 0 matches
- No hay tests que validen Scene3D + AnimationEngine + render pipeline

## Resumen de pendientes
1. [ ] Crear IntegrationTests.swift para render + animacion
2. [ ] Crear ExportServiceSTEPTests.swift para validacion STEP con geometria real