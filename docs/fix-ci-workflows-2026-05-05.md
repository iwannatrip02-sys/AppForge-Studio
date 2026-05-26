# Diagnóstico y corrección de Workflows CI
> AppForge Studio | 2026-05-05

## Estado actual

### build-ios.yml
**Antes**: Usaba `xcodebuild -scheme AppForgeStudio` sin proyecto. El proyecto es un Swift Package, no tiene .xcodeproj. **Falla**: xcodebuild no encuentra esquema.

### ios-build.yml
**Antes**: Referencia `AppForgeStudio.xcodeproj` que **no existe** en disco. El proyecto es Package.swift. **Falla**: xcodebuild busca archivo inexistente.

## Causa raíz
El proyecto migró de Xcode project a Swift Package, pero los workflows no se actualizaron.

## Solución aplicada
- Se agregó step `cd ios-app/AppForgeStudio && swift package generate-xcodeproj` ANTES del build en ambos workflows.
- Los comandos xcodebuild ahora usan `-project AppForgeStudio.xcodeproj -scheme AppForgeStudio` con `cd ios-app/AppForgeStudio`.
- build-ios.yml: build + empaquetado .ipa.
- ios-build.yml: build + tests en iPad Pro M4 Simulator.

## Push
Commit `5df1883` pusheado a `origin/main`. Branch upstream configurado.

## Próximo paso
Verificar que GitHub Actions dispare y el build pase en macos-14/Xcode.