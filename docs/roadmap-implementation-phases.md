# Roadmap de Implementación - Fases para Acercarse a la Competencia

## Resumen de Gaps Identificados
- **CAD**: 90% sin implementar. BooleanOp, extrude, revolve, loft son placeholders. Sin sketch 2D ni constraints.
- **Sculpt**: 70% sin implementar. Faltan DynTopo, simetría, capas, máscaras, pinceles alfa.
- **Paint**: 75% sin implementar. Faltan capas en textura, blending alfa, proyección UV, presión lápiz.
- **Export**: 100% placeholders. Exporta solo cuadrado hardcodeado. USDZ vacío, STEP/GLTF lanzan error.

## Fases de Implementación

### Fase 1: CAD - BooleanOp real con SDF (prioridad máxima)
**Objetivo**: Reemplazar `booleanOp()` placeholder con algoritmo SDF (Signed Distance Field) que compute unión, intersección y diferencia real entre dos mallas.
- Implementar SDF de malla usando voxelización (grid 64^3) y marching cubes.
- Crear `SDFEngine.swift` con funciones: `voxelize(mesh, gridSize)`, `combineSDFs(a, b, operation)`, `marchingCubes(sdf, gridSize) -> Mesh`.
- Actualizar `OCCTEngine.booleanOp()` para usar SDFEngine.
- Implementar `extrude(profile2D, height)` real: genera mesh extruyendo perfil 2D (lista de puntos) en altura.
- Implementar `revolve(profile2D, axis, angle)` real: revolve profile alrededor de eje.
- Implementar `loft(profiles, segments)` real: genera superficie entre múltiples perfiles.
- **Criterio de éxito**: `booleanOp()` entre dos cubos produce unión, intersección y diferencia. `extrude` de un círculo produce cilindro.

### Fase 2: CAD - Sketch 2D y Constraints paramétricos
**Objetivo**: Crear sistema de sketch 2D con constraints geométricos (distancia, ángulo, coincidencia, concentricidad).
- Crear `Sketch2D.swift`: entidad `SketchEntity` (punto, línea, arco, círculo), `Constraint` (enum: distance, angle, coincident, concentric, parallel, perpendicular).
- Crear `SketchConstraintSolver.swift`: resuelve constraints usando gradiente descendente o algoritmo de Newton-Raphson para 2D.
- Crear `SketchView.swift`: vista SwiftUI para dibujar sketch con gestos (touch para puntos, drag para líneas).
- Integrar con OCCTEngine: `extrude(sketch, height)` y `revolve(sketch, axis, angle)`.
- **Criterio de éxito**: Usuario puede dibujar rectángulo con constraints de 90°, extruirlo a cubo.

### Fase 3: Sculpt - DynTopo y Simetría
**Objetivo**: Agregar DynTopo (subdivisión adaptativa) y simetría por eje a SculptEngine.
- Crear `DynTopoEngine.swift`: subdivide triángulos donde la deformación supera un threshold (midpoint subdivision).
- Agregar simetría: en `SculptEngine.deform()`, duplicar deformación en eje X (o Y/Z) con mirror.
- Añadir capas de escultura: `SculptLayer` con parámetros (strength, blendMode), `SculptEngine.layers: [SculptLayer]`.
- **Criterio de éxito**: Al esculpir un lado, el otro se deforma simétricamente. DynTopo subdivide automáticamente zonas muy deformadas.

### Fase 4: Sculpt - Máscaras y Pinceles Alfa
**Objetivo**: Agregar máscaras por ángulo/inclinación y pinceles con textura alfa.
- Crear `SculptMask.swift`: `MaskType` (angle, position, cavity), función `evaluate(mask, vertex, mesh) -> Float` (peso 0-1).
- En `SculptEngine.deform()`, multiplicar fuerza por peso de máscara.
- Agregar pinceles alfa: `BrushTexture` con imagen (textura 2D), proyectar valor alfa en UV del mesh durante stroke.
- **Criterio de éxito**: Máscara por ángulo oculta vértices mirando hacia abajo. Pincel alfa deja marca con forma de la textura.

### Fase 5: Paint - Capas en Textura y Blending
**Objetivo**: Reemplazar stroke en malla por pintura en textura UV con capas.
- Crear `PaintLayerManager.swift`: maneja array de `PaintLayer` (cada uno con `renderTarget: MTLTexture`, `opacity`, `blendMode`).
- Modificar `PaintRenderer.generateStrokeMesh()` para pintar en textura usando `MTLRenderPassDescriptor` con blending.
- Implementar blending modes: normal, multiply, screen, overlay, add.
- **Criterio de éxito**: Usuario pinta en vista 3D y el color se aplica a textura UV. Capas se combinan con blending.

### Fase 6: Paint - Proyección UV y Presión Lápiz
**Objetivo**: Proyectar stroke en UV correctamente y soportar Apple Pencil pressure.
- Calcular coordenadas UV del punto de impacto en malla (intersección rayo-triángulo + barycentric).
- En `PaintViewController.swift`, usar `touch.coalescedTouches` para obtener fuerza.
- Modificar stroke para variar tamaño/opacidad con presión.
- **Criterio de éxito**: Pincel sigue contornos UV. Presión fuerte = trazo más grueso.

### Fase 7: Export - Geometría Real OBJ/STL/USDZ
**Objetivo**: Reemplazar placeholders con exportación real de geometría.
- En `ExportService.swift`, implementar: `exportOBJ(vertices, normals, uvs, indices) -> Data` y `exportSTL(vertices, indices) -> Data`.
- Para USDZ: usar `MDLAsset` con `MDLMesh` creado desde vertices/indices.
- Para STEP/GLTF: llamar a librería externa (por ahora lanzar error con mensaje claro).
- **Criterio de éxito**: Exportar cubo a OBJ produce archivo válido con 12 triángulos.

## Orden de Ejecución
1. Fase 1 (CAD BooleanOp + Extrude/Revolve/Loft) — base para CAD funcional.
2. Fase 2 (Sketch 2D + Constraints) — dependiente de Fase 1 para extruir sketches.
3. Fase 3 (Sculpt DynTopo + Simetría + Capas) — independiente.
4. Fase 4 (Sculpt Máscaras + Pinceles Alfa) — dependiente de Fase 3.
5. Fase 5 (Paint Capas en Textura) — independiente.
6. Fase 6 (Paint Proyección UV + Presión) — dependiente de Fase 5.
7. Fase 7 (Export real) — independiente.

## Notas
- Las fases independentes (3, 5, 7) pueden ejecutarse en paralelo.
- Cada fase produce archivos verificables.
- Se actualizará BRAIN.md, TODO.md y DECISIONS.md al completar cada fase.