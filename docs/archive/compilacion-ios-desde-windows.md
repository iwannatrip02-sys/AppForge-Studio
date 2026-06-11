# Compilación iOS desde Windows — AppForge Studio en iPad

> Documento generado: 2026-05-25
> Objetivo: Usar AppForge Studio en iPad de forma REAL, CONSTANTE y GRATIS compilando desde Windows.

---

## Resumen Ejecutivo

**SÍ es posible compilar y desplegar AppForge Studio en un iPad real desde Windows sin pagar por Mac.** La estrategia combina **GitHub Actions** (con runners macOS gratuitos) + **certificados de firma exportables** + **distribución vía TestFlight o sideloading**. El costo es $0/mes en infraestructura (sujeto a límites de minutos gratuitos).

---

## Opción 1: GitHub Actions + macOS Runner (RECOMENDADA)

### Cómo funciona
GitHub Free incluye **2000 minutos/mes** en runners **macOS** (suficientes para ~30-40 compilaciones). El runner macOS tiene Xcode preinstalado y puede compilar cualquier proyecto Swift/SwiftUI.

### Flujo completo
1. Subes el código de AppForge Studio a un repo privado en GitHub
2. Configuras un workflow `.github/workflows/build-ipa.yml`
3. El workflow:
   - Clona el repo en un runner macOS
   - Resuelve dependencias Swift Package Manager
   - Compila con `xcodebuild`
   - Firmea con certificado de distribución (exportado desde Xcode)
   - Genera el `.ipa` como artifact descargable
4. Descargas el `.ipa` desde GitHub Actions → lo instalas en tu iPad

### Ejemplo de workflow (build-ipa.yml)

```yaml
name: Build AppForge IPA

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Select Xcode version
        run: sudo xcode-select -s /Applications/Xcode_16.2.app
      
      - name: Resolve Swift Packages
        run: |
          cd ios-app/AppForgeStudio
          swift package resolve
      
      - name: Build & Archive
        run: |
          cd ios-app/AppForgeStudio
          xcodebuild clean archive \
            -scheme AppForgeStudio \
            -configuration Release \
            -archivePath ${{ runner.temp }}/AppForge.xcarchive \
            -allowProvisioningUpdates \
            CODE_SIGN_STYLE=Manual \
            PROVISIONING_PROFILE_SPECIFIER="AppForge Distribution" \
            DEVELOPMENT_TEAM=${{ secrets.APPLE_TEAM_ID }}
      
      - name: Export IPA
        run: |
          xcodebuild -exportArchive \
            -archivePath ${{ runner.temp }}/AppForge.xcarchive \
            -exportPath ${{ runner.temp }}/ipa \
            -exportOptionsPlist ExportOptions.plist
      
      - name: Upload IPA
        uses: actions/upload-artifact@v4
        with:
          name: AppForgeStudio.ipa
          path: ${{ runner.temp }}/ipa/AppForgeStudio.ipa
```

### Requisitos para firma (signing)
- **Cuenta Apple Developer** ($99/año) — es el ÚNICO costo real. Necesaria para firmar la app.
- **Certificado de distribución** exportable (.p12) — se crea desde Xcode en un Mac (cualquier Mac, incluso prestado una sola vez)
- **Provisioning Profile** — también exportable
- **Secrets en GitHub**: `APPLE_TEAM_ID`, certificado .p12 (base64), provisioning profile (base64), contraseña del certificado

### Gestión del certificado (una sola vez)
1. En un Mac: Xcode → Settings → Accounts → Export Apple ID and Code Signing Assets
2. O manual: Keychain Access → exportar certificado como .p12
3. Subir a GitHub Secrets como base64: `CERTIFICATE_P12`, `CERTIFICATE_PASSWORD`
4. En el workflow, importar con:
```yaml
- name: Import Certificate
  run: |
    echo "${{ secrets.CERTIFICATE_P12 }}" | base64 --decode > /tmp/cert.p12
    security create-keychain -p temp temp.keychain
    security import /tmp/cert.p12 -k temp.keychain -P "${{ secrets.CERTIFICATE_PASSWORD }}" -A
```

---

## Opción 2: Codemagic (CI/CD en la nube)

### Plan gratuito
- **500 minutos/mes gratis** en Mac mini M2
- Compatible con proyectos Swift nativos
- Build + firma + publicación automática a TestFlight

### Configuración
1. Conectas tu repo de GitHub
2. Creas `codemagic.yaml` en raíz del proyecto
3. Codemagic maneja el signing automáticamente (solo necesitas subir tu Apple Developer key)

### Ventajas vs GitHub Actions
- UI gráfica más amigable
- Firma automática con App Store Connect API Key
- Publicación directa a TestFlight

### Desventajas
- Solo 500 min/mes (vs 2000 de GitHub)
- Builds más lentos (Mac mini compartido)

---

## Opción 3: SwiftBuild (herramienta especializada)

**Repo**: `github.com/justdev-chris/SwiftBuild` (creado ene 2026)

SwiftBuild es una herramienta diseñada específicamente para compilar apps SwiftUI desde Windows usando GitHub Actions. Promete IPA funcionales sin necesidad de hardware Apple.

### Cómo usarla
1. Clonas SwiftBuild
2. Apuntas a tu proyecto Swift
3. Ejecuta el pipeline que:
   - Provisiona un runner macOS en GitHub Actions
   - Compila tu proyecto Swift
   - Genera el IPA firmado
4. Descargas el artifact

**Estado**: Proyecto nuevo (ene 2026), requiere verificación. Pero la idea es exactamente lo que necesitas.

---

## Sideloading Alternativo (sin $99/año)

Si no quieres pagar la cuenta de desarrollador Apple:

| Método | Costo | Renovación | Límite apps |
|--------|-------|------------|-------------|
| **AltStore** | Gratis | 7 días | 3 apps |
| **Sideloadly** | Gratis | 7 días | 3 apps |
| **SideStore** | Gratis | 7 días | ~10 apps |
| **TrollStore** (iOS ≤14.0) | Gratis | Permanente | Ilimitado |

**Problema**: Cada 7 días debes reconectar el iPad a Windows para re-firmar. No es "constante".

**Solución híbrida**: GitHub Actions genera el IPA → AltStore + AltServer en Windows firma OTA (sin cable).

---

## Estado Actual del Proyecto (dependencias)

**Archivo leído**: `docs/dependencias-build.md` (11 mayo 2026)

**Problemas resueltos**:
1. ✅ Satin corregido de branch "main" a tag semver `0.4.0`
   - `from: "0.4.0"` funciona correctamente
2. ✅ OCCTSwift removido (repositorio público inexistente)
   - Eliminado de Package.swift targets

**Problema pendiente**: Código Swift que referencie OCCTSwift generará errores de compilación. Hay que buscarlos y comentarlos/quitar importaciones.

---

## Plan de Acción Paso a Paso

### Fase 1: Preparar el proyecto
1. Buscar y eliminar referencias a OCCTSwift en todo el código Swift
2. Verificar que `Package.swift` compile con `swift package resolve` (desde cualquier máquina con Swift)
3. Crear `ExportOptions.plist` para distribución

### Fase 2: Configurar GitHub Actions
4. Crear `.github/workflows/build-ipa.yml` con el workflow
5. Subir el proyecto a GitHub (repo privado)
6. Configurar secrets: certificados, team ID, provisioning profile

### Fase 3: Build + Deploy
7. Hacer push → GitHub Actions compila automáticamente
8. Descargar IPA desde Actions → instalar en iPad
9. Opcional: Configurar publicación automática a TestFlight

---

## Límites Gratuitos

| Recurso | Gratis/mes | Equivale a |
|---------|-----------|------------|
| GitHub Actions macOS | 2000 min | ~30-40 builds completos |
| Codemagic | 500 min | ~8-10 builds |
| Apple Developer ($99/año) | N/A | Obligatorio para firma permanente |
| TestFlight | Ilimitado | Distribución a 100 beta testers |

---

## Conclusión

**Costo real: $99/año** (Apple Developer) — no hay forma de evitarlo si quieres firma permanente y distribución estable.

**Infraestructura: $0/mes** — GitHub Actions cubre las builds.

**Workflow**: Escribes código en Windows → haces push a GitHub → GitHub Actions compila en macOS cloud → descargas IPA → instalas en iPad. Todo desde Windows, sin Mac, sin suscripciones mensuales.

La herramienta **SwiftBuild** y los artículos recientes (mar-may 2026) confirman que el pipeline GitHub Actions + Swift desde Windows es un enfoque maduro y documentado.
