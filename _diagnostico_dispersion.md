# Diagnostico de Dispersion — AppForge Studio
> Creado: 2026-05-12 00:53 UTC

## MAPA DE DISPERSION

**RAIZ MADRE** (`C:\Users\USUARIO\Projects\appforge-studio`):
- 4 canonicos: GOTCHI.md (workspace apunta a raiz), BRAIN.md, TODO.md, DECISIONS.md
- Whitelist: ARCHITECTURE.md, CHANGELOG.md, ROADMAP.md
- Sources/ (carpeta misteriosa — verificar contenido)
- Hi-Rez-Satin/ (submodulo?)
- scripts/
- docs/ (analisis-estado-modulo-cad.md u otros)
- _archive/
- ExportOptions.plist

**SUB-PROYECTO iOS** (`ios-app/`):
- AppForgeStudio/ (Package.swift + Sources/ + Tests/ — 47 engines reales)
- docs/
- Sources_backup.zip

## PROBLEMAS IDENTIFICADOS
1. Workspace del proyecto registry apunta a raiz madre, NO a ios-app/AppForgeStudio donde esta el codigo real
2. La raiz madre tiene Sources/ — ? que contiene? (posible duplicado/engano de sesiones anteriores)
3. ios-app/ puede tener sus propios canonicos duplicando informacion
4. GOTCHI.md de raiz describe estructura de ios-app/AppForgeStudio/ como si fuera local — inconsistencia

## PLAN DE UNIFICACION (a ejecutar con code_agent)
1. Verificar contenido de Sources/ en raiz madre
2. Leer canonicos de ios-app/ (si existen)
3. Consolidar TODO el conocimiento en los 4 canonicos de la raiz madre
4. Mover/archivar Sources/ de raiz madre si es duplicado
5. Actualizar workspace del proyecto registry
6. Actualizar project brain
