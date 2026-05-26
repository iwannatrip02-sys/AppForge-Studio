# CAD Phase 2 — Plan Estrategico: CAD Superior a Cualquier Software en iPad
> 2026-05-07

## Diagnostico Actual

### Completado (CAD-1 a CAD-6)
- GeometryEntity.swift, GeometryConstraint.swift — tipos base
- SolveSpaceSolver.swift — solver Gauss-Seidel (coincident, distance)
- CADHistoryTree.swift — undo/redo tree con CADOperation
- GeometryConstraintManager.swift — singleton con solver + Notifications
- CADSketchEngine.swift — motor de bocetos parametricos (connectToScene arreglado)
- ExtrudeEngine.swift — extrusion de perfiles 2D -> 3D
- CADSketchView.swift — UI SwiftUI con toolbar constraints
- CADModeView.swift — sketch y model tabs
- CADTool.swift — 24 tools con SF Symbols
- SolverSwift.swift — copiado a Sources/CADCore/
- 5 engines: Bevel, Boolean, Extrusion, LoopCut, Measure
- 13 tests SolverSwift

### Pendientes Inmediatos (Phase 2 Bugs)
1. Eliminar CADToolEnum.swift (duplicado legacy en Features/CADMode/Tools/)
2. Corregir mapping tangent->coincident en GeometryConstraintManager
3. Conectar resolveConstraints en CADSketchEngine (pipeline sketch->constraint->solver->Mesh3D)
4. Package.swift: incluir Sources/CADCore/ como target

## Plan Superior — 3 Fases

### Fase A — Constraint Solver Avanzado (semana 1)
- Newton-Raphson con Sparse Matrix (Accelerate vDSP) en vez de Gauss-Seidel
- Soportar: Horizontal, Vertical, Parallel, Perpendicular, Coincident, Distance, Angle, Radius, Diameter, Equal, Tangent, Fix, Symmetric, Concentric, Midpoint
- Jacobiano para sketches subconstrenidos (DOF tracking estilo PlanGCS)
- DAG de dependencias entre constraints

### Fase B — OCCT Kernel Integration (semana 2-3)
- OCCTSwift wrapper via XCFramework
- Operaciones booleanas: Fuse, Cut, Common
- Fillets y Chamfers
- Shell (vaciado de solidos)
- Sweep/Loft con secciones y spine
- Revolucion de perfil 2D
- Esto COMPITE DIRECTAMENTE con Shapr3D ($299/ano)

### Fase C — Diferenciadores Unicos (semana 3-4)
- **Sculpt-to-CAD**: convertir mesh esculpido a NURBS via remesh cuadriculado
- **Constraint solver en tiempo real**: feedback visual mientras arrastras (como SolveSpace)
- **STEP import/export nativo**: interoperabilidad con SolidWorks, Fusion 360
- **Multi-selection con gestures**: seleccion por lasso, por arista, por cara (como Shapr3D)
- **Snap inferencing**: deteccion automatica de midpoint, endpoint, center, tangent candidate

## Ventaja Competitiva
| Feature | Shapr3D | Nomad Sculpt | Feather 3D | AppForge |
|---------|---------|-------------|-----------|----------|
| Constraint solver | Si | No | No | Si (Fase A) |
| OCCT booleanas | Si | No | No | Si (Fase B) |
| Escultura | No | Si | No | Si (existente) |
| Sculpt-to-CAD | No | No | No | Si (Fase C) |
| STEP export | $299/ano | No | No | Si |
| Precio | $299/ano | $14.99 | $9.99/mes | TBD |
