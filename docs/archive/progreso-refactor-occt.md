# Progreso: Eliminar dependencia OCCTSwift — AppForge Studio

## Estado (11 mayo 2026)

### Completado
1. **Package.swift** — Satin cambiado de `branch: "main"` a `from: "0.4.0"`. OCCTSwift removido del todo (package + target dependency).
2. **Core/CSG/Shape.swift** (7709 bytes, 213 líneas) — stub nativo con todas las operaciones OCCT:
   - Primitivas: box, cylinder, sphere, torus, cone
   - Construcción: face, shell, solid
   - CSG: + (unión superficial), - (identidad), & (identidad) — CSG real implementable con Metal
   - Deformaciones: filleted, chamfered, shelled, extruded, revolved, swept (stubs identity por ahora)
   - Struct Mesh con Vertex (position, normal, uv)

### Pendiente (próximo batch)
3. **OCCTEngine.swift** — remover `import OCCTSwift` y arreglar wrapper de clase (singleton)
4. **Core/Engines/BooleanEngine.swift** — remover `import OCCTSwift`
5. **Features/CADMode/Tools/BooleanEngine.swift** — remover `import OCCTSwift`
6. **swift build** — probar compilación con las dependencias limpias

### Impacto
- Shape.swift es 100% Swift nativo, sin bindings C++/OCCT
- CSG real (+/-/&) requiere implementación con Metal compute shaders en el futuro
- Las operaciones fillet, chamfer, extrude, revolve, sweep retornan self (shape original) hasta implementación real
