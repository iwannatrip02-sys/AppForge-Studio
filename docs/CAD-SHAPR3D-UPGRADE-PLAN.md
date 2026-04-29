# Plan Estrategico: CAD para superar Shapr3D
> Actualizado: 2026-04-29 12:00 UTC

## Estado actual vs Shapr3D

**Shapr3D** ($299/ano): sketch 2D con snapping, extrusion/revolucion/loft desde sketch, operaciones booleanas CSG, mediciones precisas, modelado parametrico no destructivo, export STEP/IGES/STL/OBJ.

**AppForge Studio** (gratis + IAP): 5 engines CAD escritos (BooleanEngine stub, ExtrusionEngine, BevelEngine, LoopCutEngine, MeasureEngine) + OCCTEngine real via OCCTSwift. ExportService con OBJ/STL. Sin sketch 2D aun.

## Brechas criticas respecto a Shapr3D

| Funcionalidad | Shapr3D | AppForge | Prioridad |
|---|---|---|---|
| Sketch 2D con snapping | Completo | No existe | CRITICA |
| Extrude desde sketch | Completo | ExtrusionEngine solo funciona con mallas, no sketches | CRITICA |
| Revolve desde sketch | Completo | No existe | CRITICA |
| Loft entre sketches | Completo | No existe | ALTA |
| Boolean CSG real | Completo | BooleanEngine stub (solo union concatena) | CRITICA |
| Mediciones reales | Completo | MeasureEngine existe pero datos irreales | ALTA |
| Modelado parametrico | Completo | No existe | ALTA |
| STEP/IGES export | Completo | No implementado | MEDIA |
| Primitivas parametricas | Completo | No existen | MEDIA |

## Roadmap para superar Shapr3D

### Fase 4A - Corregir bloqueos actuales (1-2 sesiones)
1. **AnimationEngine bug**: cambiar firma de updateScene() a (inout Scene3D, Float)
2. **BooleanEngine real**: reemplazar stub con wrapper de OCCTEngine.shared para CSG booleano completo
3. **Conectar OCCTEngine**: ToolViewModel.executeTool() debe llamar a OCCTEngine en lugar de BooleanEngine

### Fase 4B - Sketch 2D + CAD basico (3-4 sesiones)
1. **SketchView**: View de dibujo 2D con plano de referencia, snapping a grid/ejes, linea/arco/circulo/rectangulo
2. **Extrude desde sketch**: OCCTEngine.extrudeProfile(profile, height, direction)
3. **Revolve desde sketch**: OCCTEngine.revolveProfile(profile, axis, angle)
4. **Primitivas parametricas**: Toolbar con box/sphere/cylinder con sliders de dimensiones

### Fase 4C - CAD avanzado (3-4 sesiones)
1. **Loft entre sketches**: OCCTEngine.loftProfiles([profile1, profile2, ...])
2. **Sweep/Pipe**: extrusion a lo largo de curva 3D
3. **Shell/Thicken**: vaciado de solidos y espesor a superficies
4. **Mediciones reales**: conectar MeasureEngine con OCCTEngine para distancia/angulo/area/volumen

### Fase 4D - Animacion + modelo final (3-4 sesiones)
1. **TimelineView**: UI de animacion con keyframes arrastrables, slider de tiempo, play/pause/loop
2. **AnimationEngine fix + clip management**: corregir inout, conectar con TimelineView
3. **Export STEP/IGES**: agregar formatos via OCCTEngine
4. **Onboarding tutorial**: primera experiencia de usuario

## Estrategia de diferenciacion vs Shapr3D

1. **Precio**: AppForge Studio gratuito con IAP vs $299/ano de Shapr3D
2. **Todo-en-uno**: pintura 3D + escultura + CAD + animacion + exportacion (Shapr3D solo CAD)
3. **Animacion integrada**: Shapr3D no tiene animacion keyframe
4. **Subdivision integrada**: SubdivisionEngine Catmull-Clark en modo escultura
5. **Exportacion a impresion 3D**: STL/OBJ directo

## Metricas de exito
- [ ] BooleanEngine reemplazado con OCCTEngine real
- [ ] SketchView funcional con snapping
- [ ] Extrude desde sketch operativo
- [ ] Revolve desde sketch operativo
- [ ] Primitivas parametricas en toolbar
- [ ] Loft entre 2+ sketches
- [ ] Mediciones reales (distancia, angulo, area) conectadas a OCCTEngine
- [ ] TimelineView operativa con animacion keyframe
- [ ] Export STEP/IGES funcional