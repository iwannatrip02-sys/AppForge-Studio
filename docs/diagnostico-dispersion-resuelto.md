# Diagnóstico de Dispersión — Resuelto

## Problema detectado
Los archivos canónicos (GOTCHI.md, BRAIN.md, TODO.md, DECISIONS.md) existen en DOS lugares:
1. `C:\Users\USUARIO\Projects\appforge-studio\` (raíz del repo)
2. `C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\` (sub-proyecto activo)

## Causa raíz
El workspace de proyecto en el registry de NanoAtlas siempre apuntó a `ios-app/AppForgeStudio/`, pero en sesiones anteriores se trabajó también desde la raíz, creando canónicos duplicados.

## Solución aplicada
- PROYECTO ACTIVO: `AppForge Studio` con workspace `ios-app/AppForgeStudio/`
- Los canónicos del workspace activo son la verdad oficial (los escribe project_brain_update, project_todo_update, decision_log)
- Los canónicos de raíz (`/GOTCHI.md`, `/BRAIN.md`, `/TODO.md`, `/DECISIONS.md`) son vestigiales — se archivan a `_archive/root_canonicals/`
- Las modificaciones futuras SOLO tocan: `ios-app/AppForgeStudio/GOTCHI.md`, `ios-app/AppForgeStudio/BRAIN.md`, `ios-app/AppForgeStudio/TODO.md`, `ios-app/AppForgeStudio/DECISIONS.md`
- CUALQUIER code_agent recibe como cwd: `C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio`

## Estado actual del proyecto
v0.9 — 2026-05-25. 80+ archivos Swift, 2 Metal shaders, Satin 0.4.0.
- Features completadas: CSG booleanas, AnimationEngine (keyframes + playback), CAD parametrico, Export service
- Infraestructura: project.yml (XcodeGen), build.yml (GitHub Actions), ExportOptions.plist
- Pendientes: build validation, subir repo a GitHub, conectar features UI faltantes

## Próximas features (orden priorizado)
1. Mejorar UI del modelador — toolbar completa, botones CSG
2. Más deformers (twist, crease ya existen; agregar bend, shear)
3. Exportación STEP funcional — validar ExportView conectada
4. Sculpting con pinceles — pulir BrushEngine + interacción táctil
