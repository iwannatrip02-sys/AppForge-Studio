# Ruta de Compilación Gratuita para AppForge Studio

> Investigación: 2026-05-07 | Gotchi

## Resumen Ejecutivo

AppForge Studio (Swift + Metal) **SÍ puede compilarse sin un Mac físico**, pero requiere una estrategia híbrida. No hay un solo método gratuito que lo resuelva todo — la solución es una combinación de 3 frentes paralelos.

---

## 1. Compilación Swift/Metal sin Mac Físico

### Opción A: Mac Mini Cloud (RECOMENDADA)

| Servicio | Precio | Especificaciones |
|----------|--------|------------------|
| **Macly.io** | ~$30-50/mes | Mac Mini M4 dedicado, Xcode 16, Apple Silicon |
| **Scaleway Mac Mini** | ~$50-80/mes | Mac Mini M1/M2, ideal para CI/CD |
| **MacStadium** | ~$100+/mes | Más caro, pero enterprise |

**Veredicto**: Macly.io es la opción más barata (~$30/mes) con Mac Mini M4 dedicado. Te da un Mac real en la nube para compilar, firmar y hacer debug. No es gratis, pero es ~$1/día comparado con los $299/año de Shapr3D.

### Opción B: GitHub Actions + Self-Hosted Runner (GRATIS si tienes hardware)

Si tienes acceso a **cualquier Mac** (incluso uno prestado, un MacBook viejo, un Mac Mini de alguien):
1. Instalas `actions-runner` en ese Mac
2. Lo conectas a tu repo de GitHub
3. GitHub Actions corre builds iOS **gratis** en tu runner local
4. Tú pagas solo electricidad

**Guía**: https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners

### Opción C: Xcode Cloud (Apple — free tier limitado)

Apple ofrece **50 horas de compilación/mes gratis** en Xcode Cloud.
- Suficiente para builds de prueba
- Para desarrollo intensivo, se acaba rápido
- Ligado a tu cuenta de Apple Developer ($99/año)

### Opción D: Mac en Alquiler por Hora (~$2-5/hora)

Si solo necesitas compilar una vez cada 2-3 semanas:
- **MacinCloud**: $1.50/hora (Mac mini)
- **Amazon EC2 Mac**: ~$1.50/hora (dedicado)

---

## 2. Limitaciones Técnicas Confirmadas

### SPM + Metal Shaders — PROBLEMA CONOCIDO

Swift Package Manager **no soporta oficialmente** compilar shaders Metal.
- Issue abierto: https://github.com/swiftlang/swift-package-manager/issues/8930
- Solución: `MetalCompilerPlugin` (https://swiftpackageindex.com/schwa/MetalCompilerPlugin) — plugin SPM que compila `.metal` a `.metallib`
- Alternativa: compilar shaders aparte y embeberlos como recursos

### Satin — REPO INCORRECTO

Package.swift actual apunta a:
```
https://github.com/s1ddok/Satin.git (v0.3.0)
```

Pero el Satin oficial activo está en **Hi-Rez/Satin**: https://github.com/Hi-Rez/Satin
- El fork de `s1ddok` puede estar desactualizado o tener breaking changes
- **CRÍTICO**: Antes de compilar, hay que actualizar el Package.swift

---

## 3. Alternativa Web: Plan B Inmediato (FUNCIONA HOY EN IPAD)

Mientras se resuelve la compilación nativa, **podemos tener algo funcional en 72 horas**:

### Stack Propuesto: React Three Fiber (R3F) + Vite

```
scaffold_project(stack="react-vite", name="appforge-web", path="C:/Users/USUARIO/Projects/")
→ npm install three @react-three/fiber @react-three/drei
→ npm install react-router-dom zustand
```

### Capacidades en Fase 1 (3 días):
- Sketch 2D en plano (líneas, círculos, rectángulos)
- Extrusión a 3D
- Cámara orbital (dolly zoom, pan)
- Exportación STL/OBJ
- PWA instalable en iPad (sin App Store)

### Por qué Three.js en vez de competir con Metal:
- Metal es ~5-10x más rápido en GPU, pero para modelado CAD (no gaming), Three.js con WebGL es **suficiente**
- Miles de productos industriales se diseñan hoy en navegador (OnShape, Fusion 360 Web)
- La lógica CAD que desarrollemos en TypeScript se porta a Swift después
- **ANDROID FUNCIONA AUTOMÁTICAMENTE** — misma base de código

---

## 4. Apps Open Source para Estudiar y Mejorar

### Cadova — Swift DSL paramétrico
- https://github.com/tomasf/Cadova
- Swift DSL para modelado 3D paramétrico
- Inspiración directa para nuestra capa CAD de alto nivel

### Satin (Hi-Rez) — Framework Metal 3D
- https://github.com/Hi-Rez/Satin
- 3D graphics framework inspirado en Three.js
- **Debemos migrar de s1ddok a Hi-Rez**

### HelloMetal — Ejemplos Metal puros
- https://github.com/turner/HelloMetal
- 7 apps mínimas que ilustran: multi-pass rendering, ModelIO, arcball, OpenEXR
- Base de conocimiento para nuestros shaders

---

## 5. Ruta Recomendada

### Inmediato (días 1-3):
1. ✅ Scaffoldear app web con **React Three Fiber**
2. ✅ Implementar sketch, extrusión, export STL
3. ✅ Probar en iPad — Tangerine puede empezar a diseñar HOY

### Corto plazo (semanas 1-4):
4. ✅ Migrar Satin de `s1ddok` a `Hi-Rez/Satin`
5. ✅ Configurar Macly.io ($30/mes) o runner GitHub Actions
6. ✅ Compilar AppForge Studio en macOS cloud
7. ✅ Arreglar bugs críticos de render y animación

### Mediano plazo (meses 1-3):
8. ✅ Unificar pipeline Sculpt → Paint → Export
9. ✅ Portar la lógica CAD de TypeScript a Swift
10. ✅ Volver a la web como plataforma complementaria

---

## 6. Costos vs Alternativas

| Opción | Costo/mes | Tiempo hasta app funcional | iPad |
|--------|-----------|----------------------------|------|
| **Web R3F (Plan B)** | **$0** | **3 días** | **Sí (PWA)** |
| Macly.io | $30/mes | 4 semanas (con bugs) | Sí (nativa) |
| Shapr3D (competencia) | $299/año | Ya funciona | Sí |
| Blender + PC | $0 | Ya funciona | No (solo PC) |

### Conclusión: La ruta más inteligente es DUAL
**App web (3 días)** para diseñar productos de Tangerine AHORA, mientras paralelamente construimos la app nativa Swift/Metal para cuando esté lista. No tenemos que elegir — podemos hacer ambas.
