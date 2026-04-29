# AppForge Studio — Sintesis de Arquitectura y Avance
> Generado: 2026-04-27 | Sesion de implementacion

## Arquitectura Real (descubierta por inspeccion)

El proyecto tiene CODIGO REAL en `ios-app/AppForgeStudio/` con estructura modular:
- **Core/Managers/** — PaintRenderer, PincelRenderer, Shaders.metal (pipeline Metal funcional)
- **Core/Services/** — ExportService (exporta OBJ/STL via ModelIO), ModelLoadService
- **Core/ViewModels/** — ToolViewModel (5 modos, 9 herramientas CAD, presets brushes)
- **Features/CADMode/** — CADModeView con 9 herramientas UI, pero Tools/ VACIO (sin logica)
- **Features/SculptMode/** — SculptModeView + BrushEngine con undo/redo 50 estados, simetria 3 ejes, 9 brushes
- **Features/ExportMode/** — ExportView con UI bonita pero NO conectada a ExportService
- **Features/HybridMode/** — Modo hibrido CAD+Escultura

El GOTCHI.md anterior describia una arquitectura SPM obsoleta (`Sources/Views/`) que NO EXISTE en disco.

## Diagnostico por Modulo

| Modulo | % | Estado |
|--------|---|--------|
| CAD Mode | 5% | UI lista (9 tools), 0% logica. Shapr3D competencia directa |
| Sculpt Mode | 40% | 9 brushes funcionales, undo/redo, simetria. Falta DynTopo, subdivision |
| Export Service | 70% | Backend funcional (OBJ/STL). UI desconectada del backend |
| Paint Renderer | 70% | Pipeline Metal con shaders vertex/fragment funcional |
| ToolViewModel | 80% | 5 modos, presets, simetria, snap. Bien estructurado |

## Cambios Realizados en esta Sesion

### 1. Logica CAD creada (5 engines en CADMode/Tools/)
- **ExtrusionEngine.swift** — Duplica vertices de cara seleccionada, desplaza en direccion dada, genera caras laterales y frontal
- **LoopCutEngine.swift** — Inserta vertices en mitad de aristas de loop, subdivide triangulos en 4
- **BevelEngine.swift** — Estructura base para biselado con 'segments' parametrizable
- **BooleanEngine.swift** — Union basica implementada; Difference/Intersection con FIXME (requiere BSP tree)
- **MeasureEngine.swift** — Distancia, area (suma de triangulos) y volumen (teorema de divergencia)

### 2. ExportView conectado con ExportService
- Boton de exportar ahora llama a `exportService.exportToOBJ()` o `.exportToSTL()` segun formato
- fileImporter para seleccionar destino con UTType STL/OBJ
- Progreso via isExporting, alerta con resultado exitoso/fallido

### 3. SubdivisionEngine creado (Catmull-Clark)
- `Core/Managers/SubdivisionEngine.swift`
- Algoritmo completo: face points, edge points, vertex points, conexion en 6 triangulos por cara original
- Soporta multiples iteraciones
- Listo para integrar con SculptMode como DynTopo ligero

### 4. GOTCHI.md actualizado
- Ahora refleja la arquitectura REAL con Features/, Core/, Tools/
- Tabla de modulos con % completo y archivos clave
- Proximas acciones priorizadas

## Estado General del Proyecto
- **Antes:** ~25% (UI dispersa, logica CAD 0%, Export desconectado)
- **Ahora:** ~35% (CAD subio de 5% a 20%, Export de 70% a 85%)
- **Proximos pasos:** (1) Integrar engines CAD con CADModeView, (2) Subdivision en SculptMode, (3) Conectar SatinRenderer con pipeline principal

## Comparacion con Competencia
| Aspecto | Nosotros | Shapr3D | Nomad |
|---------|---------|---------|-------|
| CAD parametrico | 20% (engines listos, sin UI) | 100% | 0% |
| Escultura | 40% (basico) | 0% | 90% (DynTopo, multires) |
| Export 3D | 85% (STL/OBJ) | STL/OBJ/STEP | STL/OBJ |
| Precio | Gratis (dev) | $299/ano | $14.99 |
