# Decision Log
> Append-only. Cada entrada marca cambios de rumbo, arquitectura o prioridad.

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

## 2026-05-01 — Animacion conectada y funcional
**Decision:** Completar conexion AnimationEngine + SatinRenderer con deltaTime real (CACurrentMediaTime)
**Motivo:** La animacion por keyframes existia en AnimationEngine pero no se aplicaba al render loop
**Impacto:** Fase 4 de animacion completa. SatinRenderer.updateAnimation() evalua transforms y los aplica a scene3D.models en cada frame via render(in:)

---

## 2026-05-01 — Analisis competitivo completado
**Decision:** Documentar ventaja competitiva vs Shapr3D ($299/ano) en docs/analisis-competitivo-shapr3d-2026-05-01.md
**Hallazgo clave:** AppForge Studio es la unica app iOS nativa que combina pintura 3D + escultura + CAD parametrico + animacion + exportacion profesional en un solo producto
  
---  
  
## 2026-05-04 -- OSLog + manejo de errores en 3 modulos core  
**Decision:** Agregar OSLog y manejo de errores a SceneManager, AnimationEngine y ExportService.  
**Impacto:** Fase 0 Dia 1 completado. Proximo: escanear todos los .swift para consistencia OSLog. 

## 2026-05-11 — Prioridad inmediata: hacer que la app compile (Fase 1)
**Razón:** El proyecto tiene 47 engines funcionales y 7 Features modes pero está desensamblado - archivos clave están en backup_sources/ en vez de Sources/AppForgeStudio/. Sin compilación no podemos probar nada. Prioridad #1 es ensamblar correctamente.
**Impacto:** high


## 2026-05-11 — Eliminar dependencia OCCTSwift y reemplazar con Shape.swift nativo
**Razón:** OCCTSwift (repositorio occt/occtswift.git) no existe publicamente en GitHub. Los 3 archivos activos que importan OCCTSwift (OCCTEngine, BooleanEngine x2) usan Shape/operadores CSG que ahora tenemos como stub nativo en Core/CSG/Shape.swift con primitivas box, cylinder, sphere, torus, cone y CSG (+,-,&) basado en meshes.
**Alternativas descartadas:**
- Buscar OCCTSwift en otro proveedor o mirror — consume tiempo y el codigo actual solo necesita Shape stub, no OCCT real
- Instalar OCCT mediante CocoaPods/Carthage — sobreingenieria para operaciones CSG basicas que se implementan con Satin/Metal
**Impacto:** high


## 2026-05-12 — Modulo CAD no es usable profesionalmente — requiere CSG real y vistas SwiftUI
**Razón:** Shape.swift tiene primitivas funcionales pero CSG booleano (+/-/&) son identity stubs, exportSTEP() no existe, y no hay CADViewModel/SwiftUI conectado. Solo ~30% del modulo es funcional. Para compilar en Windows, xtool desde WSL2 es la mejor opcion. Se documenta en docs/analisis-estado-modulo-cad.md
**Impacto:** high


## 2026-05-12 — Implementar CSG booleano real con BSP tree nativo en Shape.swift en lugar de OCCT o Satin
**Razón:** Shape.swift actual tiene union/difference/intersection como identity ops. BSP tree CSG es el algoritmo clasico, liviano, sin dependencias externas. Output es Mesh nativo que Satin puede renderizar.
**Alternativas descartadas:**
- OCCTSwift — elimino del proyecto, no existe en disco
- Satin/Metal CSG — muy complejo para el MVP
- ScadModel — no es CSG booleano
**Impacto:** high


## 2026-05-12 — Los 3 items del TODO ya estaban implementados pero marcados pendientes
**Razón:** ExportServiceTests.swift (testExportToSTEP), AnimationEngineTests.swift (7 tests), y AnimationPlaybackTests.swift (playback lifecycle) existen en disco. El TODO estaba desactualizado. Se actualizaron 14 items a Completados.
**Alternativas descartadas:**
- Crear tests nuevos innecesarios
**Impacto:** medium

