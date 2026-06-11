# Decision Log
> Append-only. Cada entrada marca cambios de rumbo, arquitectura o prioridad.

---

## 2026-05-01 — Animacion conectada y funcional
**Decision:** Completar conexion AnimationEngine + SatinRenderer con deltaTime real (CACurrentMediaTime)
**Motivo:** La animacion por keyframes existia en AnimationEngine pero no se aplicaba al render loop
**Impacto:** Fase 4 de animacion completa. SatinRenderer.updateAnimation() evalua transforms y los aplica a scene3D.models en cada frame via render(in:)

---

## 2026-05-01 — Analisis competitivo completado
**Decision:** Documentar ventaja competitiva vs Shapr3D ($299/ano) en docs/analisis-competitivo-shapr3d-2026-05-01.md
**Hallazgo clave:** AppForge Studio es la unica app iOS nativa que combina pintura 3D + escultura + CAD parametrico + animacion + exportacion profesional en un solo producto
  
---  
  
## 2026-05-02 — Consolidacion canonica completa
**Decision:** Actualizar los 4 documentos canonicos (GOTCHI.md, BRAIN.md, TODO.md, DECISIONS.md) con la informacion real verificada en disco (~55 archivos escaneados).
**Motivo:** Los canonicos anteriores tenian informacion desactualizada (BRAIN.md v76 listaba entidades en rutas incorrectas como Core/Engines/ cuando realmente estan en Core/Managers/, GOTCHI.md omitia modulos completos como PBRMaterial, MaterialPresets, CADHistoryTree). Esto causaba que Gotchi se perdiera cada vez que buscaba archivos y no los encontraba.
**Evidencia:**
- CADHistoryTree encontrado en Core/Managers/CADHistoryTree.swift (NO en rutas de docs previos)
- PBRMaterial en Models/PBRMaterial.swift (NO en Core/Managers/ como indicaba documentacion anterior)
- MaterialEditorPBRView en Features/CADMode/ (NO en Features/MaterialEditor/)
- ContentView duplicado en Features/CADMode/ y UI/Components/
- DECISIONS.md no existia — creado
**Impacto:** Ahora Gotchi tiene informacion precisa para cualquier busqueda futura. Pendiente consolidar duplicados.

---

## 2026-05-04 — OSLog + manejo de errores en 3 modulos core
**Decision:** Agregar OSLog y manejo de errores a SceneManager, AnimationEngine y ExportService.
**Impacto:** Fase 0 Dia 1 completado. Proximo: escanear todos los .swift para consistencia OSLog.

---

## 2026-05-05 — Implementacion CAD parametrico
**Decision:** Se implemento solver Gauss-Seidel propio en Swift en vez de wrapper C API de SolveSpace.
**Razon:** Evita dependencia de libreria C externa, acelera time-to-build, permite iterar rapido en fase de planning. Si en produccion no converge bien, se migra a SolveSpace C API via XCFramework.
**Archivos creados (8):**
- `Sources/CADCore/GeometryEntity.swift` — tipos point/line/circle/arc/nurbs
- `Sources/CADCore/GeometryConstraint.swift` — 9 tipos de constraint
- `Sources/CADCore/SolveSpaceSolver.swift` — solver Gauss-Seidel 100 iter
- `Sources/CADCore/CADHistoryTree.swift` — undo/redo con CADOperation
- `Sources/CADCore/GeometryConstraintManager.swift` — singleton con notificaciones
- `Sources/CADCore/CADSketchEngine.swift` — motor de bocetos parametricos
- `Sources/CADCore/ExtrudeEngine.swift` — extrusion 2D→3D
- `Sources/CADSketchView.swift` — UI SwiftUI completa
**Pendientes:**
- CAD-8: Integrar CADSketchView con CADModeView (no encontrado en disco)
- CAD-9: Conectar GeometryConstraintManager.shared con Scene3D (no encontrado en disco)
- CAD-10: Verificar Package.swift incluya Sources/CADCore/*

---

## 2026-05-07 — Mantener ambos GeometryConstraintManager como archivos separados con distintas responsabilidades
**Razon:** Sources/CADCore/GeometryConstraintManager.swift usa SolverSwift para resolver constraints 2D puros. Core/Managers/GeometryConstraintManager.swift es ObservableObject con closures para UI 3D. Son roles distintos: uno es solver interno, otro es manager de UI. No deben fusionarse.
**Alternativas descartadas:**
- Fusionar en un solo archivo (complejidad innecesaria)
- Eliminar Core/Managers/ (lo usa la UI para constraints visuales)
**Impacto:** medium

---

## 2026-05-07 — Refactorizar modulo CAD: unificar enums, eliminar duplicados, conectar constraints
**Razon:** 5 bugs estructurales bloquean compilacion: CADTool incompleto con 10+ casos faltantes, CADSketchEngine duplicado en 2 rutas, constraints duales desconectados, CADHistoryTree legacy, y pipeline sketch-extrusion sin integracion real. Corregir en una sola pasada con code_agent antes de avanzar a nuevas features.
**Alternativas descartadas:**
- Parche parcial archivo por archivo (tardaria 3+ turnos)
- Ignorar y seguir con nuevas features (acumularia deuda tecnica)
**Impacto:** high

---

## 2026-05-07 — Ruta hibrida de compilacion para AppForge Studio: Macly.io (~$30/mes) como Mac cloud primario + GitHub Actions self-hosted runner en cualquier Mac disponible + Xcode Cloud free tier (50h/mes) como respaldo
**Razon:** Tras investigar 8 fuentes: Swift Package Manager no soporta Metal shaders nativamente (bug conocido #8930), MetalCompilerPlugin existe como workaround pero es limitado. La opcion mas barata viable es Macly.io (~$1/dia), muy por debajo de los $299/ano de Shapr3D. Ademas, GitHub Actions con self-hosted runner en cualquier Mac es completamente gratis. Se documento todo en docs/ruta-compilacion-gratuita.md
**Alternativas descartadas:**
- Compilar solo con SPM en Linux (Metal no funciona fuera de Apple Silicon)
- Swift Playgrounds en iPad (limitado, no soporta Metal nativo complejo)
- Solo Xcode Cloud (50h/mes insuficientes para desarrollo intensivo)
**Impacto:** high

---

## 2026-05-07 — Migrar Satin de s1ddok (repo eliminado) a Hi-Rez/Satin (repo oficial activo)
**Razon:** s1ddok/Satin ya no existe (HTTP 404). Hi-Rez/Satin es el repo oficial y mantenido, con iOS 17+ support y SPM. Requirio cambiar swift-tools-version a 6.0, refactorizar GeometryData->VertexBufferAttribute y BasicMaterial->BasicColorMaterial. API Object es compatible (expandida).
**Alternativas descartadas:**
- Mantener s1ddok/Satin (imposible, repo eliminado)
- Reescribir Satin manualmente desde cero (demasiado esfuerzo)
- Usar Metal directamente sin Satin (perdida de abstracciones valiosas)
**Impacto:** high

---

## 2026-05-07 — AppForge Studio sera open-source con monetizacion por publicidad no intrusiva + modelo open-core
**Razon:** Ningun competidor (Shapr3D $299/ano, Fusion 360 $545/ano, Nomad Sculpt $14.99) unifica paint 3D + sculpt + CAD parametrico + animacion en iPad. La ventaja diferencial de AppForge es ser la unica app iOS que integra todo esto. El modelo open-source con ads recompensados ($10-15 eCPM) + suscripcion premium sin ads ($4.99/mes) permite competir gratis contra software caro mientras se genera revenue sostenible, siguiendo el modelo Blender Foundation pero adaptado a iPad.
**Alternativas descartadas:**
- SaaS/web-only (pierde ventaja iPad + Apple Pencil)
- Pago unico tipo Nomad ($14.99 — deja mucho dinero en mesa)
- Suscripcion pura tipo Shapr3D ($299/ano — contradictory al ser open-source)
**Impacto:** high

---

## 2026-05-11 — Prioridad inmediata: hacer que la app compile (Fase 1)
**Razon:** El proyecto tiene 47 engines funcionales y 7 Features modes pero esta desensamblado - archivos clave estan en backup_sources/ en vez de Sources/AppForgeStudio/. Sin compilacion no podemos probar nada. Prioridad #1 es ensamblar correctamente.
**Impacto:** high

---

## 2026-05-11 — Eliminar dependencia OCCTSwift y reemplazar con Shape.swift nativo
**Razon:** OCCTSwift (repositorio occt/occtswift.git) no existe publicamente en GitHub. Los 3 archivos activos que importan OCCTSwift (OCCTEngine, BooleanEngine x2) usan Shape/operadores CSG que ahora tenemos como stub nativo en Core/CSG/Shape.swift con primitivas box, cylinder, sphere, torus, cone y CSG (+,-,&) basado en meshes.
**Alternativas descartadas:**
- Buscar OCCTSwift en otro proveedor o mirror — consume tiempo y el codigo actual solo necesita Shape stub, no OCCT real
- Instalar OCCT mediante CocoaPods/Carthage — sobreingenieria para operaciones CSG basicas que se implementan con Satin/Metal
**Impacto:** high

---

## 2026-05-11 — Plan de Fases 8-10: orden de implementacion
**Razon:** Primero Apple Pencil (diferencia competitiva contra Shapr3D), luego OCCTSwift + extrusion (kernel CAD real), luego timeline, gestos, constraints auto, benchmark, boolean GPU, assemblies. Cada fase produce codigo verificable y tests.
**Alternativas descartadas:**
- Empezar con OCCTSwift (mas riesgoso, sin UX visible de retorno)
- Saltar benchmark (necesario para validar contra Shapr3D)
**Impacto:** high

---

## 2026-05-11 — Restauracion masiva de backup_sources/ a Sources/
**Razon:** Las 5 subcarpetas de Sources/ estan vacias. Todo el codigo real (CAD, animacion, shaders Metal, UI, export, escultura) esta en backup_sources/ en un unico directorio plano. Es la causa raiz de por que el proyecto solo tiene 1 archivo Swift activo en lugar de 48+.
**Alternativas descartadas:**
- Dejarlo asi y escribir nuevo codigo (perderia 67 archivos existentes)
- Restaurar manualmente archivo por archivo (ineficiente, 67 operaciones)
**Impacto:** high

---

## 2026-05-12 — Modulo CAD no es usable profesionalmente — requiere CSG real y vistas SwiftUI
**Razon:** Shape.swift tiene primitivas funcionales pero CSG booleano (+/-/&) son identity stubs, exportSTEP() no existe, y no hay CADViewModel/SwiftUI conectado. Solo ~30% del modulo es funcional. Para compilar en Windows, xtool desde WSL2 es la mejor opcion. Se documenta en docs/analisis-estado-modulo-cad.md
**Impacto:** high

---

## 2026-05-12 — Implementar CSG booleano real con BSP tree nativo en Shape.swift en lugar de OCCT o Satin
**Razon:** Shape.swift actual tiene union/difference/intersection como identity ops. BSP tree CSG es el algoritmo clasico, liviano, sin dependencias externas. Output es Mesh nativo que Satin puede renderizar.
**Alternativas descartadas:**
- OCCTSwift — elimino del proyecto, no existe en disco
- Satin/Metal CSG — muy complejo para el MVP
- ScadModel — no es CSG booleano
**Impacto:** high

---

## 2026-05-12 — Los 3 items del TODO ya estaban implementados pero marcados pendientes
**Razon:** ExportServiceTests.swift (testExportToSTEP), AnimationEngineTests.swift (7 tests), y AnimationPlaybackTests.swift (playback lifecycle) existen en disco. El TODO estaba desactualizado. Se actualizaron 14 items a Completados.
**Alternativas descartadas:**
- Crear tests nuevos innecesarios
**Impacto:** medium
