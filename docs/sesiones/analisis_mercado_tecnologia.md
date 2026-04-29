# Análisis de Mercado y Tecnología — AppForge Studio

## Fecha
2026-04-27

## Resumen Ejecutivo
El mercado de modelado 3D móvil está valorado en $7.6B (2025) con crecimiento CAGR de 13.9%. Existe una oportunidad clara en Android (vacío de apps de sculpting de calidad) y en un modelo de negocio de pago único justo.

## Competencia Directa

### Shapr3D
- **Precio**: $239/año o $19.99/mes
- **Plataforma**: iOS, iPadOS, macOS, Windows
- **Fortalezas**: CAD preciso, Apple Pencil optimizado, exportación STL/OBJ
- **Debilidades**: Precio alto (quejas recurrentes en Reddit, cracks circulando), orientado a CAD no a sculpting artístico
- **Modelo**: Suscripción obligatoria

### Nomad Sculpt
- **Precio**: $19.99 (pago único)
- **Plataforma**: iOS, iPadOS, Android
- **Fortalezas**: Dynamic topology, PBR rendering, Apple Pencil support, 80+ pinceles, interfaz intuitiva
- **Debilidades**: Sin animación, sin exportación directa a impresión 3D, limitado en Android vs iOS
- **Modelo**: Pago único — muy bien recibido

### ZBrush for iPad
- **Precio**: $200/año (requiere Creative Cloud)
- **Plataforma**: iPadOS (requiere A10+)
- **Fortalezas**: 200+ pinceles, herencia del estándar de la industria, ZRemesher
- **Debilidades**: Solo iPad, requiere hardware reciente, suscripción cara, sin Android
- **Modelo**: Suscripción a Creative Cloud

### Feather 3D
- **Precio**: Pago único (sin suscripción)
- **Plataforma**: iOS, iPadOS
- **Fortalezas**: Herramientas de dibujo 3D, pago único, interfaz limpia
- **Debilidades**: Sin Android, menos features que Nomad, comunidad pequeña
- **Modelo**: Pago único

### Forger
- **Precio**: $9.99 (pago único)
- **Plataforma**: iOS, iPadOS
- **Fortalezas**: Precio bajo, dynamesh, exportación OBJ/STL
- **Debilidades**: Sin actualizaciones recientes, sin Android, features básicos
- **Modelo**: Pago único

## Oportunidades de Mercado

1. **Android**: Vacío enorme — no hay app de sculpting 3D de calidad comparable a Nomad o ZBrush. La mayoría son apps básicas de modelado CAD.
2. **Modelo de negocio justo**: Pago único o freemium generoso. Las quejas sobre suscripciones caras (Shapr3D, ZBrush) son recurrentes.
3. **Exportación a impresión 3D**: Ninguna app líder ofrece exportación optimizada para impresión 3D (watertight meshes, soportes automáticos).
4. **Animación + Sculpting**: Ninguna app móvil combina sculpting y animación 3D en un solo producto.
5. **Multiplataforma real**: Ninguna solución cubre iOS + Android + Windows + macOS con la misma calidad.

## Tecnologías Clave

### iOS — Metal + Satin
- **Metal**: API gráfica de Apple, madura para 3D rendering, soporte nativo en todos los dispositivos iOS
- **Satin**: Framework Swift que abstrae shaders, geometría y rendering para Metal. Código abierto, activo en GitHub.
- **ModelIO**: Framework nativo de Apple para importar/exportar assets 3D (OBJ, STL, glTF, FBX). Sin dependencias externas.
- **Lottie**: Animaciones vectoriales exportables, útil para UI animada.

### Android — OpenGL ES + Kool
- **OpenGL ES**: API gráfica estándar en Android, soporte universal
- **Kool**: Motor 3D Kotlin para Android con OpenGL ES. Código abierto.
- **Assimp**: Librería C++ para import/export de 40+ formatos 3D (STL, OBJ, glTF, FBX, Collada).

### Multiplataforma
- **Flutter**: flutter_cube (básico, sin sculpting), flutter_gl (experimental). Inmaduro para 3D complejo.
- **React Native**: react-native-3d-model-view (solo visualización), expo-three (básico). Limitado.
- **Recomendación**: Renderer nativo en cada plataforma (Metal/iOS, OpenGL ES/Android), lógica de negocio compartida en Kotlin Multiplatform o C++.

## Brechas Técnicas Identificadas

1. **No hay framework multiplataforma maduro** para 3D painting/sculpting. Habría que construir el renderer desde cero en cada plataforma.
2. **Dynamic topology en móvil**: Solo Nomad lo implementa bien. Requiere optimización de compute shaders.
3. **PBR rendering en tiempo real**: Factible en Metal y OpenGL ES moderno, pero requiere shaders personalizados.
4. **Exportación a impresión 3D**: Watertight mesh generation, soportes automáticos, slicing básico — ninguna app lo hace bien.
5. **Animación 3D en móvil**: Rigging y skinning en tiempo real es complejo, pero factible con compute shaders.

## Recomendación Estratégica

### Fase 1 — MVP iOS (3-4 meses)
- **Stack**: Swift + Satin + ModelIO
- **Features**: Sculpting básico (pinceles, dynamesh), PBR rendering, exportación STL/OBJ
- **Modelo**: Pago único ($14.99) con trial de 7 días
- **Diferenciación**: Interfaz intuitiva, rendimiento optimizado para Apple Silicon

### Fase 2 — Android (3-4 meses después)
- **Stack**: Kotlin + Kool + Assimp
- **Features**: Portar sculpting engine, misma UX
- **Diferenciación**: Primera app de sculpting 3D de calidad en Android

### Fase 3 — Diferenciación (6+ meses)
- **Features**: Exportación optimizada para impresión 3D, animación básica, Lottie para UI animada
- **Multiplataforma**: Compartir lógica de negocio

## Conclusión
La oportunidad es real y está validada por datos de mercado. Android es el mayor gap. El modelo de pago único es viable (Nomad lo demuestra). La tecnología existe pero requiere construir el renderer nativo. Recomiendo empezar con iOS por madurez del ecosistema y menor fragmentación.