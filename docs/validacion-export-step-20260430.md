# Validacion Export STEP - AppForge Studio
> 2026-04-30 07:00 UTC | Analisis de ExportService.swift

## Estado actual
ExportService.swift en `Core/Services/` tiene 4 funciones de exportacion:
- `exportToOBJ(model:, url:)` → usa buildMDLAsset + ModelIO export
- `exportToSTL(model:, url:)` → igual, exporta como stl
- `exportToUSDZ(model:, url:)` → igual, exporta como usdz
- `exportToSTEP(model:, url:)` → generacion manual AP214 con CARTESIAN_POINT + POLYLOOP

## Bug detectado (documentado en docs/estado-fase6-paso1.md)
Originalmente habia `for mesh in mesh.meshes` en lugar de `for mesh in model.meshes` en exportToSTEP.
Estado actual del codigo: revisado el contenido leido, la linea dice `for mesh in model.meshes` — el bug fue corregido.

## Validaciones faltantes
1. **Sin validacion de vertices unicos**: El STEP manual genera un CARTESIAN_POINT por cada vertice del mesh, incluidos duplicados. Model3D puede tener vertices duplicados (por normales/UV diferentes), generando STEP ineficiente.
2. **Sin validacion de triangulos**: `for i in stride(from:0, to:mesh.indices.count, by:3)` asume que todas las caras son triangulares. No hay chequeo de `mesh.primitiveType == .triangle`.
3. **Sin validacion de archivo resultante**: `exportToOBJ` y `exportToSTL` verifican `fileExists(atPath:)`, pero `exportToSTEP` no tiene post-validacion.
4. **Sin manejo de errores**: `exportToSTEP` no tiene do-catch ni validacion de escritura. Si el archivo no se escribe, retorna `true` igual.
5. **Sin uso de OCCTEngine**: `occtEngine` esta disponible como propiedad pero no se usa en exportToSTEP. OCCTSwift tiene export STEP nativo que seria mas robusto que la generacion manual.

## Formato STEP AP214
El STEP generado incluye:
- CARTESIAN_POINT para cada vertice
- POLYLOOP para cada cara (3 puntos por triangulo)
- MANIFOLD_SOLID_BREP como contenedor
- Fecha hardcodeada '2026-04-30' en FILE_NAME

## Recomendaciones
1. **Usar OCCTEngine para STEP**: Reemplazar generacion manual con `occtEngine.exportSTEP(model)` — sera mas robusto y soportara superficies NURBS.
2. **Agregar post-validacion**: Verificar fileExists y tamano del archivo (> 0 bytes).
3. **Desduplicar vertices**: Usar Set de SIMD3<Float> para eliminar duplicados en STEP manual (si se mantiene generacion manual).
4. **Validar primitive type**: Solo exportar si `mesh.primitiveType == .triangle`.
5. **Actualizar fecha**: Usar Date() en lugar de hardcode.
6. **Agregar soporte para mallas multiples**: El loop actual agrega todas las mallas al mismo MANIFOLD_SOLID_BREP sin separacion.

## Conclusión
ExportToSTEP funciona para casos simples (modelos con 1 malla triangular, pocos vertices). Para produccion se recomienda migrar a OCCTEngine.exportSTEP() que dara soporte CAD completo. No hay bugs activos de compilacion, pero si debilidades de robustez.
