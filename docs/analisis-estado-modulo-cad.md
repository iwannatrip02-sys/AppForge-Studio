# Analisis del Modulo CAD — Estado funcional y alternativas Windows

> Fecha: 2026-05-11
> Proyecto: AppForge Studio (iOS)
> Modulo: CAD (Core/CSG/, Core/Engines/, Features/CADMode/)

---

## 1. Arquitectura actual del modulo CAD

### Archivos activos (0 referencias a OCCTSwift)

| Archivo | Ruta | Estado |
|---------|------|--------|
| Shape.swift | `Core/CSG/Shape.swift` | Stub nativo — 213 lineas, 7709 bytes |
| OCCTEngine.swift | `Core/Engines/OCCTEngine.swift` | Wrapper singleton — llama a Shape.* |
| BooleanEngine.swift | `Core/Engines/BooleanEngine.swift` | Motor booleano — usa OCCTEngine.shared |
| BooleanEngine.swift (CADMode) | `Features/CADMode/Tools/BooleanEngine.swift` | Copia del Core |
| ExportService.swift | `Core/Services/ExportService/ExportService.swift` | Exportacion STL/OBJ |
| ExportServiceSTEP.swift | `Features/ExportMode/ExportServiceSTEP.swift` | Exportacion STEP |
| Package.swift | Raiz | Dependencias: Satin 0.4.0 + simd |

### Archivos ausentes
- CADViewModel.swift — NO existe en el proyecto (glob 0 resultados)
- CADMode/Views/ — no hay vistas SwiftUI del modulo CAD

### Backups con OCCTSwift (no activos)
- `backup_sources/OCCTEngine.swift` — aun tiene `import OCCTSwift`
- `backup_sources_cadcore/BooleanEngine.swift` — aun tiene `import OCCTSwift`

---

## 2. Funcionalidad real de Shape.swift

### Lo que SI funciona (codigo real generando geometria):

```
✓ Shape.box(width:height:depth:) — 8 vertices, 12 triangulos, normales basicas
✓ Shape.cylinder(radius:height:) — ~24 segmentos, geometria tubular
✓ Shape.sphere(radius:) — generacion UV sphere
✓ Shape.torus(majorRadius:minorRadius:) — toroide
✓ Shape.cone(radius:height:) — cono truncado
✓ Shape.face(p0:p1:p2:) — triangulo individual (throws)
✓ Shape.shell(faces:) — cascara de caras
✓ Shape.solid(shell:) — solido desde cascara
✓ Operador + (union) — combina mallas (NO CSG real, solo merge de vertices/indices)
✓ Operador - (subtract) — igual que + (sin operacion booleana real)
✓ Operador & (intersect) — igual que + (sin operacion booleana real)
```

### Lo que son STUBS (codigo que devuelve self sin transformar):

```
✗ .filleted(radius:) → return self
✗ .chamfered(radius:) → return self
✗ .shelled(thickness:) → return self
✗ .extruded(direction:distance:) → return self
✗ .revolved(angle:) → return self
✗ .swept(along:) → return self
```

### Lo que falta para ser profesional:

1. **CSG booleano real** — `+`, `-`, `&` solo concatenan mallas. No hay interseccion volumetrica.
2. **Fillets/Chamfers** — operacion geometrica compleja (requiere calculo de curvas de interseccion)
3. **Extrusion/Revolucion/Sweep real** — generacion de malla desde perfil 2D
4. **Topologia** — no hay estructura B-Rep (caras, aristas, vertices con adyacencia)
5. **Tolerancias** — operaciones CSG requieren tolerancias numericas para interseccion de superficies
6. **ViewModel + UI** — no existe CADViewModel.swift, no hay vistas SwiftUI del CAD

---

## 3. Evaluacion de madurez profesional

### Flujo "principio a fin" ideal vs realidad:

| Paso | Requerido | Estado actual |
|------|-----------|---------------|
| Crear primitiva (box, cylinder) | Si | ✓ Funcional |
| Operacion booleana (union/difference) | Si | ✗ Stub (solo merge de mallas) |
| Fillet/Chamfer | Si | ✗ Stub (no opera) |
| Extrusion/Revolucion | Si | ✗ Stub (no opera) |
| Editar en viewport 3D | Si | ✗ No hay CADViewModel |
| Exportar STL/OBJ | Si | ✓ ExportService existe |
| Exportar STEP | Si | ✓ ExportServiceSTEP existe |
| Animacion CAD | Opcional | ✗ No implementado |

**Veredicto: NO es usable profesionalmente.** El modulo CAD tiene una base estructural correcta (desacoplamiento OCCTEngine → Shape → BooleanEngine) pero las operaciones CSG, fillets, extrusion y revolucion son stubs. El 100% de las operaciones CAD profesionales requieren logica real de interseccion geometrica.

---

## 4. Alternativas para compilar en Windows

### Opcion A: Swift nativo en Windows (recomendada para desarrollo)

Swift.org tiene instalador oficial para Windows (Swift 6.x). Compila codigo Swift puro (sin SwiftUI ni Metal).

**Que funciona en Windows Swift:**
- Codigo Swift estructural (structs, clases, protocolos)
- simd framework (Apple lo open-sourceo)
- Foundation (open-source)
- OSLog (no disponible en Windows)

**Que NO funciona en Windows:**
- SwiftUI (framework privativo Apple, no open-source)
- Metal (API GPU exclusiva de Apple, corre sobre IOKit)
- ModelIO, MetalKit, SceneKit (frameworks iOS/macOS)
- UIKit, Combine (privativos Apple)

**Flujo practico:**
- Windows: editar y compilar logica CAD (Shape.swift, OCCTEngine, BooleanEngine)
- macOS: compilar UI (SwiftUI + Metal) y hacer archive para App Store

### Opcion B: xtool (CI/CD multiplataforma)

**Que es:** Reemplazo de Xcode open-source que compila iOS desde Windows/Linux usando SwiftPM.

**Estado:** Activo en GitHub (xtool-org/xtool), licencia MIT.
**Limitacion conocida:** Metal shaders (MSL) no se compilan fuera de macOS — requieren el compilador `metal` de Xcode.

### Opcion C: EdgeCompiler (experimental)

**Que es:** Compilador iOS offline desde Windows, creado por un dev independiente.
**Riesgo:** Proyecto nuevo, sin comunidad grande, no verificado para Metal/SwiftUI.

### Opcion D: OCCT + Swift bridging

**OCCT en Windows:** OpenCASCADE se compila nativamente con MSVC + CMake.
**Problema:** OCCT es C++ puro. Para usarlo desde Swift se necesita:
- Un wrapping Objective-C++ (bridge)
- O compilar OCCT como DLL y llamarlo via C interop
- Esto es posible pero requiere ~2-3 semanas de trabajo de integracion

### Opcion E: Mac virtual / cloud

**MacStadium, MacinCloud, RentAMac** — servicio cloud para builds CI.
**VMware/VirtualBox** — macOS VM en Windows (legalmente gris, tecnicamente inestable).

---

## 5. Recomendacion

### Para desarrollo en Windows AHORA:

```
1. Instalar Swift 6.x desde swift.org/install/windows/
2. Compilar solo los modulos CAD puros (Shape.swift, OCCTEngine, BooleanEngine)
3. swift build --target AppForgeStudioCore (si se separa en target aparte)
4. NO intentar compilar SwiftUI/Metal en Windows — no es posible
```

### Para el modulo CAD (hoja de ruta):

```
Fase 1 (2-3 semanas): CSG real
  - Implementar interseccion de triangulos (Moller-Triangle)
  - Clipping de mallas contra planos
  - Construccion B-Rep desde malla triangulada

Fase 2 (3-4 semanas): Fillets/Chamfers
  - Deteccion de aristas vivas
  - Interpolacion de superficies de barrido circular

Fase 3 (2 semanas): Extrusion/Revolucion
  - Sweep de perfil 2D a lo largo de trayectoria
  - Revolucion alrededor de eje

Fase 4 (1-2 semanas): ViewModel + UI
  - Crear CADViewModel.swift con estado de sesion
  - Integrar con SatinRenderer (Metal viewport)
```

### Costo estimado de implementar CSG real:
- Alternativa A: implementar CSG propio ~4-6 semanas (gratis, solo tiempo)
- Alternativa B: integrar OCCT via C++ bridge ~2-3 semanas (OCCT es gratis, GPL)
- Alternativa C: usar Satin + Metal compute shaders ~3-4 semanas (mas performante en GPU)

---

## 6. Datos concretos del codigo

### Shape.swift — metricas reales
```
- 7709 bytes, 213 lineas
- 6 primitivas (box, cylinder, sphere, torus, cone, face)
- 2 constructores compuestos (shell, solid)
- 3 operadores (+, -, &) — todos stubs CSG
- 6 metodos de transformacion — todos stubs (return self)
- Mesh interno con vertices SIMD3<Float> + indices UInt32
```

### OCCTEngine.swift — metricas reales
```
- Singleton class
- 5 factories de primitivas (delegan a Shape.*)
- 3 operadores CSG (delegan a Shape.operators)
- 3 metodos de borde (fillet, chamfer, shell)
- 3 metodos de construccion (extrude, revolve, sweep)
- NO importa OCCTSwift — limpio
```

### Dependencia Satin
- Package.swift especifica `from: "0.4.0"` (no branch "main")
- Satin framework Swift para Metal — abstrae render pipeline 3D
- Version 0.4.0 parece ser la mas reciente estable
