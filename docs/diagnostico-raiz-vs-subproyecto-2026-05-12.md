# Diagnostico: Raiz Madre vs Sub-proyecto iOS
> Fecha: 2026-05-12 | Objetivo: Determinar que archivos sirven, cual ubicacion es la fuente real, y que limpiar

## 1. ARBOL COMPARATIVO

### Ubicacion A — Raiz Madre: `C:\Users\USUARIO\Projects\appforge-studio\`
```
appforge-studio/
├── GOTCHI.md              ← CREADO POR GOTCHI 2026-05-12 (puntero)
├── BRAIN.md               ← CREADO POR GOTCHI 2026-05-12 (resumen)
├── TODO.md                ← CREADO POR GOTCHI 2026-05-12 (11 items legacy + 4 reales)
├── DECISIONS.md           ← CREADO POR GOTCHI sesiones anteriores
├── Sources/CADCore/       ← VESTIGIO — 5 engines CAD duplicados
│   ├── ChamferEngine.swift
│   ├── FilletEngine.swift
│   ├── LoftEngine.swift
│   ├── ShellEngine.swift
│   └── SweepEngine.swift
├── _archive/              ← CREADO POR GOTCHI (vestigios de sesiones pasadas)
├── docs/                  ← CREADO POR GOTCHI 2026-05-12 (analisis de unificacion)
├── Hi-Rez-Satin/          ← REFERENCIA EXTERNA (clon Satin upstream)
└── ios-app/AppForgeStudio/ ← CODIGO REAL
```

### Ubicacion B — Sub-proyecto iOS: `C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\`
```
AppForgeStudio/
├── Package.swift           ← COMPILABLE — depende de Satin 0.4.0
├── AppForgeStudio/         ← Entry app SwiftUI
├── Core/
│   ├── CADCore/            ← 7 engines CAD LIVE (los reales)
│   ├── CSG/                ← Shape.swift (CSG identity stub) + OCCTEngine.swift
│   ├── Managers/           ← AnimationEngine, PaintRenderer, shaders
│   └── Services/           ← ExportService, ModelLoadService
├── Features/               ← CADMode, SculptMode, HybridMode, ExportMode
├── Models/                 ← Scene3D, Model, PBRMaterial
├── Sculpting/              ← SculptEngine + 8 Deformers
├── UI/Components/          ← MetalView, ContentView
└── ViewModels/             ← AppState, CanvasViewModel
├── GOTCHI.md               ← CANONICO LOCAL (reglas Swift/Metal)
├── BRAIN.md                ← CANONICO LOCAL (estado del sub-proyecto)
├── TODO.md                 ← CANONICO LOCAL (pendientes del sub-proyecto)
└── DECISIONS.md            ← CANONICO LOCAL (decisiones locales)
```

## 2. DIAGNOSTICO — QUE ES REAL Y QUE ES VESTIGIO

### CODIGO REAL (vive en Sub-proyecto iOS)
| Componente | Archivos | Estado |
|---|---|---|
| 7 CAD engines | `Core/CADCore/*.swift` | Implementados (extrude, revolve, sweep, loft, fillet, chamfer, shell) |
| SculptEngine + 8 Deformers | `Sculpting/*.swift` | Implementados |
| AnimationEngine | `Core/Managers/AnimationEngine.swift` | COMPLETO (Phase 4) |
| PaintRenderer + shaders | `Core/Managers/PaintRenderer.swift`, `Shaders/` | Implementados |
| ExportService (OBJ/STL) | `Core/Services/ExportService.swift` | Funcional sin boton en UI |
| ModelLoadService | `Core/Services/ModelLoadService.swift` | Implementado |
| Shape.swift (CSG) | `Core/CSG/Shape.swift` | Stub — operaciones booleanas son identity |
| Scene3D, Model, PBRMaterial | `Models/` | Implementados |
| 4 Modes (CAD, Sculpt, Hybrid, Export) | `Features/` | UI con pestañas, logica parcial |
| MetalView + ContentView | `UI/Components/` | Implementados |
| AppState, CanvasViewModel | `ViewModels/` | Implementados |

### VESTIGIOS (en raiz madre, duplicados o creados por error)
| Archivo | Problema |
|---|---|
| `Sources/CADCore/ChamferEngine.swift` | DUPLICADO — el real esta en `ios-app/.../Core/CADCore/` |
| `Sources/CADCore/FilletEngine.swift` | DUPLICADO |
| `Sources/CADCore/LoftEngine.swift` | DUPLICADO |
| `Sources/CADCore/ShellEngine.swift` | DUPLICADO |
| `Sources/CADCore/SweepEngine.swift` | DUPLICADO |
| `GOTCHI.md` | CREADO POR GOTCHI — puntero, no codigo real |
| `BRAIN.md` | CREADO POR GOTCHI — resumen, el brain real esta en el registry |
| `TODO.md` | CREADO POR GOTCHI — 11 items legacy, 4 reales (ya movi los reales al sub-proyecto) |
| `DECISIONS.md` | CREADO POR GOTCHI — decisiones de sesiones pasadas |
| `docs/unificacion-canonicos-2026-05-12.md` | CREADO POR GOTCHI hoy — analisis temporal |
| `_archive/` | CREADO POR GOTCHI — vestigios archivados |

### REFERENCIAS EXTERNAS (no tocar)
| Directorio | Proposito |
|---|---|
| `Hi-Rez-Satin/` | Clon upstream de Satin framework — necesario para referencia |
| `blender_source/` o `blender-paint/` | Analisis de brush logic (si existen) |

## 3. CUAL UBICACION ESTA MAS AVANZADA

**El sub-proyecto iOS (`ios-app/AppForgeStudio`) es EL CODIGO REAL** — tiene:
- 47 engines implementados (sculpt, CAD, animation, paint, export)
- Package.swift compilable con Satin 0.4.0 via Swift Package Manager
- Animacion completa (Phase 4 ✅): morph targets, keyframes, timeline
- Arquitectura modular con Managers/Services/Features/Models/Sculpting

**La raiz madre SOLO TIENE**:
- Canonicos que Gotchi creo como punteros (GOTCHI.md, BRAIN.md, TODO.md, DECISIONS.md)
- 5 engines CAD duplicados en `Sources/CADCore/` que ya existen en el sub-proyecto
- Archivos de sesiones pasadas (analisis, archive)

## 4. PLAN DE LIMPIEZA

### Accion inmediata — Mover a _archive/ (NO borrar por si acaso):
1. `Sources/CADCore/` → `_archive/Sources/CADCore/` (los 5 engines duplicados)
2. `docs/unificacion-canonicos-2026-05-12.md` → `_archive/docs/` (analisis temporal ya cumplio su proposito)
3. `_archive/` ya existe y contiene lo que hay

### Los canonicos de raiz (GOTCHI.md, BRAIN.md, TODO.md, DECISIONS.md):
- Servian como puente cuando el workspace apuntaba a la raiz
- AHORA que el workspace apunta a `ios-app/AppForgeStudio`, estos canonicos de raiz son redundantes
- Opcion A: eliminarlos (el sub-proyecto tiene los suyos propios que Gotchi gestiona)
- Opcion B: mantener GOTCHI.md como indice visual del proyecto completo (raiz → sub-proyectos)

### Recomendacion final:
**El codigo productivo esta 100% en `ios-app/AppForgeStudio/`.** La raiz madre solo debe tener:
- `GOTCHI.md` (indice del proyecto completo — opcional)
- `Hi-Rez-Satin/` (referencia externa)
- `_archive/` (vestigios por si se necesitan)
- `ios-app/AppForgeStudio/` (el codigo real)
- Opcionalmente: `README.md` con descripcion del proyecto

**NADA MAS** en la raiz. Todo lo demas se mueve a `_archive/` o se elimina.
