# AppForge Studio — TODO.md
> Updated: 2026-05-25 23:30 UTC
> Proyecto unificado: 130+ archivos Swift/Metal reales en Sources/ + Core/UI/ + Features/ + Tests/

## Foco actual
- Hacer que el proyecto compile en CI (GitHub Actions macOS)

## Pendientes
- [ ] Corregir error exit code 74 de xcodegen en CI (project.yml vs estructura real)
- [ ] Validar que todos los imports compilan (Satin API, Metal types)
- [ ] Obtener cuenta Apple Developer ($99/año) para firmar y deployar
- [ ] O conseguir Mac/Mac mini para compilar + sideloading gratuito (AltStore, 7 días)
- [ ] Migrar BooleanEngine de stub identidad a BSP tree real (Core/CSG/Shape.swift ya tiene BSP)
- [ ] Implementar GPU compute shaders para boolean ops (BooleanComputeShaders.metal existe, falta integrar)
- [ ] Conectar IBLPipeline.generate() al pipeline de render (el código existe, falta wiring)
- [ ] Agregar tangent/bitangent a VertexIn para normal maps en PBRShaders.metal
- [ ] Integrar Apple Pencil + PencilKit (GestureHandler usa touch genérico, sin presión)
- [ ] Corregir BUG1: layout GPU PBR (float3 padding a 16 bytes)
- [ ] Corregir BUG2: updateAnimation() doble por frame
- [ ] Corregir BUG3: UInt16 → UInt32 para mallas >65k vértices
- [ ] Corregir BUG5: normal matrix bajo escala no-uniforme
- [ ] Corregir BUG7: grab deformer dirección contraria
- [ ] Corregir BUG9: rebuildSceneFrom llamado cada frame (60 allocs/seg)
- [ ] Tests: ejecutar 7 test files en iOS simulator via CI

## Bloqueos
- Sin Mac para compilar localmente (Windows 11)
- Sin Apple Developer account para firmar/deployar
- CI falla con exit code 74 (xcodegen no encuentra paths del project.yml)

## Completados
- Estructura unificada: Sources/ contiene 69 archivos (Engines, CSG, CAD, Shaders, Services, Theme) *(done 2026-05-25)*
- Limpieza de 67 archivos huérfanos en backup_sources/ *(done 2026-05-25)*
- .git anidado eliminado, repo unificado *(done 2026-05-25)*
- Satin dependency unified a Hi-Rez/Satin 0.4.0 *(done 2026-05-25)*
- GitHub token removido del remote URL *(done 2026-05-25)*
- CSG real implementado (BSPTree + union/difference/intersection en Shape.swift) *(done 2026-05-12)*
- 49 engines en Sources/Engines/ (sculpt, animation, morph, IBL, PBR, CAD tools) *(done)*
- 5 shaders Metal funcionales (PBR, IBL diffuse/specular/BRDF, boolean compute) *(done)*
- ExportService con STEP ISO 10303-21 + OBJ/STL/USDZ/GLTF *(done)*
- UI completa: 25 archivos en Core/UI/ (ContentView, CanvasViewModel, AppState, theme) *(done)*
- 7 Features modes: CADMode (20 files), ExportMode, PaintMode, SculptMode, etc. *(done)*
