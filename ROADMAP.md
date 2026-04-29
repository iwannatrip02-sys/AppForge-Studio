# AppForge Studio — Roadmap de Desarrollo
> Actualizado: 2026-04-27 23:45 UTC | Post-auditoria de codigo real

## Estado Actual (verificado contra arbol de archivos iOS)

### Implementado ✅
- **App principal** con 4 modos: CAD, Sculpt, Hybrid, Render via Picker
- **Modelos 3D:** Scene3D, Camera, Lighting, Model, Mesh, Vertex, BrushStroke
- **Sistema de pinceles:** BrushEngine con 10 brush types, stroke modes (paint/sculpt/hybrid), simetria, falloff GPU
- **Shaders Metal:** Shaders.metal con vertex_main, fragment_main, strokeVertex, strokeFragment
- **Undo/Redo:** BrushEngine (50 stacks stroke-level) + CanvasViewModel (50 stacks scene-level) — COMPLETO
- **Renderers:** SatinRenderer (wrapper Satin), PaintRenderer (pipeline Metal), PincelRenderer (billboard quads)
- **Touch + Raycast:** MetalView con ray-triangle intersection, deformacion en tiempo real — COMPLETO
- **Exportacion:** ExportService OBJ + STL via ModelIO, ExportView con progreso y alertas, ExportViewModel async
- **CAD Tools engines:** BevelEngine, BooleanEngine, ExtrusionEngine, LoopCutEngine, MeasureEngine (5/5 implementados)
- **SculptEngine:** SculptEngine + 8 Deformers (Crease, Flatten, Grab, Inflate, Move, Pinch, Smooth, Twist)
- **ViewModels:** AppState, CanvasViewModel, ToolViewModel, ExportViewModel — COMPLETO
- **UI:** ContentView (orbit controls), MetalView (pipeline), SculptModeView (brushes + undo/redo), CADModeView (toolbar + tools), HybridModeView (submodos), ExportView
- **Dependencias:** Package.swift con Satin v0.3.0 (SPM), target iOS 17

### Pendiente 🔴

#### Fase 4 — Animacion + Subdivision (ALTA PRIORIDAD)
- [ ] Animacion basica con keyframes (interpolacion de transformaciones)
- [ ] Subdivision de malla dinamica (Catmull-Clark)
- [ ] Remesh / DynTopo

#### CAD Mode — UI Integration (MEDIA PRIORIDAD)
- [ ] Conectar UI de CADModeView con los 5 engines existentes
- [ ] Toolbar funcional con botones para cada herramienta
- [ ] Visualizacion de mediciones en 3D

#### Hybrid Mode — Funcionalidad (MEDIA PRIORIDAD)
- [ ] Logica de capas (pintura + escultura combinadas)
- [ ] Intercambio fluido entre submodos CAD/Sculpt/Paint
- [ ] Sistema de blending entre modos

#### SatinRenderer — Pipeline Integration (MEDIA PRIORIDAD)
- [ ] Conectar SatinRenderer con el pipeline principal de render
- [ ] Unificar SatinRendererView con MetalView existente

#### Limpieza de Estructura (BAJA PRIORIDAD)
- [ ] Eliminar duplicado de Shaders.metal en Sources/
- [ ] Eliminar carpeta vacia AppForgeStudio/ en raiz del repo (MetalEngine, Services, Views)
- [ ] Archivar ~20 archivos .md de sesiones anteriores en /archive/
- [ ] Verificar que Sources/ no tenga archivos desactualizados vs AppForgeStudio/

## Proximos Hitos
| Hito | Descripcion | Prioridad |
|------|-------------|-----------|
| Fase 4a | Animacion basica con keyframes | ALTA |
| Fase 4b | Subdivision Catmull-Clark | ALTA |
| Fase 4c | Remesh / DynTopo | ALTA |
| CAD UI | Conectar engines con toolbar | MEDIA |
| Hybrid | Funcionalidad capas + blending | MEDIA |
| Satin Pipe | Integrar SatinRenderer con pipeline | MEDIA |
| Cleanup | Eliminar duplicados y archivar sesiones | BAJA |
