# Dependencias y compilación — AppForge Studio

## Problemas detectados (11 mayo 2026)
1. Package.swift línea 19: `Satin` con branch "main" → inexistente, requiere tag semver
2. Package.swift línea 20: `OCCTSwift` desde URL `occt/occtswift.git` → repositorio no existe públicamente

## Solución aplicada
1. Satin cambiado a `.package(url: "https://github.com/Hi-Rez/Satin.git", from: "0.4.0")`
2. OCCTSwift removido completamente (package + target dependency)
3. Pendiente: `swift package resolve && swift build` para verificar
4. Errores de OCCTSwift en código Swift serán corregidos en paso siguiente
