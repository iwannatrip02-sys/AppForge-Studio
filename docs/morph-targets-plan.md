# Morph Targets — Plan de implementacion

## Arquitectura

### Datos nuevos:
1. `MorphTarget` struct en Core/Engines/:
   - id: UUID
   - name: String
   - offsets: [SIMD3<Float>] (delta posiciones, mismo count que vertices base)
   - weight: Float (0-1)

2. Extension a `Mesh`:
   - var morphTargets: [MorphTarget] = []
   - var baseVertices: [Vertex] (copia de vertices al crear morph target)
   - mutating func applyMorphs() — aplica weighted blend de morph targets sobre vertices

3. Extension a `AnimationClip`:
   - var morphFrames: [String: [Keyframe<Float>]] (nombre morph -> keyframes de peso)

4. `MorphEngine` struct:
   - static func applyAllMorphs(to mesh: inout Mesh, at time: Float, clip: AnimationClip)
   - static func createMorphTarget(from mesh: Mesh, name: String, deformedVertices: [Vertex]) -> MorphTarget

### Integracion con AnimationEngine:
- AnimationEngine.evaluate(at:) actual: aplica transform (pos/rot/scale) al modelo
- Extender: que tambien itere morphFrames del clip activo y aplique en meshes

### UI (AnimationModeView.swift):
- Panel "Morph Targets" con lista de targets + sliders de peso
- Boton "Capture current shape as morph"
- Timeline para animar pesos

## Archivos a modificar:
1. Core/Engines/Mesh.swift — agregar morphTargets + applyMorphs()
2. Core/Engines/AnimationEngine.swift — agregar morphFrames a AnimationClip + evaluacion morph
3. Core/Engines/AnimationEngine.swift — MorphTarget struct (o archivo nuevo)
4. Features/AnimationMode/AnimationModeView.swift — UI morph panel
5. Tests/AnimationPlaybackTests.swift — tests morph

## Nuevos archivos:
6. Core/Engines/MorphEngine.swift — engine dedicado a morph targets

## Criterio de exito:
- Model puede tener morph targets en sus meshes
- AnimationClip puede animar pesos morph en el tiempo
- AnimationEngine.evaluate(at:) aplica morph blend ademas de transform
- Sliders en UI permiten ajuste manual de pesos
