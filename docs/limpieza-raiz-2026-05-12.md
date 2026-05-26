# Limpieza Raíz Madre — Diagnóstico Completo
> 2026-05-12 | Basado en datos verificados en esta sesión

---

## 1. Estructura actual de C:\Users\USUARIO\Projects\appforge-studio\

```
appforge-studio/
├── GOTCHI.md           ← CREADO POR GOTCHI (hoy) — puntero al sub-proyecto
├── BRAIN.md            ← CREADO POR GOTCHI (hoy) — summary de limpieza
├── TODO.md             ← CREADO POR GOTCHI (hoy) — 4 items pendientes
├── DECISIONS.md        ← Histórico (desde feb 2026) — decisiones reales del proyecto
├── Sources/CADCore/    ← VESTIGIO — 5 engines CAD duplicados
│   ├── ChamferEngine.swift
│   ├── FilletEngine.swift
│   ├── LoftEngine.swift
│   ├── ShellEngine.swift
│   └── SweepEngine.swift
├── _archive/           ← CREADO POR GOTCHI (hoy)
│   └── vestigios-raiz-2026-05-12/
│       └── Sources/CADCore/  ← YA ARCHIVADO (copia de seguridad)
├── docs/               ← CREADO POR GOTCHI (hoy)
│   └── unificacion-canonicos-2026-05-12.md
├── Hi-Rez-Satin/       ← REFERENCIA EXTERNA (Satin clone, OK)
└── ios-app/
    └── AppForgeStudio/ ← CÓDIGO REAL DEL PROYECTO (47 engines)
```

---

## 2. ¿Qué sirve de la raíz para el sub-proyecto?

| Archivo raíz | ¿Sirve? | Acción |
|---|---|---|
| `GOTCHI.md` | Parcial — apunta correctamente al sub-proyecto | Mantener como puntero o actualizar |
| `BRAIN.md` | Parcial — resume estado de limpieza | Puede pasar a `_archive/` |
| `TODO.md` | **SÍ** — contiene los 4 pendientes reales que también aparecen en el TODO.md del sub-proyecto | Fusionar/mantener solo en sub-proyecto |
| `DECISIONS.md` | **SÍ** — histórico real desde feb 2026 | MANTENER en raíz (es histórico genuino) |
| `Sources/CADCore/` | **NO** — 5 engines duplicados (Chamfer, Fillet, Loft, Shell, Sweep ya existen en el sub-proyecto) | ELIMINAR (ya archivados en `_archive/`) |
| `docs/unificacion-canonicos-2026-05-12.md` | **NO** — análisis de esta sesión | Mover a `_archive/` o eliminar |
| `Hi-Rez-Satin/` | **SÍ** — clon de Satin como referencia externa | MANTENER |

---

## 3. Comparación: Engines CAD en raíz vs sub-proyecto

**Raíz `Sources/CADCore/`** (5 archivos, todos vestigio):
- ChamferEngine.swift — `//` (solo struct con función `apply()`)
- FilletEngine.swift — `//` (solo struct)
- LoftEngine.swift — `//` (solo struct)
- ShellEngine.swift — `//` (solo struct)
- SweepEngine.swift — `//` (solo struct)

**Sub-proyecto `Core/CADCore/`** (7 engines reales):
- BevelEngine.swift — con lógica real
- BooleanEngine.swift — con lógica real
- ChamferEngine.swift
- ExtrudeEngine.swift
- FilletEngine.swift
- LoftEngine.swift
- ShellEngine.swift
- SweepEngine.swift

Conclusión: los 5 de la raíz son DUPLICADOS, versión más antigua/parcial. Los del sub-proyecto son los reales.

---

## 4. Canónicos del sub-proyecto — estado actual

| Archivo | Contenido | Problema |
|---|---|---|
| `GOTCHI.md` | Stack, estructura, fases. Menciona **OCCTSwift** | OCCTSwift NO existe (0 archivos lo importan). Desactualizado. |
| `BRAIN.md` | No se encontró (404 en lectura) | ¿Fue eliminado o nunca existió? El registry tiene brain aparte. |
| `TODO.md` | **23 items**, muchos de Fase 1 marcados [x] | Mezcla items legacy completados con 4 pendientes reales. Necesita depuración. |
| `DECISIONS.md` | 52 entradas, última: 2026-03 | Histórico completo, OK. |

---

## 5. Pendientes reales (cruzando raíz TODO.md + sub-proyecto TODO.md)

Ambos TODO.md coinciden en estos 4 items:

1. **🔴 CSG boolean operations reales** en `Shape.swift` — actualmente son identity ops (solo copian mesh A). Falta algoritmo BSP tree o intersección de mallas.
2. **🟡 ExportService STEP** — validar exportación con modelo real (STEP funciona en código pero no probado con archivo real).
3. **🟡 Botón exportación en UI** — ExportMode tiene las vistas pero el botón de exportar no está conectado a ExportService.
4. **🟢 Unit tests AnimationEngine** — XCTest framework configurado, tests por escribir.

Además, en el TODO.md del sub-proyecto hay items legacy que ya están completados (Fase 1-4) y deberían limpiarse.

---

## 6. Plan de acción propuesto

| Paso | Acción | Riesgo |
|---|---|---|
| 1 | Eliminar `Sources/CADCore/` de la raíz | Ninguno — ya archivado en `_archive/` y duplicado en sub-proyecto |
| 2 | Eliminar `docs/unificacion-canonicos-2026-05-12.md` de la raíz | Ninguno — el análisis está en el chat de esta sesión |
| 3 | Mover `docs/` y `_archive/` de la raíz a `_archive/` del sub-proyecto | Bajo — solo mover, no borrar |
| 4 | Actualizar `GOTCHI.md` del sub-proyecto: eliminar OCCTSwift | Bajo — solo texto |
| 5 | Depurar `TODO.md` del sub-proyecto: eliminar items legacy completados | Bajo — solo texto, items ya están [x] |
| 6 | Mantener 4 canónicos en raíz como punteros mínimos al sub-proyecto | Bajo |
| 7 | Arrancar con el foco real: CSG boolean operations en Shape.swift | Alto — es código nuevo |

---

## 7. Resumen para Andrés

- **El desorden que creé**: `Sources/CADCore/` duplicado, `docs/` y `_archive/` en raíz, `GOTCHI.md`/`BRAIN.md`/`TODO.md` que duplican info del sub-proyecto.
- **Nada útil único en la raíz** que no esté ya en el sub-proyecto, excepto `DECISIONS.md` (histórico) y `Hi-Rez-Satin/` (referencia).
- **El código real está en `ios-app/AppForgeStudio/`** con 47 engines, `Package.swift` compilable, y fases 1-4 completas.
- **El foco correcto**: CSG boolean operations reales en Shape.swift.
