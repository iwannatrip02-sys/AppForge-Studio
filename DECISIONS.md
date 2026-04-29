# Decisiones Arquitectónicas

## 2026-04-29: Pipeline CI/CD Windows → iPad
**Contexto:** Solo se dispone de PC Windows para desarrollo y iPad como dispositivo de prueba. No hay Mac.
**Decisión:** Adoptar GitHub Actions + AltStore como pipeline de compilación e instalación.
- Workflow build-ios.yml usa runner macos-14 (gratuito) para compilar con Xcode 15.4
- .ipa sin firma (CODE_SIGNING_ALLOWED=NO) para distribución personal via AltStore
- Apple ID gratuito: firma válida 7 días, AltStore autorefresca si el PC está encendido
- Alternativa TrollStore descartada: iPadOS 26+ no compatible
- OCCTSwift no puede incluirse en el build hasta que exista como Swift Package Manager package

## 2026-04-13: Arquitectura CAD + Sculpt
Ver docs/arquitectura_cad_sculpt.md

## 2026-04-13: Satin como motor de render
Se adoptó Satin v0.3.0 como framework Metal para SwiftUI. Alternativa SceneKit descartada por menor control sobre shaders.

## 2026-04-13: OCCT como motor CAD
Se adoptó OCCTSwift (bindings Swift para Open CASCADE Technology) para operaciones booleanas, fillet, extrude, revolve. Alternativa SceneKit descartada por falta de CAD paramétrico.