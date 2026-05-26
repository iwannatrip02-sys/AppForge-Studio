# CAD Phase 2 — Integration Plan

## Status pre-Phase 2 (2026-05-07)

### Completo
- CADModeView.swift con sketch y model tabs
- GeometryConstraintManager con SolverSwift conectado
- CADSketchEngine con constraintManager
- CADTool.swift con 24 tools + SF Symbols
- SolverSwift.swift copiado a Sources/CADCore/
- 5 engines: Bevel, Boolean, Extrusion, LoopCut, Measure
- 13 tests SolverSwift en Tests/

### Lo que hay que hacer

**BUG 1-2: Fusionar CADTool duplicados**
- CADTool.swift (Features/CADMode/) tiene 24 tools completas
- CADToolEnum.swift (Features/CADMode/Tools/) es duplicado legacy
- Accion: eliminar CADToolEnum.swift, CADTool.swift ya es canonical

**BUG 3: Corregir mappings en GeometryConstraintManager**
- `case .tangent:` mapea a `SolverConstraintType.coincident`
- `case .collinear:` mapea correctamente
- Ya implementado segun el codigo leido

**BUG 4: Conectar resolveConstraints en CADSketchEngine**
- CADSketchEngine tiene constrainManager y points
- GeometryConstraintManager recibe entityPositionProvider/Updater closures
- Falta: conectar UI de constraints con resolveConstraints

**Package.swift: incluir Sources/CADCore**
- Sources/CADCore/ ahora tiene SolverSwift.swift
- Verificar que target incluya CADCore/

## Prioridad inmediata
1. Verificar CADToolEnum.swift (leerlo)
2. Leer Package.swift
3. Conectar pipeline sketch→constraint→solver→Mesh3D