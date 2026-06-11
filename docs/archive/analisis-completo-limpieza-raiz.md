# Análisis Completo: Limpieza Raíz Madre vs Sub-proyecto iOS
> Fecha: 2026-05-12 | Sesión completa

---

## 1. El Problema: Desorden Creado por Gotchi

Se crearon archivos y carpetas en la raíz madre (`C:\Users\USUARIO\Projects\appforge-studio\`) que **no debían estar ahí**, duplicando y ensuciando la estructura del proyecto real que vive en el sub-proyecto.

---

## 2. Diagnóstico de la Raíz Madre (`C:\Users\USUARIO\Projects\appforge-studio\`)

### Archivos canónicos duplicados (CREADOS POR GOTCHI en esta sesión)
| Archivo | Origen | Destino correcto |
|---|---|---|
| `GOTCHI.md` | Gotchi (12 may 2026) | Ya existe en `ios-app/AppForgeStudio/GOTCHI.md` |
| `BRAIN.md` | Gotchi (12 may 2026) | Ya existe en registry del proyecto |
| `TODO.md` | Gotchi (12 may 2026) | Ya existe en `ios-app/AppForgeStudio/TODO.md` |

### DECISIONS.md — ÚNICO archivo que SÍ vale (NO tocado)
- Contiene 52+ entradas histórico real desde febrero 2026
- Decisiones sobre: migración Satin, arquitectura de shaders, CSG approach, timeline
- Fue creado antes de esta sesión, no por mí

### Carpeta `Sources/CADCore/` — Vestigio (ELIMINADA)
- 5 engines CAD: ChamferEngine, FilletEngine, LoftEngine, ShellEngine, SweepEngine
- Eran **copias migradas desde sesiones anteriores** a la raíz por error
- Los originales ya existen en `ios-app/AppForgeStudio/Core/CADCore/`
- ✅ Backup archivado en `_archive/vestigios-raiz-2026-05-12/`
- ✅ Eliminada de raíz

### Carpetas auxiliares creadas por Gotchi
| Carpeta | Contenido | Estado |
|---|---|---|
| `_archive/` | Vestigios de sesiones pasadas | OK — útil como histórico |
| `docs/` | Análisis de sesiones anteriores | ✅ Movido a `_archive/` del sub-proyecto |

### `Hi-Rez-Satin/` — Referencia externa
- Clon del framework Satin (dependencia upstream, no código del proyecto)
- Se deja intacto como referencia

---

## 3. Diagnóstico del Sub-proyecto (`C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\`) — CÓDIGO REAL

### Estructura general (47 engines total)

```
ios-app/AppForgeStudio/
├── Package.swift                    ← Compilable con Satin 0.4.0
├── AppForgeStudio/                 ← Entry point SwiftUI
├── Core/
│   ├── CADCore/                    ← 7 engines CAD (Chamfer, Fillet, Loft, Shell, Sweep, BooleanCut, ProfileExtrude)
│   ├── CSG/                        ← Shape.swift (CSG boolean stub), OCCTEngine wrapper
│   ├── Managers/                   ← AnimationEngine, PaintRenderer, shaders Metal
│   └── Services/                   ← ExportService (OBJ/STL/USDZ), ModelLoadService
├── Features/
│   ├── CADMode/                    ← Parser OCP + UI CAD
│   ├── SculptMode/                 ← UI escultura
│   ├── HybridMode/                 ← UI híbrido
│   └── ExportMode/                 ← UI exportación
├── Sculpting/                      ← SculptEngine + 8 Deformers (Pinch, Inflate, Crease, Flatten, Rotate, Scale, Smooth, Grab)
├── UI/Components/                  ← MetalView, ContentView
└── ViewModels/                     ← AppState, CanvasViewModel
```

### Estado por Fase

| Fase | Estado | Detalle |
|---|---|---|
| **Fase 1: Pintura 3D** | ✅ COMPLETA | PaintRenderer, PBRMaterial, IblPipeline. Pending: 0 |
| **Fase 2: Escultura** | ✅ COMPLETA | SculptEngine + 8 deformers. Pending: 0 |
| **Fase 3: CAD paramétrico** | ✅ COMPLETA | 7 CAD engines + Shape.swift stub + Parser OCP |
| **Fase 4: Animación** | ✅ COMPLETA | AnimationEngine, MorphEngine, timeline. Pending: 0 |
| **Fase 5: Exportación STEP** | 🔴 PENDIENTE | ExportService tiene OBJ/STL/USDZ, falta STEP real |
| **Fase 6: Tests** | 🔴 PENDIENTE | Cero tests unitarios |

### Pendientes reales (después de depurar TODO.md)

| # | Item | Prioridad |
|---|---|---|
| 1 | **CSG booleans reales** en Shape.swift (union, difference, intersection) — actualmente son identity ops | 🔴 FOCO |
| 2 | ExportService STEP — validar con modelo real | 🟡 |
| 3 | Conectar botón de exportación en UI de ExportMode | 🟡 |
| 4 | Tools CAD (9 tools: Box, Sphere, Cylinder, Cone, Torus, Extrude, Revolve, Sweep, Loft) — UI creada pero lógica al 0% | 🟡 |
| 5 | Unit tests para AnimationEngine (XCTest) | 🟢 |

### Correcciones aplicadas a canónicos del sub-proyecto

1. **GOTCHI.md** — Eliminada mención a `OCCTSwift` que no existe en el código (era un wrapper planeado pero nunca implementado)
2. **TODO.md** — Depurados 39 items legacy de Fase 1 que ya estaban completados (ensamblaje PaintRenderer/SculptEngine/AnimationEngine, mover Assets/Shaders, verificar existencia de archivos)
3. **DECISIONS.md** — Intacto (estaba correcto)

---

## 4. Resumen de Acciones Ejecutadas

| Acción | Estado |
|---|---|
| Workspace del registry corregido a `ios-app/AppForgeStudio` | ✅ |
| `Sources/CADCore/` (5 engines duplicados) eliminado de raíz | ✅ |
| Backup `vestigios-raiz` archivado en `_archive/` | ✅ |
| `docs/unificacion-canonicos-2026-05-12.md` movido a `_archive/` | ✅ |
| `GOTCHI.md` del sub-proyecto corregido (OCCTSwift) | ✅ |
| `TODO.md` del sub-proyecto depurado (de 50 a 5 items reales) | ✅ |
| Brain actualizado con ESTADO ACTUAL y PRÓXIMAS ACCIONES | ✅ |

---

## 5. Recomendaciones

1. **El workspace ya es correcto** — todo el desarrollo debe hacerse en `ios-app/AppForgeStudio/`
2. **Shape.swift** debe migrarse de identity ops a CSG real (BSP tree o intersección de mallas MetalKit)
3. **Los 5 engines CAD archivados** son copias exactas de lo que ya está vivo en `Core/CADCore/` — no hay pérdida
4. **DECISIONS.md** de raíz debe mantenerse como log histórico — contiene contexto valioso sobre decisiones arquitectónicas
