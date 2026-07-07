# Tech Stack

- Swift 5.9+, SwiftUI, iOS 17+ (target iPad principalmente).
- Metal 2: pipeline PBR + IBL + compute shaders (`Sources/Shaders/*.metal`).
- **Satin 13.0.0** (Hi-Rez/Satin, repo ARCHIVADO abr-2025) — framework Metal/Swift vía SPM, pineado a revisión exacta en `Package.swift`; clon espejo en `vendor/Satin/` para vendorización futura. CI aplica patch a Satin antes de build (script en workflow).
- ModelIO/MetalKit para import/export de modelos; simd para matemáticas.
- Proyecto Xcode generado con **XcodeGen** desde `ios-app/AppForgeStudio/project.yml` (Info.plist en `ios-app/AppForgeStudio/AppForgeStudio/`, NO mover).
- CI: `.github/workflows/build.yml` (único workflow válido) — runner macOS, build simulador + tests + archive IPA sin firmar.
- Sin cuenta Apple Developer y sin Mac local: la IPA sale sin firmar (sideload).
