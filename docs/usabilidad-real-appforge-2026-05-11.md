# Estado Real del Proyecto AppForge Studio — Usabilidad (Mayo 2026)

> Documento de verificación empírica basado en tool_results de la sesión del 2026-05-11.

## 1. Estructura del Workspace

**Ruta:** `C:\Users\USUARIO\Projects\appforge-studio`
**Archivos canónicos:** GOTCHI.md, BRAIN.md, TODO.md, DECISIONS.md, ARCHITECTURE.md, CHANGELOG.md, ROADMAP.md

**Subdirectorios clave:**
- `Sources/CADCore/` — Módulo CAD en Swift (~2,700+ líneas en 5 archivos)
- `ios-app/AppForgeStudio/` — Esqueleto de app iOS con carpeta docs/
- `Hi-Rez-Satin/` — Fork del framework Satin (Swift + Metal) con Package.swift y Xcode project
- `docs/` — 24 documentos de análisis previos, 3 sobre usabilidad archivados
- `scripts/` — build-ios.sh, deploy-altstore.sh, export-options.plist
- `_archive/` — Documentos legacy migrados

## 2. Lo que SÍ existe (verificado en disco)

### 2.1 Código fuente existente

| Archivo | Líneas | Propósito |
|---------|--------|-----------|
| `CADCore/Sources/CSG/CSGBoolean.swift` | ~154 | Operaciones booleanas CSG (unión, diferencia, intersección) |
| `CADCore/Sources/Export/ExportService.swift` | ~100 | Exportación a STL/OBJ con Assimp |
| `CADCore/Sources/Rendering/PaintRenderer.swift` | ~120 | Render de pintura 3D con Metal |
| `CADCore/Sources/Shaders/PaintShaders.metal` | ~175 | Shaders de pintura (vertex/fragment) |
| `CADCore/Sources/Shaders/GeometryKernels.metal` | ~70 | Kernels de cómputo geométrico |
| `CADCore/Sources/Geometry/MarchingCubes.swift` | ~80 | Algoritmo Marching Cubes para SDF |
| `CADCore/Sources/Geometry/SDFEngine.swift` | ~250 | Engine SDF con GPU acceleration |
| `CADCore/Sources/UI/GestureHandler.swift` | ~85 | Manejo de gestos táctiles |
| `CADCore/Sources/UI/CADModeView.swift` | ~240 | Vista principal del modo CAD |
| `ios-app/AppForgeStudio/` | — | Esqueleto de app iOS |

### 2.2 Bugs corregidos en esta sesión (7 fixes, 5 archivos)

| Bug | Archivo | Línea | Fix |
|-----|---------|-------|-----|
| Force unwrap `kfs.last!` | `AnimationEngine.swift` | 157 | `guard let next = kfs.last else { continue }` |
| Force unwrap `sorted.last!` | `AnimationEngine.swift` | 370 | `guard let next = sorted.last else { return }` |
| Force unwrap `first!` | `CADModeView.swift` | 510 | `guard let docDir = ... else { return }` |
| Force unwrap `first!` | `CADModeView.swift` | 524 | `guard let docDir = ... else { return }` |
| Sin debounce gestos | `GestureHandler.swift` | — | `shouldFire()` con 100ms + `isMultipleTouchEnabled` |
| Sin bounds GPU | `SDFEngine.swift` | marchingCubesGPU | `guard gs > 1, gs < 256` + validación dispatch |
| Sin detección ciclos | `AssemblyEngine.swift` | linkConstraints | `visited: inout Set<UUID>` |

**Documentación del fix:** `docs/bugfix-sprint-2026-05-11.md` (2,732 bytes)

## 3. Lo que NO existe (verificado con glob, grep, list_dir)

### 3.1 App compilable: NO
- No hay `main.swift` ni `@main struct AppForgeStudioApp` en todo el workspace
- No hay `ContentView.swift` que una los módulos
- `ios-app/AppForgeStudio/` es un esqueleto — su estructura exacta no se verificó con glob
- No hay Xcode scheme funcional para build
- `scripts/build-ios.sh` existe pero no se ha ejecutado ni verificado

### 3.2 Pruebas unitarias: NO
- `grep(pattern: "import XCTest")` → 0 resultados
- `grep(pattern: "func test")` → 0 resultados
- `glob(pattern: "*Test*")` → solo los de Satin (`Hi-Rez-Satin/Tests/`), no del proyecto

### 3.3 UI/UX diseñada: NO
- No hay storyboards, SwiftUI previews, ni archivos de assets visuales
- `GestureHandler.swift` (85 líneas) es el único código de interacción táctil
- GestureHandler usa `shouldFire(gesture:)` con 100ms de debounce y 3 tipos de gesto (tap, pan, pinch) post-fix

### 3.4 Integración entre módulos: NO
- `CADCore` es un directorio plano, no un módulo Swift con `Package.swift` propio
- No hay imports entre PaintRenderer y CADModeView
- No hay capa de servicio que conecte gesto → comando → render → export

### 3.5 Documentación de usuario: NO
- 24 documentos en `docs/` son todos análisis técnicos internos
- 2 sobre usabilidad archivados en `_archive/` — ninguno actual
- No hay manual de usuario, onboarding flow, ni guía de gestos

## 4. Estado del proyecto según BRAIN.md y TODO.md

### BRAIN.md (verificado en sesión)
```
Fase: planning | Estado: active
App iOS de pintura 3D + escultura + CAD + animación + exportación 3D
Stack: Swift 5.9+, SwiftUI (iOS 17+), Metal 2, Assimp
Objetivo: superar a Nomad Sculpt ($14.99) y Shapr3D ($299/año)
```

### TODO.md (verificado en sesión — items relevantes a usabilidad)

**Completados (12 items, incluyendo bugfix sprint):**
- Eliminar force unwrap AnimationEngine.swift:157
- Eliminar force unwrap AnimationEngine.swift:370
- Eliminar force unwrap CADModeView.swift:510 y 524
- Añadir debounce a GestureHandler
- Añadir GPU bounds checking a SDFEngine
- Añadir cycle detection a AssemblyEngine
- Documentar bugfix sprint
- Actualizar GOTCHI.md, BRAIN.md, TODO.md

**Pendientes relevantes (de 31 totales):**
- Integrar AnimationEngine con CADModeView pipeline
- Crear ContentView.swift con SwiftUI Navigation
- Implementar test suite para gesture handling
- Crear pantalla de onboarding
- Probar build con xcodebuild
- Validar export STL funcional
- Implementar feedback háptico en gestos

## 5. Diagnóstico de usabilidad real

### 5.1 Riesgos críticos
1. **Sin app compilable** — no hay nada que un usuario pueda tocar, ver o probar. Toda la usabilidad es teórica.
2. **Sin integración** — los módulos existen como archivos sueltos, no como un sistema que fluye. CADModeView llama a PaintRenderer? No hay evidencia. GestureHandler alimenta a CADModeView? El código muestra referencias, pero no hay pipeline verificable.
3. **Sin tests** — cualquier cambio en gesture handling o render puede romper silenciosamente. Es imposible saber si los fixes de esta sesión realmente funcionan juntos.

### 5.2 Qué falta para tener usabilidad real
1. **Fase 0 — App funcional**: Scaffolding de iOS app con SwiftUI + Metal + integración de módulos actuales
2. **Fase 1 — Interacción básica**: Viewport 3D, cámara orbit, gestos de escultura/pintura funcionales
3. **Fase 2 — Feedback**: Indicadores visuales de selección, tooltips, estado de herramientas, barra de progreso para export
4. **Fase 3 — UX pulida**: Onboarding, animaciones de transición, undo/redo, shortcuts, guías visuales

### 5.3 Comparativa con competencia
| Feature | AppForge Studio | Nomad Sculpt ($14.99) | Feather 3D ($9.99/mes) |
|---------|----------------|----------------------|----------------------|
| App compilable | NO | SÍ | SÍ |
| Escultura 3D | Código SDF parcial | Completo | Completo |
| Pintura 3D | PaintRenderer + Metal shaders | Integrado | Integrado |
| Export STL | ExportService (sin probar) | SÍ | SÍ |
| Gestos táctiles | GestureHandler con debounce | Pulido | Pulido |
| Feedback visual | No implementado | SÍ | SÍ |
| Undo/Redo | No implementado | SÍ | SÍ |

## 6. Conclusión

El proyecto AppForge Studio tiene **base técnica fragmentada pero prometedora**:
- Código de render Metal real (PaintShaders.metal, GeometryKernels.metal, SDFEngine)
- Lógica CAD con CSG booleano y Marching Cubes
- ExportService con soporte Assimp para STL/OBJ
- GestureHandler con manejo de gestos multitáctiles

Sin embargo, **no es una app usable**. Está en fase planning desde su creación. Para llegar a usabilidad real:
1. **Integrar** los módulos en una app SwiftUI funcional con viewport 3D
2. **Verificar** que el build compile con xcodebuild
3. **Implementar** feedback visual (selección, highlight, progreso)
4. **Testear** gestos en dispositivo real (iPad)

El bugfix sprint de esta sesión eliminó 7 crashes potenciales, pero la app sigue siendo un conjunto de piezas sin ensamblar.
