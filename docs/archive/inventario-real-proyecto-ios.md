# AppForge Studio iOS — Inventario Real del Proyecto
> Generado: 2026-05-11

## Stack Confirmado
- **Lenguaje**: Swift 6.0
- **UI**: SwiftUI (iOS 17+)
- **Render**: Satin (Metal) — dependencia externa Hi-Rez/Satin
- **CAD**: OCCTSwift (Open CASCADE Technology) — kernel CAD paramétrico
- **Target**: AppForgeStudio (executable), AppForgeStudioTests

## Estructura del Workspace (`ios-app/AppForgeStudio/`)

| Dirección | Contenido |
|---|---|
| `Core/` | Engines, Managers, Render pipeline, CAD, Escultura, Pintura, Animación |
| `Features/` | UI Views por modo (CAD, Paint, Sculpt, Animate, Render, Hybrid, Export) |
| `Sources/AppForgeStudio/` | Entry point (ContentView, AppForgeStudioApp) |
| `Tests/` | Test targets |
| `Resources/` | Assets, shaders, modelos |
| `Preview/` | Preview Content |
| `docs/` | Documentación |
| `Build/` | Build artifacts |

## Lo que YA tenemos (evidencia de archivos vistos)

### Core/Engines — Múltiples motores
Engine principal, más 6+ engines de render, escultura, animación.

### Core/CAD — 12+ operaciones
Sólido CAD con sketch, constraints, extrusion, boolean operations.

### Core/Paint — Pipeline PBR
Editor de pintura 3D con capas, pinceles, texturas PBR.

### Core/Sculpt — Deformación
SculptEngine, deformers, SDF operations.

### Features/ — 7 modos de UI
Cada modo con su vista SwiftUI: CADMode, PaintMode, SculptMode, AnimationMode, RenderMode, HybridMode, ExportMode.

### Package.swift
Compila con Satin + OCCTSwift como dependencias.

## Lo que NO hemos verificado (falta leer)
- BRAIN.md — estado vivo del proyecto
- TODO.md — pendientes actuales
- GOTCHI.md — reglas locales
- DECISIONS.md — historial de decisiones
- ContentView.swift — root de la app
- Features/ — cada modo individual
- Tests/ — cobertura

## Próximo paso
Leer los 4 canónicos + ContentView + explorar Features/ y Core/ para diagnóstico completo de qué falta para superar Shapr3D + sculpting + paint3D.
