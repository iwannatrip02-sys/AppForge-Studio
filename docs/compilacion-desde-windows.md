# Compilación de AppForge Studio desde Windows

## Problema
Xcode (el IDE necesario para compilar apps iOS nativas con Metal) **solo funciona en macOS**. Apple no permite su ejecución en Windows ni en máquinas virtuales no Apple. El código SwiftUI + Metal del proyecto no puede compilarse directamente desde Windows.

## Soluciones reales (sin Mac físico)

### Opción 1: GitHub Actions con runner macOS (RECOMENDADA)
- Crear un workflow `.github/workflows/build.yml` que use `macos-latest` o `macos-14` runner
- El runner es un Mac real en la nube de GitHub, con Xcode 15+ preinstalado
- Pasos: `swift build` (o `xcodebuild` si se tiene proyecto .xcodeproj) → generar .app → firmar con certificado de Apple Developer
- Límite: 2000 minutos/mes gratis en cuentas públicas; cuentas privadas tienen 300-500 min/mes
- Ventajas: gratuito hasta cierto límite, no requiere infraestructura propia

### Opción 2: Servicios cloud CI/CD específicos para iOS
- **Codemagic** (Flutter nativo) — build automático desde repo, integración con App Store Connect
- **Bitrise** — CI/CD nativo para iOS, soporta proyectos Swift/UIKit
- **Expo Application Services** (si se usa React Native)
- Costo: ~$30-80/mes los planes básicos

### Opción 3: Mac mini en la nube (renta por horas)
- **MacStadium** — Mac mini dedicado, ~$100/mes
- **MacInCloud** — por horas, ~$1-2/hora
- Permite acceso remoto completo al escritorio macOS para usar Xcode directamente

### Opción 4: Swift on Windows (NO SIRVE para iOS)
- El Swift oficial para Windows (swift.org) compila para Win32 API, no para UIKit/Metal
- No genera código para iOS ni usa el SDK de Apple
- Solo útil para compartir lógica de negocio multiplataforma

## Plan recomendado para AppForge Studio

1. **Configurar GitHub Actions** con workflow que compile en `macos-14` runner
2. El workflow debe:
   - Checkout del repositorio
   - Instalar dependencias SPM
   - Ejecutar `swift build` (o `xcodebuild` si se prepara proyecto Xcode)
   - Ejecutar tests (si existen)
   - Artefacto: app compilada
3. Para deploy al iPad: necesitarás cuenta Apple Developer ($99/año) para firmar y subir a TestFlight

## Requisitos adicionales
- Cuenta Apple Developer ($99/año)
- Certificado de distribución (se genera desde Xcode en macOS, pero se puede gestionar via Fastlane match)
- El iPad final recibirá la app via TestFlight o App Store