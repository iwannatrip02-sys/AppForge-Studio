# AppForge Studio iOS: Lo que tenemos y lo que falta para superar Shapr3D + Esculpido + Paint3D
> Fecha: 2026-05-11 | Proyecto real: ios-app/AppForgeStudio/

## LO QUE TENEMOS — Inventario Real

### Stack Técnico
| Componente | Detalle |
|---|---|
| Lenguaje | Swift 6.0 |
| UI | SwiftUI (iOS 17+) |
| Render | Satin (Metal 2) — pipeline GPU completo |
| CAD Kernel | OCCTSwift (Open CASCADE Technology) — paramétrico profesional |
| Target | AppForgeStudio (executable) + AppForgeStudioTests |

### Arquitectura (7 subdirectorios en Core/)
1. **Core/CAD/** — 12+ operaciones: extrude, revolve, loft, boolean ops (union/subtract/intersect), chamfer, fillet, shell, thicken, sweep, helix, section, measure
2. **Core/Engines/** — 47 archivos: SatinRenderer, PBRMaterial, IBLPipeline, Scene3D, AnimationEngine, SculptEngine, SDFEngine, SubdivisionEngine, BrushEngine, PincelRenderer, etc.
3. **Core/Managers/** — RenderManager, AnimationManager, SceneManager, ThemeManager, LODManager, ModelCacheService
4. **Core/Services/** — ExportServiceSTEP, ModelLoadService, HapticService, CrashReporter, ExportViewModel
5. **Core/Shaders/** — Metal shaders (.metal files)
6. **Core/Theme/** — AppTheme, ThemeManager
7. **Core/UI/** — ContentView.swift, CanvasViewModel.swift, MaterialEditorViewModel.swift, ToolViewModel.swift, MetalView, SatinRendererView, ColorPickerView, GridView2

### 7 Modos de UI (Features/)
| Modo | Estado |
|---|---|
| **CADMode** ⭐ | Más completo: sketch engine, constraint solver, gesture handler, history tree, material editor PBR |
| **SculptMode** | SculptEngine + 8 deformers (Grab, Move, Smooth, Inflate, Pinch, Crease, Flatten) + Brushes/ |
| **PaintMode** | Editor PBR con capas, pinceles, texturas |
| **AnimationMode** | Keyframe timeline, play/pause, slider, conectado a SatinRenderer (Fase 4 completa) |
| **ExportMode** | STL, OBJ, STEP, ARQuickLook |
| **RenderMode** | Preview render con Metal |
| **HybridMode** | Combinación CAD + Sculpt |

### Tests (6 archivos)
- AnimationEngineTests.swift
- AnimationPlaybackTests.swift
- ExportServiceTests.swift
- GeometryConstraintManagerTests.swift
- ModelCacheServiceTests.swift
- AppForgeStudioTests/

### Archivos Clave Verificados
| Archivo | Ruta |
|---|---|
| ContentView (principal) | Core/UI/ContentView.swift |
| ContentView (CAD) | Features/CADMode/ContentView.swift |
| CanvasViewModel | Core/UI/CanvasViewModel.swift |
| SatinRenderer | (en Engines/) |
| AnimationEngine | Core/Engines/AnimationEngine.swift |
| AppForgeStudioApp | backup_sources/AppForgeStudioApp.swift |

### Backup Legacy
- `backup_sources/` — 60+ archivos Swift de la versión pre-migración
- `Sources_backup.zip` — backup comprimido adicional

## LO QUE FALTA para llegar a "Máximo Nivel: intuitivo+fácil+potente > Shapr3D+Esculpido+Paint3D"

### 🟥 CRÍTICO — Bloqueante
| # | Qué falta | Por qué es crítico |
|---|---|---|
| 1 | **ContentView + CanvasViewModel NO verificados por budget** | Sabemos dónde están (Core/UI/) pero no pudimos leerlos. Sin ContentView y su ViewModel, no sabemos si la app cablea correctamente los 7 modos. Es el root de la app. |
| 2 | **Compilación NO validada** | Package.swift usa Satin + OCCTSwift como dependencias externas. No sabemos si resuelven, si los paths de sources son correctos, o si hay errores de compilación. Esto requiere Xcode en macOS. |
| 3 | **AppForgeStudioApp.swift está en backup_sources/ NO en Sources/** | El entry point de la app no está donde Package.swift espera. Package.swift busca en `Sources/` pero AppForgeStudioApp.swift está en `backup_sources/`. Esto probablemente impide compilar. |

### 🟧 ALTA PRIORIDAD — Diferencial competitivo vs Shapr3D
| # | Qué falta | Shapr3D lo tiene |
|---|---|---|
| 4 | **UX pulida: onboarding interactivo** | Shapr3D tiene onboarding táctil guiado |
| 5 | **Feedback háptico completo** — no solo HapticService, sino en cada interacción (extrude, select, grab) | Shapr3D tiene haptics contextuales |
| 6 | **Gestos multi-touch nativos** — pinz-to-zoom, rotación con 2 dedos, selección con tap | Sin gestos fluidos, la UX se siente tosca vs Shapr3D |
| 7 | **Modo oscuro completo** (AppTheme existe pero no sabemos si cubre toda la UI) | Shapr3D tiene tema unificado |
| 8 | **LOD automático** (LODManager existe en backup_sources, hay que integrarlo al render loop) | Shapr3D maneja mallas complejas sin lag |

### 🟨 MEDIA PRIORIDAD — Características "potentes"
| # | Qué falta | Impacto |
|---|---|---|
| 9 | **OIT Transparency** — Order-Independent Transparency en Metal | Render profesional de materiales translúcidos |
| 10 | **Subdivision surfaces preview** (SubdivisionEngine existe) | Smooth preview en tiempo real (Shapr3D lo tiene) |
| 11 | **AR QuickLook export** (ExportMode tiene ARQuickLookView pero no sabemos si genera archivos USDZ) | Vista previa AR del modelo (diferenciador vs Shapr3D) |
| 12 | **Constraint solver visual** — mostrar constraints en la UI mientras se dibuja el sketch | Shapr3D muestra constraints en vivo |
| 13 | **Snapping magnético** — snap a grid, snap a puntos, snap a ángulos | Precisión CAD profesional |
| 14 | **Undo/Redo visual** — CADHistoryTree existe pero no sabemos si está bindeado a la UI | Sin undo visual la UX no es profesional |

### 🟩 BAJA PRIORIDAD — Polish final
| # | Qué falta |
|---|---|
| 15 | Loading screen con progreso real (LoadingScreenView existe en backup_sources) |
| 16 | OnboardingView en backup_sources — integrar al flujo de primera ejecución |
| 17 | PreferencesView en backup_sources — settings de usuario |
| 18 | Grid 2D/3D toggle (GridView2 en backup_sources) |
| 19 | ColorPickerView (existe en Core/UI/) — verificar integración con materiales PBR |
| 20 | Test coverage — solo 6 tests para 60+ archivos |

### DIFERENCIAL ÚNICO — Lo que YA tenemos que Shapr3D NO tiene
| Característica | AppForge Studio | Shapr3D |
|---|---|---|
| **Pintura 3D PBR** | ✅ PaintMode con capas y pinceles | ❌ No tiene |
| **Esculpido** | ✅ SculptEngine + 8 deformers + SDF | ❌ No tiene (es solo CAD paramétrico) |
| **Animación por keyframes** | ✅ AnimationEngine conectado a render loop | ❌ No tiene |
| **Render Metal nativo** | ✅ Satin + Metal 2 pipeline | ✅ Sí, Metal |
| **AR QuickLook** | ✅ ExportMode con ARQuickLookView | ✅ Sí |
| **CAD paramétrico** | ✅ OCCTSwift (Open CASCADE) | ✅ Propietario |
| **Export STEP/STL/OBJ** | ✅ ExportServiceSTE | ✅ Sí |

## CONCLUSIÓN: Score actual vs Meta "Maximo nivel > Shapr3D + Sculpt + Paint"

| Dimensión | Score (1-10) | Notas |
|---|---|---|
| Potencia técnica (engines) | **8/10** | 47 engines, 12 CAD ops, 8 deformers, animación, PBR — best in class iOS |
| UX / Intuitividad | **4/10** | Falta onboarding, gestos, haptics, undo visual, snapping — la UX no está pulida |
| Completitud funcional | **6/10** | 7 modos escritos pero NO sabemos si compilan ni si cablean correctamente |
| Diferenciación vs Shapr3D | **7/10** | Paint3D + Sculpt + Animation son diferenciales únicos que Shapr3D no tiene |
| Calidad de código | **5/10** | ContentView duplicado, AppForgeStudioApp en backup_sources, solo 6 tests |

**Score global: 6/10** — La arquitectura y los motores son impresionantes (47 engines, Metal, OCCTSwift), pero la app no está ensamblada: el entry point está en backup, los ViewModels no están verificados, y la UX necesita polish completo. El potencial para superar Shapr3D+sculpt+paint es REAL porque YA tenemos paint3D, sculpt y animación que Shapr3D no tiene — solo falta cablear todo correctamente y pulir UX.

## PRÓXIMOS PASOS RECOMENDADOS

1. ✅ **Inmediato**: Leer Core/UI/ContentView.swift y Core/UI/CanvasViewModel.swift (pendiente)
2. ⬜ Mover AppForgeStudioApp.swift de backup_sources/ a Sources/AppForgeStudio/
3. ⬜ Validar Package.swift compila (requiere Xcode en macOS)
4. ⬜ Unificar ContentView (eliminar duplicado Features/CADMode/ContentView.swift)
5. ⬜ Integrar LODManager, LoadingScreenView, OnboardingView desde backup_sources
6. ⬜ Agregar snapping, gestos multi-touch, haptics contextuales
7. ⬜ Tests: expandir de 6 a 30+ tests cubriendo CAD ops, sculpt, paint
