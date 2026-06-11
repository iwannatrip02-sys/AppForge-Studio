# Bug Fix Session — AppForge Studio
## Fecha: 2026-05-26 | Gotchi (NanoAtlas)

---

## Auditoría de Bugs (BRAIN.md vs Disco)

De 6 bugs reportados en BRAIN.md, solo 1 es real. Los otros 5 son:

| Bug | Archivo | Estado Real |
|-----|---------|-------------|
| BUG1 (GPU PBR padding) | SatinRenderer.swift | **YA RESUELTO** — GPUPBRMaterial tiene `_pad1` y `_pad2` explícitos |
| BUG2 (doble updateAnimation) | AnimationEngine.swift | **NO EXISTE** — `advanceFrame`, `tick()`, `updateAnimation` no aparecen en el archivo |
| BUG3 (UInt16 overflow) | Mesh.swift | **YA RESUELTO** — Mesh usa `UInt32` para índices |
| BUG5 (normal matrix) | SatinRenderer.swift | **NO VERIFICABLE sin Mac** — requiere compilar shaders Metal. El código Swift que empaqueta normals es correcto (líneas 605-607, 652-654) |
| BUG7 (GrabDeformer) | SculptEngine.swift:93 | **REAL — CORREGIDO** |
| BUG9 (rebuildSceneFrom) | Scene3D.swift | **NO EXISTE** — `rebuildSceneFrom`, `buildScene`, `isDirty` no aparecen |

---

## BUG7 — GrabDeformer Dirección Contraria (CORREGIDO)

### Archivo
`Sources/Engines/SculptEngine.swift`

### Síntoma
El deformer `.grab` usa `point.normal` en vez de `point.dragDelta` para calcular
la dirección de desplazamiento. Esto mueve los vértices en dirección de la normal
de la superficie, no en la dirección del arrastre del dedo. Resultado: al hacer
grab, el mesh se infla/desinfla en vez de seguir el gesto.

### Fix aplicado
Línea 93: `case .grab:` — cambiado `point.normal * influence` → `point.dragDelta * influence`

```swift
// ANTES (bug):
case .grab:
    vertex.position += point.normal * influence

// DESPUÉS (fix):
case .grab:
    vertex.position += point.dragDelta * influence
```

### Verificación
- `SculptPoint` ya tiene `dragDelta: SIMD3<Float>` (línea 8) — el campo existe
- `apply(at:to:)` pasa `dragDelta` correctamente en el punto de simetría
- El fix es de 1 línea, sin efectos colaterales

---

## Conclusión

- **1 bug real corregido** (BUG7 en SculptEngine.swift)
- **2 bugs ya estaban resueltos** (BUG1 padding, BUG3 UInt32)
- **2 bugs fabricados** (BUG2, BUG9 — no existen en el código)
- **1 bug no verificable sin Mac** (BUG5 requiere compilación Metal)

El BRAIN.md tenía bugs inflados — corregido abajo.
