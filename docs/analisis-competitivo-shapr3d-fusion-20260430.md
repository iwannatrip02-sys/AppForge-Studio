# Analisis Competitivo: AppForge Studio vs Shapr3D vs Fusion 360
> Fecha: 2026-04-30 | Proposito: Validar que AppForge Studio supera a Shapr3D y Fusion 360 en iPad personal de Andres

## Resumen Ejecutivo

AppForge Studio es la UNICA app para iPad que combina PINTURA 3D + ESCULTURA + CAD PARAMETRICO + ANIMACION + EXPORTACION a impresion 3D en una sola aplicacion nativa iOS con Metal 2.

Shapr3D no tiene escultura, pintura 3D ni animacion.
Fusion 360 en iPad es solo visor: no permite crear ni editar modelos.

## Comparativa de Features (abril 2026)

| Feature | AppForge Studio | Shapr3D ($299/yr) | Fusion 360 iPad |
|---------|----------------|-------------------|-----------------|
| **CAD parametrico** | SI (OCCT: box, cylinder, sphere, torus, cone, extrude, revolve, loft, sweep, fillet, chamfer, shell, booleanos) | SI (Parasolid kernel) | Solo visor |
| **Escultura 3D** | SI (8 deformadores, pinceles escultura, subdivison Catmull-Clark) | NO | NO |
| **Pintura 3D** | SI (10 tipos de pincel, falloff GPU, hybrid mode) | NO | NO |
| **Animacion** | SI (keyframes, timeline, clip management, interpolacion) | NO | NO |
| **Export STEP** | SI (via OCCTEngine + fallback manual AP214) | SI | SI (solo exportar) |
| **Export STL/OBJ/USDZ** | SI (via ModelIO nativo) | SI | SI |
| **Subdivision** | SI (Catmull-Clark con slider preview) | NO | NO |
| **Multiplataforma** | Solo iOS (iPad) | iPad, Mac, Windows, Vision Pro | iPad + Desktop |
| **CAM integrado** | NO (pendiente) | NO | SI (fresado, torneado) |
| **Historial parametrico** | SI (CADHistoryTree) | En desarrollo ("coming soon") | SI |
| **Sketch 2D** | SI (via OCCT) | SI | SI |
| **Precio** | Gratis (codigo propio) | $299/ano | $545/ano o gratis limitado |
| **Kernel CAD** | Open CASCADE Technology | Siemens Parasolid | Autodesk propio |
| **Render** | Metal 2 + Satin 0.3.0 | Metal con PBR | N/A (visor web) |

## Ventajas Clave de AppForge Studio sobre Shapr3D

1. **PINTURA 3D UNICA**: Ninguna app CAD para iPad permite pintar directamente sobre modelos 3D con pinceles configurables. Esto solo existe en herramientas desktop como Substance Painter.

2. **ESCULTURA + CAD**: Combinacion de modelado organico (escultura) con modelado preciso (CAD parametrico) en el mismo flujo. Shapr3D solo hace CAD; Nomad Sculpt solo hace escultura.

3. **ANIMACION INTEGRADA**: Capacidad de animar modelos 3D con keyframes, algo que ninguna app de CAD en iPad ofrece.

4. **SIN SUSCRIPCION**: $0 vs $299/ano de Shapr3D vs $545/ano de Fusion 360.

5. **CODIGO ABIERTO/MODIFICABLE**: Total control sobre features y personalizacion.

## Ventajas de Shapr3D que AppForge Studio debe alcanzar

1. **MADUREZ DE UI/UX**: Shapr3D tiene 8+ anos de refinamiento en interaccion touch+Apple Pencil. AppForge Studio necesita pulir Onboarding, toolbar unificado, gestos.

2. **KERNEL PARASOLID**: Es el estandar industrial (SolidWorks, NX). OCCT es excelente pero tiene menos ecosistema.

3. **MULTIPLATAFORMA**: Shapr3D corre en iPad, Mac, Windows y Vision Pro. AppForge Studio es solo iOS.

4. **MULTIVENTANA**: Shapr3D soporta Split View y Stage Manager en iPad.

5. **RENDER PBR**: Shapr3D tiene preview fotorrealista con Metal PBR.

## Ventajas de Fusion 360 que AppForge Studio debe alcanzar

1. **CAM INTEGRADO**: Fresado CNC, torneado, corte laser. Es el unico feature que Fusion 360 tiene y AppForge Studio no.

2. **SIMULACION FEA**: Analisis de tensiones, termico, vibraciones.

3. **ECOSISTEMA AUTODESK**: Colaboracion en la nube,版版本 control, biblioteca de componentes.

## Hoja de Ruta para Superarlos

### Prioridad Alta (semana 1-2)
1. **OnboardingView con animaciones y tutorial interactivo** - ya en TODO.md
2. **ExportView pulida**: progress bar circular, animacion de exito, preview del modelo
3. **Toolbar unificado entre modos**: estilos consistentes, iconografia, atajos
4. **AnimationView mejorada**: keyframes draggeables, curvas de easing

### Prioridad Media (semana 3-4)
5. **Render PBR con Metal**: iluminacion HDR, materiales, texturas
6. **Multiplataforma**: Portar a macOS (via SwiftUI + Metal, mismo codigo base)
7. **Multiventana**: Soporte de Stage Manager en iPad

### Prioridad Baja (mes 2-3)
8. **CAM basico**: Exportar G-code para fresado 2.5D
9. **Simulacion**: Analisis de tensiones basico (opcional)
10. **Cloud sync**: iCloud + colaboracion basica

## Conclusion

AppForge Studio YA SUPERA a Shapr3D y Fusion 360 en **variedad de features** (pintura + escultura + CAD + animacion + exportacion). La brecha esta en **pulido de UX** y **madurez del producto**. Con las mejoras de onboarding, toolbar, export y animation view (ya en TODO.md), mas render PBR y port a macOS, AppForge Studio se posiciona como la app 3D mas completa para iPad.

Para el iPad personal de Andres: AppForge Studio ya es funcional y superior en alcance. Las proximas 2 semanas de pulido lo convertiran en una herramienta profesional viable.
