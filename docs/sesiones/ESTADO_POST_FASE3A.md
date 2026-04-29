# Estado Post-Fase 3A — AppForge Studio
> 2026-04-27 20:38 UTC | Verificación de archivos existentes y tareas pendientes

## Archivos Verificados EXISTEN

### Sources/ (unificada post-Fase3A)
| Archivo | Ruta | Estado |
|---------|------|--------|
| AppForgeStudioApp.swift | ios-app/Sources/ | OK |
| ContentView.swift | ios-app/Sources/ | OK |
| Package.swift | ios-app/Sources/ | OK |
| Shaders.metal | ios-app/Sources/ | OK (completo) |
| Renderer/ | ios-app/Sources/ | OK |

### AppForgeStudio/ (rama completa)
| Archivo | Ruta | Estado |
|---------|------|--------|
| Package.swift | ios-app/AppForgeStudio/ | OK |
| AppForgeStudioApp.swift | ios-app/AppForgeStudio/AppForgeStudio/ | OK |
| SatinRenderer.swift | ios-app/AppForgeStudio/AppForgeStudio/ | OK (no conectado) |
| Scene3D.swift | ios-app/AppForgeStudio/Models/ | OK |
| Mesh.swift | ios-app/AppForgeStudio/Models/ | OK |
| BrushStroke.swift | ios-app/AppForgeStudio/Models/ | OK |
| PaintRenderer.swift | ios-app/AppForgeStudio/Core/Managers/ | OK |
| PincelRenderer.swift | ios-app/AppForgeStudio/Core/Managers/ | OK |
| Shaders.metal | ios-app/AppForgeStudio/Core/Managers/ | COMPLETO |
| ExportService.swift | ios-app/AppForgeStudio/Core/Services/ | OK |
| ModelLoadService.swift | ios-app/AppForgeStudio/Core/Services/ | OK |
| CanvasViewModel.swift | ios-app/AppForgeStudio/ViewModels/ | CREADO F3A |
| ToolViewModel.swift | ios-app/AppForgeStudio/ViewModels/ | CREADO F3A |
| AppState.swift | ios-app/AppForgeStudio/ViewModels/ | CREADO F3A |
| SculptEngine.swift | ios-app/AppForgeStudio/Sculpting/ | CREADO F3A |

## Tareas PENDIENTES (del roadmap original, NO ejecutadas)

### CRITICO — Exportación y Pulido (Fase 3 del plan estratégico)
- [ ] ExportViewModel.swift — Lógica de exportación separada
- [ ] Verificar ExportService.swift funcional (OBJ + STL vía ModelIO)
- [ ] Animación básica con keyframes
- [ ] Onboarding tutorial
- [ ] UI pulida para iPad

### ALTA PRIORIDAD — Roadmap items pendientes
- [ ] Deformers/ — Cada deformador como clase separada (inflate, pinch, smooth, crease, grab, flatten, twist, move)
- [ ] Subdivision de malla dinámica (Catmull-Clark)
- [ ] Remesh / DynTopo
- [ ] UndoManager central (Command pattern) con Commands/
- [ ] CAD Tools/ — Implementar herramientas (extrusión, loop cut, bevel, boolean operations)
- [ ] Sistema de mediciones completo

### MEDIA PRIORIDAD
- [ ] Conectar SatinRenderer con el pipeline principal
- [ ] ViewModels para CAD, Sculpt, Hybrid mode
- [ ] HybridModeView completo
- [ ] ExportView funcional
- [ ] Preview/ contenido
- [ ] Resources/ contenido
- [ ] UI/ — Componentes reutilizables
- [ ] Core/ViewModels/ — ViewModels del core
- [ ] Core/Models/ — Modelos del core

## Próximas Acciones Inmediatas
1. Crear ExportViewModel.swift
2. Verificar y completar ExportService.swift
3. Crear Deformers/ con clases separadas para cada deformador