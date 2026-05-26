# Estado del Build — AppForge Studio en iPad

> Sesión: 2026-05-25
> Objetivo: Compilar y desplegar AppForge Studio en un iPad real para ver la interfaz

---

## ¿Dónde estamos?

### ✅ Lo que ya funciona
- **Entry point listo**: `Core/UI/AppForgeStudioApp.swift` con `@main`, SwiftUI + Metal + Satin, `AppRootView` con onboarding y navegación
- **Package.swift correcto**: Swift 6.0, iOS 17+, Satin 0.4.0 vía SPM
- **~80+ archivos Swift** en Core/Engines/, Core/CSG/, Core/Services/, Features/, Sources/
- **Documentación de build existe**: `docs/compilacion-ios-desde-windows.md` con el pipeline GitHub Actions detallado
- **Build/ directory** con diffs y backups de versiones previas

### ❌ Lo que falta (para compilar en iPad)

| # | Pendiente | Prioridad |
|---|-----------|-----------|
| 1 | **Crear Xcode project** (.xcodeproj) — el proyecto es solo Package.swift, no tiene proyecto Xcode para `xcodebuild` | 🔴 Alta |
| 2 | **Crear scheme de build** para que `xcodebuild archive` funcione | 🔴 Alta |
| 3 | **Configurar repo GitHub** y subir el código | 🔴 Alta |
| 4 | **Crear workflow YAML** `.github/workflows/build-ipa.yml` | 🔴 Alta |
| 5 | **Exportar certificados de firma** desde una Mac (perfil de desarrollo/distribución) | 🟡 Media |
| 6 | **Probar compilación local** con `swift build` primero (sin Xcode) | 🟡 Media |

---

## Plan de acción (3 pasos)

### Paso 1: Crear Xcode project + scheme (desde Windows)
- Usar `swift package generate-xcodeproj` NO funciona en Swift 6.0 (deprecated)
- Alternativa: crear `.xcodeproj` manualmente con `xcodeproj` Ruby gem, o mejor:
- Usar **Tuist** (`tuist init`) o **XcodeGen** para generar el proyecto desde un spec YAML
- Instalar XcodeGen via Homebrew... no tenemos macOS. Otra opción: escribir el `project.yml` manual y generarlo en el runner de GitHub Actions

### Paso 2: Configurar GitHub + workflow CI
- Crear repo `appforge-studio` en GitHub
- Crear `.github/workflows/build-ipa.yml` con el workflow que:
  1. Corre en `macos-latest`
  2. Genera el Xcode project desde Package.swift
  3. Compila con `xcodebuild`
  4. Genera .ipa como artifact

### Paso 3: Firma y despliegue
- Necesitas exportar desde una Mac: 
  - Certificado de distribución (`.p12`)
  - Perfil de aprovisionamiento (`.mobileprovision`)
- Subirlos como GitHub Secrets
- El workflow los usa para firmar el .ipa
- Descargar el artifact y usar sideloading (AltStore) o TestFlight

---

## Próxima acción concreta
**Crear el workflow YAML de build** y subir el proyecto a GitHub. Podemos hacer eso AHORA mismo desde Windows. Luego necesitarás una Mac (cuando tengas acceso) para:
1. Exportar los certificados de firma
2. Hacer `swift package generate-xcodeproj` una vez
3. Subir el .xcodeproj generado al repo
