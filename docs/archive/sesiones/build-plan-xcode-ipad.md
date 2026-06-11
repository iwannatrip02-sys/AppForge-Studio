# Build Plan: Compilar AppForgeStudio en iPad

## Estado Actual del Proyecto
- **Package.swift** configurado con Swift 6.0, iOS 17+, Satin 0.4.0
- **Entry point**: `Core/UI/AppForgeStudioApp.swift` con `@main` + SwiftUI + Metal + Satin
- **NO** existe `.xcodeproj` ni `.xcworkspace` — el proyecto es 100% SPM
- **~80+ archivos Swift** en Core/Engines/Services/ViewModels
- **2 shaders Metal** en Core/Managers/Shaders.metal
- **NO** hay repositorio GitHub creado aún

## Arquitectura del Entry Point
AppForgeStudioApp.swift:
- `@main struct AppForgeStudioApp: App` con WindowGroup
- Llama a `SatinRendererView()` que usa MTKView + Satin
- Render pipeline: PaintRenderer.swift + PincelRenderer.swift + Satin
- Sistema de materiales con PBR (Metal roughness/metalness)
- Animación con AnimationEngine (SceneKit + Metal bridge)
- Export service para STL/OBJ/glTF

## Lo que FALTA para Compilar en iPad

### 1. XcodeGen project.yml (CREAR)
Desde Windows, no podemos abrir Xcode. Pero podemos generar el .xcodeproj:
- Usar XcodeGen (tool multiplataforma) para crear `project.yml`
- Este YAML define targets, fuentes, recursos, frameworks
- Se sube a GitHub, un Mac runner ejecuta `xcodegen generate`

### 2. GitHub Actions Workflow (CREAR)
Workflow YAML en `.github/workflows/build.yml`:
- Trigger: push a main + pull_request
- Runner: macOS-latest (GitHub hosted, gratis 2000 min/mes)
- Pasos: checkout → xcodegen generate → xcodebuild → export .app/.ipa
- Firmado con certificados exportados como secrets

### 3. Xcode Project Generation (PRIMER BUILD)
- push a GitHub → runner genera .xcodeproj con xcodegen
- Luego xcodebuild confirma que compila
- Se descarga el artifact .app

### 4. Carga al iPad (DESPUÉS DEL BUILD)
- Usar .ipa firmado con Apple Developer account ($99/año)
- O sideloading con AltStore (gratis, expira 7 días)
- O TestFlight (requiere Developer account)

## Pipeline Completo
Windows (escribe código + push) 
  → GitHub (trigger workflow) 
    → macOS runner (xcodegen + xcodebuild) 
      → artifact descargable (.app/.ipa) 
        → iPad (AltStore/TestFlight)

## Tiempo Estimado
- project.yml + workflow: 30 min
- Primer build y corrección: 1-2 horas
- Carga a iPad: 15 min
