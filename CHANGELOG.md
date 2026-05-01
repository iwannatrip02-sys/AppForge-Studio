# Changelog - AppForge Studio

## 2026-04-30 07:30 UTC - Validacion Export STEP

### Acciones
- Auditado ExportService.exportToSTEP() en Core/Services/ExportService.swift (~76 lineas)
- Verificado bug previo corregido: `for mesh in model.meshes` (antes era `for mesh in mesh.meshes`)
- Evaluado formato STEP AP214 generado: CARTESIAN_POINT + POLYLOOP + MANIFOLD_SOLID_BREP

### 5 Debilidades Detectadas
1. Sin deduplicacion de vertices: cada vertice genera CARTESIAN_POINT, incluidos duplicados por normales/UV
2. Sin chequeo de primitiveType: asume todas las caras son triangulares sin validar `mesh.primitiveType == .triangle`
3. Sin post-validacion de archivo: OBJ/STL verifican `fileExists(atPath:)`, STEP carece de esta validacion
4. Sin manejo de errores: retorna `true` aunque la escritura del archivo falle
5. Sin uso de OCCTEngine: `occtEngine` disponible como propiedad pero no usado; generacion manual menos robusta que OCCTSwift nativo

### Recomendaciones documentadas
- Migrar a OCCTEngine.exportSTEP() para soporte CAD completo (NURBS, B-Rep)
- Agregar post-validacion de fileExists + tamano > 0 bytes
- Desduplicar vertices con Set de SIMD3<Float> si se mantiene generacion manual
- Validar primitiveType antes de exportar
- Usar Date() en lugar de fecha hardcodeada '2026-04-30'

### Archivos
- Creado: docs/validacion-export-step-20260430.md (analisis completo)
- Actualizado: BRAIN.md, ARCHITECTURE.md (documentacion canonica)

### Estado
- exportToSTEP funcional para casos simples (1 malla triangular, pocos vertices)
- Sin bugs activos de compilacion; debilidades de robustez documentadas
- Pendiente: migracion a OCCTEngine.exportSTEP() para produccion

## 2026-04-29 21:50 UTC - Correcciones post-Fase 4 + Integracion AnimationView

### Acciones
- Verificado ExportService.swift (97 lineas) con buildMDLAsset y meshToMDL implementados
- Verificado ExportViewModel.swift (112 lineas) con exportModel() conectado a ExportService real
- Integrado AnimationView en navegacion principal como 5to modo (Animation)
- Agregado case animation = "Animation" a AppState.AppMode enum
- Agregado case .animation al switch en AppForgeStudioApp.swift
- Limpiados archivos temporales __temp_*.txt (ya eliminados)

### Estado
- Fase 4 completa: animacion keyframes + exportacion real + modo Animation navegable
- Pendiente: implementar exportTo*() real en ExportService si es necesario

## 2026-04-27 23:57 UTC - Archivo de Documentos Obsoletos

### Acciones
- **Archivados 3 archivos .md obsoletos** en archive/:
  - plan_desarrollo.md (contenido duplicado/desactualizado vs documentacion real)
  - PLAN_ESTRATEGICO.md (informacion de negocio desactualizada, preservada en archive/)
  - STRUCTURE_PLAN.md (plan de construccion redundante, los archivos ya existen)
- **Corregido GOTCHI.md**: Resources/Shaders/ no existe como carpeta, corregido a nota aclaratoria
- **Raiz del proyecto reducida** a 6 documentos esenciales

### Resultado
- Proyecto listo para continuar con Fase 4 (Animacion + Subdivision)
- Documentacion historica preservada en archive/

## 2026-04-27 23:53 UTC - Limpieza Completa de Documentacion

### Acciones
- **Archivados 21 archivos .md** obsoletos en archive/documentacion_sesiones/
- **Eliminado Shaders.metal duplicado** en ios-app/Sources/ (identico al de Core/Managers/)
- **Raiz del proyecto reducida** a 8 documentos esenciales
- **Creado CIERRE_LIMPIEZA_2026-04-27.md** con resumen completo

### Resultado
- Proyecto listo para continuar desarrollo sin ruido documental
- Documentacion historica preservada en archive/

## 2026-04-27 23:45 UTC - Auditoria y Actualizacion de Documentacion

### Documentacion Actualizada
- **ESTADO_ACTUAL.md**: Corregido — Fase 3 marcada como COMPLETA (no 'en progreso'), anadidas fases pendientes reales (Fase 4, CAD Tools UI, HybridMode)
- **DOCUMENTACION_ACTUALIZADA_2026-04-27.md**: Creado diagnostico completo con hallazgos, problemas de estructura y recomendaciones
- **CHANGELOG.md**: Anadida entrada de hoy con cambios realizados

### Hallazgos de Auditoria
- **CADMode/Tools/** NO esta vacio: 5 engines implementados (BevelEngine, BooleanEngine, ExtrusionEngine, LoopCutEngine, MeasureEngine)
- **SatinRenderer.swift** existe en la estructura real
- **ExportView** tiene UI funcional con ExportViewModel
- **SculptMode/Brushes/** contiene solo BrushEngine.swift (deformers en Sculpting/Deformers/)
- ~20 archivos .md de sesiones anteriores en raiz del proyecto (candidatos a archivo/limpieza)
- Duplicacion de Shaders.metal en 2 ubicaciones

## 2026-04-27 18:32 UTC - Actualizacion Mayor de Documentacion

### Documentacion Creada/Actualizada
- **GOTCHI.md**: Actualizado con arquitectura real del proyecto, estado por fase, y archivos completos
- **ARCHITECTURE.md**: Creado por primera vez con arquitectura por capas, flujo de datos y decisiones tecnicas
- **CHANGELOG.md**: Creado para tracking de cambios
- **ESTADO_ACTUAL.md**: Actualizado con fases reales completadas vs pendientes

### Correcciones en Documentacion vs Codigo Real
- SatinRenderer existe en AppForgeStudio/ (no en Core/)
- CADMode/Tools/ contiene 5 engines (no esta vacio)
- ExportMode tiene ExportView con UI funcional
- HybridMode tiene estructura basica pero sin logica completa