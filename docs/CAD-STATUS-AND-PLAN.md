# CAD Status & Plan para Superar Shapr3D
> Generado: 2026-04-29 12:10 UTC | Basado en analisis de 26 archivos fuente

## Estado Real de Cada Componente

### OCCTEngine (`Core/Managers/OCCTEngine.swift`) — COMPLETO, FUNCIONAL
- API completa: primitivas (box, cylinder, sphere, torus, cone), booleanos (union/subtract/intersect con operadores +, -, &), fillet, chamfer, shell, extrude, revolve, export STEP/STL
- Singleton `OCCTEngine.shared` — listo para usar

### BooleanEngine (`Features/CADMode/Tools/BooleanEngine.swift`) — YA NO ES STUB
- Implementacion real que usa OCCTEngine.shared para las 3 operaciones
- `meshToShape()`: convierte Mesh a Shape OCCT usando triangulacion via BRepBuilderAPI

### AnimationEngine (`Core/Managers/AnimationEngine.swift`) — BUG CONFIRMADO EN SATINRENDERER
- Metodo `updateScene()` en AnimationEngine SI recibe `inout Scene3D` correctamente (linea 113, llamado con & en 241)
- **Bug real**: `SatinRenderer.updateScene()` en linea 25 recibe por valor. `SatinRendererView.swift` en lineas 17, 26, 41 lo llaman sin `&`

### CADSketchEngine + CADSketchView — YA FUNCIONALES
- Soporta: puntos, lineas, circulos, rectangulos, arcos, 8 tipos de constraints, grid snapping
- Extrusion desde sketch genera Mesh. Conectado a CADModeView via $meshResult binding
- **Lo que falta**: revolve desde sketch, loft, snapping a geometria 3D

### CADModeView — YA INTEGRA SKETCH
- Detecta herramienta de sketch y muestra CADSketchView. Cuando extrudedMesh cambia, lo agrega a canvasVM.scene

### MeasureEngine — DATOS DUMMY, requiere OCCTEngine
- distance siempre 1, area/volume random. Sin conectar a OCCT

### BevelEngine — BUG EN ALGORITMO
- No desplaza vertices hacia el centro de la arista, solo interpola linealmente
- No genera triangulos nuevos para el bevel, solo preserva indices originales

## Brechas vs Shapr3D

| Funcionalidad | Shapr3D | AppForge | Estado Real |
|---|---|---|---|
| Sketch 2D con snapping | Completo | Existe | IMPLEMENTADO con grid snapping, lineas, circulos, rectangulos, arcos |
| Constraints | Completo | Existe | 8 tipos implementados |
| Extrude desde sketch | Completo | Existe | FUNCIONAL en CADSketchView |
| Revolve desde sketch | Completo | NO existe | OCCTEngine.revolve() existe pero sin UI |
| Loft entre sketches | Completo | NO existe | No implementado |
| Boolean CSG | Completo | Funciona | Via OCCTEngine, 3 operaciones |
| Fillet/Chamfer | Completo | Parcial | BevelEngine con bug; OCCTEngine.fillet no conectado |
| Shell (vaciado) | Completo | NO existe en UI | OCCTEngine.shell() existe sin boton |
| Mediciones reales | Completo | Parcial | MeasureEngine con datos dummy |
| Primitivas parametricas | Completo | NO existe en UI | OCCTEngine.createBox/etc sin sliders |
| Modelado parametrico | Completo | NO existe | Sin historial ni arbol de construccion |
| Export STEP/IGES | Completo | Parcial | STEP existe via OCCT pero no conectado a UI |
| Pintura 3D sobre CAD | No tiene | Ventaja | PaintRenderer funcional |
| Animacion CAD | No tiene | Ventaja | AnimationEngine completo |
| Precio | $299/ano | Gratis + IAP | Ventaja competitiva clave |

## Plan de Implementacion

### Fase 4A — Corregir Bugs Criticos (1 sesion) — EN EJECUCION
1. SatinRenderer.updateScene: cambiar firma a `inout Scene3D`
2. SatinRendererView.swift: 3 llamadas con `&`
3. ToolViewModel: caso .boolean unir mallas diferentes (no copia de si misma)
4. BevelEngine: algoritmo con desplazamiento hacia centro de arista + triangulacion

### Fase 4B — Sketch 2D Avanzado + CAD Basico (2 sesiones) — SIGUIENTE
1. Revolve desde sketch: boton en bottomBar, UI para seleccionar eje y angulo
2. Primitivas parametricas: toolbar con Box/Cylinder/Sphere/Cone + sliders
3. Mediciones reales: MeasureEngine + OCCTEngine
4. Export STEP: conectar a ExportView

### Fase 4C — CAD Avanzado (2 sesiones)
1. Fillet/Chamfer UI via OCCTEngine
2. Shell (vaciado) via OCCTEngine
3. Loft entre sketches via OCCTEngine
4. Modelado parametrico: arbol de construccion

### Fase 4D — Diferenciacion Final (2 sesiones)
1. Pintura 3D sobre CAD
2. Timeline animacion en HybridMode
3. Onboarding CAD + pintura + exportacion
