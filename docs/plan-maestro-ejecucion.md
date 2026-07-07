# Plan Maestro de Ejecución — AppForge Studio
> 2026-05-27 | 5 fases verificables | Ejecución autónoma

## Resumen de Auditoría (disco vs docs)

| Métrica | BRAIN.md | DISCO REAL | Estado |
|---------|----------|------------|--------|
| Engines | 49 files | 54 files | BRAIN desactualizado |
| Tests | 49 tests | 7 files | BRAIN inflado |
| BUG3 (UInt32) | Pendiente | YA RESUELTO | TODO desactualizado |
| BUG1 (padding) | Pendiente | YA RESUELTO | TODO desactualizado |
| Hi-Rez-Satin | "symlink roto" | Clon completo 350+ archivos | OK |
| CI remoto | gotchi-nano/appforge-studio | NO EXISTE | Bloqueo |

## FASE 0: Sincronización (15 min)
- [ ] Actualizar BRAIN.md con conteos reales (54 engines, 7 tests)
- [ ] Actualizar TODO.md: marcar BUG1 y BUG3 como done
- [ ] Limpiar artefacto `nul`
- [ ] Verificar git remote real

## FASE 1: Corrección de Bugs (45 min) — 4 bugs reales
- [ ] BUG2: updateAnimation() doble por frame — AnimationPlaybackController.tick() + AnimationEngine.update()
- [ ] BUG5: normal matrix bajo escala no-uniforme — SatinRenderer
- [ ] BUG7: GrabDeformer dirección contraria — usa point.normal, debe usar point.dragDelta
- [ ] BUG9: rebuildSceneFrom llamado cada frame (60 allocs/seg) — CanvasViewModel o Scene3D

## FASE 2: Conectar Features Existentes (60 min)
- [ ] Touch→Sculpt: MetalView → SculptEngine.applySculpt()
- [ ] HybridMode botones: Remesh, Color, Tamaño, Opacidad, Loop Cut, Bisel
- [ ] Import: fileImporter → ModelLoadService
- [ ] GLTF export: escribir buffer .bin

## FASE 3: CAD Avanzado (90 min)
- [ ] Fillet, Chamfer, Shell, Extrude, Revolve, Sweep reales

## FASE 4: CI + Tests (30 min)
- [ ] Arreglar CI build.yml para el remote correcto
- [ ] Push y verificar build

## Reglas de ejecución
- Cada bug → 1 code_agent
- Cada feature → 1 code_agent  
- Verificar con glob/list_dir después de cada code_agent
- Actualizar TODO.md inmediatamente al completar cada item
- No compilar localmente (Windows)
