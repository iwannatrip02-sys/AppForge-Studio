# Auditoría CSG — Fase 3, Tarea 1 (F3.T1)

> Fecha: 2026-06-10 | Ejecutor: NEXUS | Rama: w4/cad-anim
> Alcance: Solo lectura. Archivos auditados: 7 archivos CSG + 1 test.

---

## 1. Archivos Auditados

| Archivo | Líneas | Estado |
|---------|--------|--------|
| `Sources/CSG/Shape.swift` | 6 | Typealias vacío |
| `Sources/LegacyCSG/BSPNode.swift` | 201 | BSP tree legacy — tiene bug de compilación |
| `Sources/LegacyCSG/CSGOperation.swift` | 38 | Operaciones legacy — lógica de BSP parcialmente incorrecta |
| `Sources/LegacyCSG/Polygon3D.swift` | 52 | Conversión mesh↔polígonos — OK |
| `Sources/Engines/CSGEngine.swift` | 204 | BSP engine alternativo — BSPNode duplicado, intersect bug |
| `Features/CADMode/Tools/BooleanEngine.swift` | 125 | Engine de producción — delega a OCCTSwift |
| `Sources/Services/OCCTBridge.swift` | 91 | Bridge OCCT→Mesh — OK |
| `Sources/Engines/OCCTEngine.swift` | 125 | Wrapper OCCT — OK |
| `Tests/CSGTests.swift` | 74 | Tests existentes — 7 tests, usan API que puede no compilar |

---

## 2. Hallazgos Críticos

### 2.1 DOS implementaciones de BSPNode — Conflicto de nombres (CRÍTICO)

**Archivos:** `Sources/LegacyCSG/BSPNode.swift:4` y `Sources/Engines/CSGEngine.swift:7`

Dos clases `BSPNode` distintas coexisten en el mismo módulo (AppForgeStudio):
- `LegacyCSG/BSPNode`: árbol basado en polígonos con plano (normal, d). Soporta clip, classify, splitPolygon.
- `Engines/CSGEngine`: clase interna con `plane`, `front`, `back`, `triangles` (array de tuplas de 3 SIMD3).

**Riesgo:** Ambigüedad de símbolo al compilar. Si el compilador resuelve una cuando se espera la otra, comportamiento indefinido o error de compilación.

**Recomendación:** Consolidar en una sola implementación. La de `LegacyCSG` es más completa (soporta polígonos arbitrarios), pero tiene bugs (ver 2.2).

---

### 2.2 BUG: `backPolys` no declarado en LegacyCSG/BSPNode.clip() (CRÍTICO — error de compilación)

**Archivo:** `Sources/LegacyCSG/BSPNode.swift:174`
```swift
case .back:
    if let b = back {
        backPolys.append(contentsOf: b.clip(p, keepFront: keepFront))
    } else if !keepFront {
        frontPolys.append(p)
    }
```

`backPolys` se usa en línea 174 pero **nunca se declara** en el scope del método. La función `clip()` solo declara `var frontPolys: [Polygon3D] = []` (línea 156). `backPolys` no existe. Esto es un **error de compilación** — el código legacy no compila.

**Fix sugerido:** La línea 174 debería ser `frontPolys.append(...)` o declarar `var backPolys` y fusionar al final. La intención parece ser acumular polígonos del lado "back" cuando `keepFront == false`.

---

### 2.3 BUG: Operación `.difference` en LegacyCSG/CSGOperation potencialmente incorrecta (ALTO)

**Archivo:** `Sources/LegacyCSG/CSGOperation.swift:26-29`
```swift
case .difference:
    let clippedA = polysA.flatMap { treeB.clip($0, keepFront: true) }
    let clippedB = polysB.flatMap { treeA.clip($0, keepFront: true) }
    result = clippedA + clippedB
```

En CSG clásico con BSP trees:
- **A − B** = fragmentos de A en frente de B + fragmentos de B **detrás** de A (como "volumen negativo" que define el hueco).

El código actual usa `keepFront: true` para **ambos** A y B. Debería usar `keepFront: false` para B (o simplemente descartar B del resultado, como hace `CSGEngine.subtract()` que correctamente solo devuelve `clipTriangles(A, by: bspB)`).

**Comparación con CSGEngine.subtract():** La versión de `Sources/Engines/CSGEngine.swift:183-186` hace `return trianglesToMesh(clipTriangles(trisA, by: bspB), device: device)` — correcto, solo mantiene A fuera de B.

---

### 2.4 BUG: Operación `.intersect` en CSGEngine retiene geometría exterior (ALTO)

**Archivo:** `Sources/Engines/CSGEngine.swift:189-196`
```swift
func intersect(_ a: Mesh, _ b: Mesh, device: MTLDevice) -> Mesh {
    let trisA = meshToTriangles(a); let trisB = meshToTriangles(b)
    guard let bspB = buildBSP(trisB) else { return Mesh() }
    let clippedA = clipTriangles(trisA, by: bspB)
    guard let bspA = buildBSP(clippedA) else { return Mesh() }
    let clippedB = clipTriangles(trisB, by: bspA)
    return trianglesToMesh(clippedA + clippedB, device: device)
}
```

`clipTriangles` retiene solo fragmentos en **FRENTE** (exterior) del BSP tree. Para intersección se necesitan fragmentos en **ATRÁS** (interior). El código construye BSP de clippedA (que son fragmentos de A FUERA de B), luego clipa B contra ese BSP, reteniendo fragmentos de B FUERA de A. Esto produce el complemento de la intersección, no la intersección.

**Fix sugerido:** Para intersección: `clipTriangles(trisA, by: bspB, keepFront: false)` (mantener interior) + `clipTriangles(trisB, by: bspA, keepFront: false)`. Requiere modificar `clipTriangles` para aceptar un parámetro `keepFront`.

---

### 2.5 BUG: Operación `.union` en LegacyCSG/CSGOperation usa keepFront opuesto para B (MEDIO)

**Archivo:** `Sources/LegacyCSG/CSGOperation.swift:22-25`
```swift
case .union:
    let clippedA = polysA.flatMap { treeB.clip($0, keepFront: true) }
    let clippedB = polysB.flatMap { treeA.clip($0, keepFront: false) }
    result = clippedA + clippedB
```

Para unión A∪B: fragmentos de A frente a B (keepFront:true ✓) + fragmentos de B frente a A (debería ser `keepFront: true`, pero usa `keepFront: false`). Esto descarta partes de B que están fuera de A y conserva partes de B dentro de A, resultando en geometría incorrecta para unión de objetos no superpuestos completamente.

---

### 2.6 `Sources/CSG/Shape.swift` es solo un typealias — no hay CSG nativo en Sources/CSG (INFO)

**Archivo:** `Sources/CSG/Shape.swift`
```swift
typealias CADShape = OCCTSwift.Shape
```

El plan maestro asumía que `Sources/CSG/` contenía el motor BSP nativo (Shape.swift, BSPNode.swift, CSGOperation.swift, Polygon3D.swift). La realidad:
- `Sources/CSG/Shape.swift` → typealias vacío
- Los archivos reales de BSP están en `Sources/LegacyCSG/` (3 archivos)
- El BSP engine "activo" está en `Sources/Engines/CSGEngine.swift` (con su propio BSPNode duplicado)

El motor de producción real para booleanas es **OCCTSwift** (vía `OCCTEngine.shared` → `BooleanEngine`), no el BSP tree nativo.

---

## 3. Inventario de Implementaciones CSG

| Capa | Ubicación | Usa | Estado | Usado por |
|------|-----------|-----|--------|-----------|
| **OCCTSwift** (B-rep) | Paquete externo | Parasolid/OCCT kernel | ✅ Funcional | BooleanEngine, OCCTEngine, CADModeView |
| **CSGEngine** (BSP nativo) | `Sources/Engines/CSGEngine.swift` | BSP tree propio | ⚠️ intersect bug | No usado en UI actual |
| **LegacyCSG** (BSP legacy) | `Sources/LegacyCSG/` | BSP tree legacy | ❌ No compila (backPolys) | No usado en UI actual |
| **BooleanEngine** (wrapper) | `Features/CADMode/Tools/BooleanEngine.swift` | OCCTSwift (fallback: concat vértices) | ✅ Funcional | CADModeView |

**Conclusión:** Hay **3 motores CSG** (OCCTSwift, CSGEngine, LegacyCSG) y solo 1 funciona correctamente (OCCTSwift). Los 2 motores BSP nativos tienen bugs y no se usan en producción.

---

## 4. Análisis de Cobertura de Tests

**Archivo:** `Tests/CSGTests.swift` — 7 tests

| Test | ¿Compila? | Hallazgo |
|------|-----------|----------|
| `testBoxPrimitiveCreates12Triangles` | ⚠️ Incierto | Usa `Shape.box()` → `OCCTSwift.Shape.box()`. El test usa `.mesh.indices`/`.mesh.vertices` como propiedad. OCCTBridge usa `.mesh(...)` como método. Puede no compilar si OCCTSwift no exporta `.mesh` como propiedad. |
| `testCylinderPrimitiveHasCorrectStructure` | ⚠️ Incierto | Misma preocupación de API. |
| `testUnionOfTwoBoxesProducesValidMesh` | ⚠️ Incierto | Depende de `.union()` en Shape. |
| `testDifferenceOfTwoBoxesProducesValidMesh` | ⚠️ Incierto | Depende de `.difference()` en Shape. |
| `testIntersectionOfTwoBoxesProducesValidMesh` | ⚠️ Incierto | Depende de `.intersection()` en Shape. |
| `testMeshToPolygonsAndBackPreservesCount` | ⚠️ Incierto | Usa `Polygon3D.fromMesh()` y `Polygon3D.toMesh()`. API existe. OK. |
| `testUnionReducesTriangleCount` | ⚠️ Incierto | Depende de `.union()`. |
| `testNonOverlappingUnionPreservesGeometry` | ⚠️ Incierto | Depende de `.union()`. |

**Problema raíz:** Los tests usan `Shape` como si tuviera `.mesh` (propiedad) y métodos `.union()`, `.difference()`, `.intersection()`. El typealias `CADShape = OCCTSwift.Shape` apunta al tipo de OCCTSwift. Si OCCTSwift exporta estos métodos, los tests compilan. Si no, están rotos.

**Dato clave:** CI nunca ejecuta `xcodebuild test` (solo build). Por tanto, estos tests **nunca se han ejecutado en CI**. Su estado de compilación es desconocido.

---

## 5. Dependencia de OCCTSwift

Toda la funcionalidad CAD productiva (BooleanEngine, OCCTEngine, primitivas, export STEP/STL) depende de `gsdali/OCCTSwift` (xcframework pre-compilado, ~190 MB, iOS arm64 only).

**Riesgo:** Si OCCTSwift desaparece o rompe compatibilidad, el 100% del CAD productivo se pierde. Los backups BSP nativos (CSGEngine, LegacyCSG) tienen bugs y no son sustitutos viables sin correcciones.

---

## 6. Resumen de Gaps

| ID | Gap | Severidad | Archivo(s) |
|----|-----|-----------|------------|
| GAP1 | BSPNode duplicado (2 clases en mismo módulo) | CRÍTICO | LegacyCSG/BSPNode + Engines/CSGEngine |
| GAP2 | `backPolys` no declarado — error de compilación | CRÍTICO | LegacyCSG/BSPNode.swift:174 |
| GAP3 | CSGOperation.difference produce resultado incorrecto | ALTO | LegacyCSG/CSGOperation.swift:26-29 |
| GAP4 | CSGEngine.intersect retiene exterior en vez de interior | ALTO | Engines/CSGEngine.swift:189-196 |
| GAP5 | CSGOperation.union usa keepFront opuesto para B | MEDIO | LegacyCSG/CSGOperation.swift:24 |
| GAP6 | Tests CSG posiblemente no compilan (API de Shape no verificada) | MEDIO | Tests/CSGTests.swift |
| GAP7 | 3 motores CSG coexisten, solo 1 funcional (OCCTSwift) | MEDIO | Arquitectura |
| GAP8 | Sin tests de CSGEngine (BSP nativo) | BAJO | Cobertura |
| GAP9 | Sin tests de LegacyCSG | BAJO | Cobertura |
| GAP10 | Dependencia total de OCCTSwift sin fallback nativo funcional | ALTO | Arquitectura |

---

## 7. Recomendaciones

1. **Eliminar `Sources/LegacyCSG/`** — no compila, tiene bugs, no se usa. Es deuda técnica pura.
2. **Renombrar BSPNode en CSGEngine** a `CSGBSPNode` para evitar conflicto con LegacyCSG.
3. **Corregir CSGEngine.intersect** — agregar parámetro `keepFront: Bool = true` a `clipTriangles`.
4. **Ejecutar `xcodebuild test`** en CI para verificar si CSGTests compila.
5. **Si OCCTSwift es frágil** (dependencia externa no mantenida), priorizar la corrección de CSGEngine como fallback nativo.
6. **Unificar en un solo motor CSG:** OCCTSwift para producción, CSGEngine corregido como fallback. LegacyCSG → eliminar.

---

## 8. Verificación de Símbolos

Todos los símbolos referenciados fueron verificados con `grep -rn` contra el código fuente real:

```
✅ BSPNode (LegacyCSG)        → Sources/LegacyCSG/BSPNode.swift:4
✅ BSPNode (CSGEngine interno) → Sources/Engines/CSGEngine.swift:7
✅ CSGOperation               → Sources/LegacyCSG/CSGOperation.swift:4
✅ Polygon3D                  → Sources/LegacyCSG/Polygon3D.swift:4
✅ CSGEngine                  → Sources/Engines/CSGEngine.swift:18
✅ BooleanEngine              → Features/CADMode/Tools/BooleanEngine.swift:6
✅ OCCTEngine                 → Sources/Engines/OCCTEngine.swift:8
✅ OCCTBridge                 → Sources/Services/OCCTBridge.swift:7
✅ CADHistoryTree             → Core/Managers/CADHistoryTree.swift:78
✅ Shape (typealias)          → Sources/CSG/Shape.swift:5
✅ Shape (OCCTSwift)          → Paquete externo (API: .box, .cylinder, .sphere, .torus, .cone, +, -, &)
```

---

*Documento generado como parte de F3.T1 del Plan Maestro AppForge.*
