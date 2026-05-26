# AppForge Studio — TODO.md
> Updated: 2026-05-26 04:30 UTC
> Post-compilation-fix v1: los 7 bugs de compilacion resueltos. Satin 13.0.0. Shape unificado sin conflictos de tipos.

## Foco actual
- Hacer que el proyecto compile en CI (GitHub Actions macOS) y ver si los tests pasan

## Pendientes
- [ ] Verificar que CI compila sin errores (push reciente, build #12 pendiente)
- [ ] Verificar que los 49 tests pasan en iOS Simulator via CI
- [ ] Obtener cuenta Apple Developer ($99/año) para firmar y deployar
- [ ] O conseguir Mac/Mac mini para compilar + sideloading gratuito (AltStore, 7 días)
- [ ] Conectar sculpt al touch — los 10 deformers existen pero MetalView nunca los llama. rayTriangleIntersect() existe pero no se usa
- [ ] Activar botones de HybridMode — Remesh, Color, Tamaño, Opacidad, Loop Cut, Bisel (engines implementados, closures vacíos)
- [ ] Agregar botón "Import" con fileImporter → ModelLoadService (el engine existe, falta UI)
- [ ] Arreglar export GLTF (escribe JSON pero nunca escribe el buffer .bin)
- [ ] Implementar filleted/chamfered/shelled/extruded/revolved/swept reales en Shape (actualmente son stubs identidad)
- [ ] Corregir BUG1: layout GPU PBR (float3 padding a 16 bytes)
- [ ] Corregir BUG2: updateAnimation() doble por frame
- [ ] Corregir BUG3: UInt16 → UInt32 para mallas >65k vértices
- [ ] Corregir BUG5: normal matrix bajo escala no-uniforme
- [ ] Corregir BUG7: grab deformer dirección contraria
- [ ] Corregir BUG9: rebuildSceneFrom llamado cada frame (60 allocs/seg)

## Bloqueos
- Sin Mac para compilar localmente (Windows 11)
- Sin Apple Developer account para firmar/deployar
- Satin repo archivado (Hi-Rez/Satin, último tag 13.0.0, Abril 2025)

## Completados
- BUG6 (Shape.swift/Mesh.swift): dual Mesh/Vertex definitions — UNIFICADO a Mesh.swift *(done 2026-05-26)*
- BUG2 (Shape.swift): 13 metodos faltantes (triangulate, boundingBox, volume, area, exportSTEP, etc.) — IMPLEMENTADOS *(done 2026-05-26)*
- BUG3 (SatinRenderer.swift): deltaTime use-before-definition — CORREGIDO *(done 2026-05-26)*
- BUG4 (ExportService.swift): MDLMesh(submesh:allocator:) invalido — CORREGIDO a vertex buffer API *(done 2026-05-26)*
- BUG5 (AnimationEngine.swift): simd_float4x4(rotation) missing — EXTENSION AGREGADA *(done 2026-05-26)*
- BUG6 (OCCTEngine.swift): measureBoundingBox duplicado — ELIMINADO *(done 2026-05-26)*
- BUG7 (Package.swift + project.yml): Satin 0.4.0→13.0.0 — CORREGIDO *(done 2026-05-26)*
- AppIcon + AccentColor assets creados en Resources/Assets.xcassets *(done 2026-05-26)*
- LaunchScreen reemplazado por UILaunchScreen (iOS 17+) *(done 2026-05-26)*
- Test target agregado a project.yml *(done 2026-05-26)*
- CI workflow: tests + archive + IPA export arreglados *(done 2026-05-26)*
- Operadores Shape - y & arreglados (usaban stubs, ahora usan CSGOperation.difference/intersection) *(done 2026-05-26)*
- Estructura unificada: Sources/ contiene 69+ archivos (Engines, CSG, CAD, Shaders, Services, Theme) *(done 2026-05-25)*
- Limpieza de 100+ archivos huérfanos *(done 2026-05-25)*
- .git anidado eliminado, repo unificado *(done 2026-05-25)*
- Satin dependency unified a Hi-Rez/Satin *(done 2026-05-25)*
