# Diagnóstico: Estructura Dual de AppForge Studio
> 2026-05-26 — Raíz del problema histórico de escritura duplicada

## Hallazgo crítico

AppForge Studio tiene **DOS capas de organización** que coexisten, causando dispersión:

### Capa 1 — Raíz (`C:\Users\USUARIO\Projects\appforge-studio\`)
- Archivos canónicos: BRAIN.md, TODO.md, GOTCHI.md, DECISIONS.md
- Package.swift (Swift Package Manager — compila desde aquí)
- project.yml (XcodeGen — genera .xcodeproj)
- .github/workflows/ — CI/CD
- docs/ — ~28 archivos de documentación (muchos vestigiales)
- scripts/ — build, deploy, export options
- Core/, Sources/, Features/, Tests/ — **fuentes de compilación REALES**
- Backup: backup_sources/, backup_sources_cadcore/, _export_full.swift

### Capa 2 — Subdirectorio (`ios-app/AppForgeStudio/`)
- Tiene su propio Sources/, Features/, docs/, etc.
- Es un **sub-proyecto vestigial** de una estructura anterior
- No se compila desde aquí (Package.swift está en raíz)

### Problema raíz

Cuando el code_agent o scripts escribían, a veces apuntaban a:
```
appforge-studio/Sources/ → compila OK
appforge-studio/ios-app/AppForgeStudio/Sources/ → archivo huérfano
```

Esto causó que:
1. Feature X parecía "completada" en BRAIN.md
2. Pero el código real quedaba en el subdirectorio equivocado
3. Al compilar, la feature no existía
4. Se re-escribía la feature en raíz → duplicación

## Correcciones necesarias

1. **Mover GUIA-SIDELOADING.md** de tangerine-product-lab a appforge-studio/docs/
2. **Archivar docs/ vestigiales** con project_organize_docs
3. **Revisar que Sources/ raíz sea la fuente única de verdad**
4. **Actualizar TODO.md con items reales**, no históricos
5. **Actualizar BRAIN.md con estado real de mayo 2026**

## Regla para futuro (vigente)

> **"La raíz de appforge-studio/ es la UNICA fuente de compilación. 
> NUNCA escribir en ios-app/AppForgeStudio/ a menos que sea un archivo de documentación."**
