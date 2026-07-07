# AppForge Studio — Plan de Desarrollo por Fases
> 2026-05-27 | Auditoria: Gotchi + OpenCode

## Resumen del Estado Real (disco vs brain)

| Indicador | BRAIN.md | Disco Real | Estado |
|-----------|----------|------------|--------|
| Archivos Engines/ | 49 | 54 | BRAIN desactualizado |
| Tests | 49 tests | 7 archivos de test | BRAIN inflado |
| Hi-Rez-Satin/ | symlink roto | clon completo 350+ archivos | OK, es real |
| Mesh.indices | UInt16 (BUG3) | UInt32 | YA CORREGIDO |
| CI remoto | gotchi-nano/appforge-studio | No encontrado | BLOQUEADO |
| BUG3 (UInt16→UInt32) | Pendiente | Ya usa UInt32 en Mesh.swift | YA HECHO |
| GOTCHI.md Satin ver | s1ddok | Hi-Rez/Satin 13.0.0 | Desactualizado |

---

## FASE 0: Limpieza y Sincronizacion (ahora)
- [ ] Corregir GOTCHI.md: Satin version, estructura real
- [ ] Eliminar `nul` untracked
- [ ] .gitignore Hi-Rez-Satin/ o decidir si es submodulo
- [ ] Verificar git remote real (`git remote -v`)
- [ ] Actualizar BRAIN.md con conteos reales
- [ ] Marcar BUG3 como YA HECHO en TODO.md

## FASE 1: Correccion de Bugs (logica Swift pura, sin Mac)
- [ ] BUG1: layout GPU PBR (float3 padding a 16 bytes en shader Metal)
- [ ] BUG2: updateAnimation() doble por frame (CADisplayLink duplicado)
- [ ] ~~BUG3: UInt16→UInt32~~ YA HECHO (Mesh.swift usa UInt32)
- [ ] BUG5: normal matrix bajo escala no-uniforme
- [ ] BUG7: grab deformer direccion contraria
- [ ] BUG9: rebuildSceneFrom 60 allocs/seg (cache check)

## FASE 2: Conectar Features Existentes
- [ ] Touch→Sculpt: MetalView llama a SculptEngine con rayTriangleIntersect
- [ ] Activar botones HybridMode: Remesh, Color, Tamano, Opacidad, Loop Cut, Bisel
- [ ] Boton Import con fileImporter → ModelLoadService
- [ ] Export GLTF: escribir buffer .bin (actualmente solo JSON)

## FASE 3: CAD Avanzado (stubs → reales)
- [ ] FilletEngine real (actualmente stub identidad)
- [ ] ChamferEngine real
- [ ] ShellEngine real
- [ ] ExtrudeEngine real
- [ ] RevolveEngine (nuevo o completar SweepEngine)
- [ ] SweepEngine real

## FASE 4: CI + Tests + Push
- [ ] Corregir remote y flujo CI
- [ ] Verificar que los 7 tests existentes compilan
- [ ] Push final con todos los cambios

---

## Metodo de Trabajo
1. Cada fase se ejecuta con code_agent (tareas multi-archivo) o inline (tareas 1-2 archivos)
2. Al completar cada item: project_todo_update(action='done')
3. Al final de cada fase: project_brain_update + verificacion
4. Si code_agent falla 2 veces: cambiar enfoque, no reintentar
