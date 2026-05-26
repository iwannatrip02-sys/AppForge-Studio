# Decisiones de arquitectura

## 2026-05-05: Implementación CAD paramétrico

**Decisión:** Se implementó solver Gauss-Seidel propio en Swift en vez de wrapper C API de SolveSpace.

**Razón:** Evita dependencia de librería C externa, acelera time-to-build, permite ite-rar rápido en fase de planning. Si en producción no converge bien, se migra a SolveSpace C API via XCFramework.

**Archivos creados (8):**
- `Sources/CADCore/GeometryEntity.swift` — tipos point/line/circle/arc/nurbs
- `Sources/CADCore/GeometryConstraint.swift` — 9 tipos de constraint
- `Sources/CADCore/SolveSpaceSolver.swift` — solver Gauss-Seidel 100 iter
- `Sources/CADCore/CADHistoryTree.swift` — undo/redo con CADOperation
- `Sources/CADCore/GeometryConstraintManager.swift` — singleton con notificaciones
- `Sources/CADCore/CADSketchEngine.swift` — motor de bocetos paramétricos
- `Sources/CADCore/ExtrudeEngine.swift` — extrusión 2D→3D
- `Sources/CADSketchView.swift` — UI SwiftUI completa

**Pendientes:**
- CAD-8: Integrar CADSketchView con CADModeView (no encontrado en disco)
- CAD-9: Conectar GeometryConstraintManager.shared con Scene3D (no encontrado en disco)
- CAD-10: Verificar Package.swift incluya Sources/CADCore/*

## 2026-05-07 — Mantener ambos GeometryConstraintManager como archivos separados con distintas responsabilidades
**Razón:** Sources/CADCore/GeometryConstraintManager.swift usa SolverSwift para resolver constraints 2D puros. Core/Managers/GeometryConstraintManager.swift es ObservableObject con closures para UI 3D. Son roles distintos: uno es solver interno, otro es manager de UI. No deben fusionarse.
**Alternativas descartadas:**
- Fusionar en un solo archivo (complejidad innecesaria)
- Eliminar Core/Managers/ (lo usa la UI para constraints visuales)
**Impacto:** medium


## 2026-05-07 — Refactorizar modulo CAD: unificar enums, eliminar duplicados, conectar constraints
**Razón:** 5 bugs estructurales bloquean compilacion: CADTool incompleto con 10+ casos faltantes, CADSketchEngine duplicado en 2 rutas, constraints duales desconectados, CADHistoryTree legacy, y pipeline sketch-extrusion sin integracion real. Corregir en una sola pasada con code_agent antes de avanzar a nuevas features.
**Alternativas descartadas:**
- Parche parcial archivo por archivo (tardaria 3+ turnos)
- Ignorar y seguir con nuevas features (acumularia deuda tecnica)
**Impacto:** high


## 2026-05-07 — Ruta híbrida de compilación para AppForge Studio: Macly.io (~$30/mes) como Mac cloud primario + GitHub Actions self-hosted runner en cualquier Mac disponible + Xcode Cloud free tier (50h/mes) como respaldo
**Razón:** Tras investigar 8 fuentes: Swift Package Manager no soporta Metal shaders nativamente (bug conocido #8930), MetalCompilerPlugin existe como workaround pero es limitado. La opción más barata viable es Macly.io (~$1/día), muy por debajo de los $299/año de Shapr3D. Además, GitHub Actions con self-hosted runner en cualquier Mac es completamente gratis. Se documentó todo en docs/ruta-compilacion-gratuita.md
**Alternativas descartadas:**
- Compilar solo con SPM en Linux (Metal no funciona fuera de Apple Silicon)
- Swift Playgrounds en iPad (limitado, no soporta Metal nativo complejo)
- Solo Xcode Cloud (50h/mes insuficientes para desarrollo intensivo)
**Impacto:** high


## 2026-05-07 — Migrar Satin de s1ddok (repo eliminado) a Hi-Rez/Satin (repo oficial activo)
**Razón:** s1ddok/Satin ya no existe (HTTP 404). Hi-Rez/Satin es el repo oficial y mantenido, con iOS 17+ support y SPM. Requirió cambiar swift-tools-version a 6.0, refactorizar GeometryData->VertexBufferAttribute y BasicMaterial->BasicColorMaterial. API Object es compatible (expandida).
**Alternativas descartadas:**
- Mantener s1ddok/Satin (imposible, repo eliminado)
- Reescribir Satin manualmente desde cero (demasiado esfuerzo)
- Usar Metal directamente sin Satin (pérdida de abstracciones valiosas)
**Impacto:** high


## 2026-05-07 — AppForge Studio será open-source con monetización por publicidad no intrusiva + modelo open-core
**Razón:** Ningún competidor (Shapr3D $299/año, Fusion 360 $545/año, Nomad Sculpt $14.99) unifica paint 3D + sculpt + CAD paramétrico + animación en iPad. La ventaja diferencial de AppForge es ser la única app iOS que integra todo esto. El modelo open-source con ads recompensados ($10-15 eCPM) + suscripción premium sin ads ($4.99/mes) permite competir gratis contra software caro mientras se genera revenue sostenible, siguiendo el modelo Blender Foundation pero adaptado a iPad.
**Alternativas descartadas:**
- SaaS/web-only (pierde ventaja iPad + Apple Pencil)
- Pago único tipo Nomad ($14.99 — deja mucho dinero en mesa)
- Suscripción pura tipo Shapr3D ($299/año — contradictory al ser open-source)
**Impacto:** high


## 2026-05-11 — Plan de Fases 8-10: orden de implementacion
**Razón:** Primero Apple Pencil (diferencia competitiva contra Shapr3D), luego OCCTSwift + extrusion (kernel CAD real), luego timeline, gestos, constraints auto, benchmark, boolean GPU, assemblies. Cada fase produce codigo verificable y tests.
**Alternativas descartadas:**
- Empezar con OCCTSwift (mas riesgoso, sin UX visible de retorno)
- Saltar benchmark (necesario para validar contra Shapr3D)
**Impacto:** high


## 2026-05-11 — Restauracion masiva de backup_sources/ a Sources/
**Razón:** Las 5 subcarpetas de Sources/ estan vacias. Todo el codigo real (CAD, animacion, shaders Metal, UI, export, escultura) esta en backup_sources/ en un unico directorio plano. Es la causa raiz de por que el proyecto solo tiene 1 archivo Swift activo en lugar de 48+.
**Alternativas descartadas:**
- Dejarlo asi y escribir nuevo codigo (perderia 67 archivos existentes)
- Restaurar manualmente archivo por archivo (ineficiente, 67 operaciones)
**Impacto:** high

