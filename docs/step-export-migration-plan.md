# Migracion STEP Export a OCCTEngine Nativo
> 2026-05-01

## Estado Actual
- **ExportService.swift** (6419 bytes): exportToSTEP genera STEP manual con strings ISO-10303-21 (AP214). Usa vertices del mesh directamente, sin operaciones booleanas ni curva/superficie NURBS.
- **OCCTEngine.swift** (224 lineas): Usa OCCTSwift `Shape` con operaciones booleanas (union, subtract, intersect), fillet, chamfer, shell, extrude, revolve, sweep, loft, y `meshToShape()` que convierte Mesh a Shape via triangulated(). **NO tiene metodo de exportacion STEP.**

## Plan de Migracion
1. Agregar `exportSTEP(shape:to:)` a OCCTEngine que llame a `shape.exportSTEP()` nativo de OCCTSwift.
2. Modificar `ExportService.exportToSTEP` para convertir Model a Shape via `occtEngine.meshToShape()` y delegar en `occtEngine.exportSTEP()`.
3. Mantener fallback para modelos sin Shape (usar generacion manual como respaldo).

## Archivos a Modificar
- `Core/Managers/OCCTEngine.swift` — agregar metodo exportSTEP
- `Core/Services/ExportService.swift` — delegar STEP a OCCTEngine