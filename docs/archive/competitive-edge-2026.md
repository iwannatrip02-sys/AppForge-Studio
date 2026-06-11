# Competitive Edge Analysis — AppForge Studio vs Shapr3D + Fusion 360
> Fecha: 2026-05-07 | Autor: Gotchi (NanoAtlas agent)

## Resumen Ejecutivo

Shapr3D domina CAD paramétrico en iPad ($299/año, kernel Parasolid).
Fusion 360 Mobile es SOLO visor/markup (NO editor real en iPad).
Nomad Sculpt tiene escultura pero CERO CAD paramétrico.
**Nadie en iPad combina: sculpt paramétrico + CAD completo + animación + AI generativo.**

AppForge Studio puede ocupar este vacío con una estrategia de **features unificadoras**.

---

## Análisis de Competencia Directa

### Shapr3D ($299/año)
- **Fortalezas:** Kernel Parasolid (Siemens), modelado paramétrico + directo, iPad/Mac/Windows, STEP import/export, histórico de operaciones
- **Debilidades:** NO sculpt, NO animación, sin AI, sin collaboration en tiempo real
- **Target:** Ingenieros CAD profesionales
- **GAP explotable:** $299/año es caro para hobbyists/makers

### Fusion 360 Mobile (gratis con suscripción $545/año)
- **Fortalezas:** Modelado paramétrico, CAM, simulation, sheet metal, generativo
- **Debilidades:** Mobile es **SOLO visor/markup** — no se puede editar en iPad
- **Target:** Ingenieros mecánicos profesionales
- **GAP explotable:** CERO edición real en iPad

### Nomad Sculpt ($14.99 one-time)
- **Fortalezas:** Escultura digital intuitiva, buena para concept art
- **Debilidades:** Sin CAD paramétrico, sin export profesional (solo OBJ/STL básico)
- **Target:** Artistas 3D, concept artists
- **GAP explotable:** $14.99 es barato pero limitadísimo — no escala a producto

### Tinkercad (gratis, web/iPad)
- **Fortalezas:** Booleanas complejas, fácil para principiantes
- **Debilidades:** Sin sculpt, sin animación, solo web básico
- **Target:** Principiantes, educación
- **GAP explotable:** No profesional, no scalable

### Part3D (lanzado marzo 2026)
- **Fortalezas:** Modelado paramétrico + bridge directo a impresora 3D en iPad
- **Debilidades:** Nuevo, pocas features, sin sculpt/animación
- **Target:** Makers 3D printing
- **GAP explotable:** Novato, se puede superar rápido

---

## 8 Features Diferenciales para Superarlos

### D1. Escultura Paramétrica (UNIQUE - nadie lo tiene)
Combinar el sculpt engine con constraints paramétricos en la misma sesión.
- Sculpt una forma orgánica → convertir a superficie paramétrica → aplicar constraints
- Ejemplo: Esculpir un mango de herramienta → definir distancia constraint → CAD lo mantiene
- **Implementación:** `GeometryConstraintManager` ya conectado a solver; falta hook en sculptor

### D2. CAD + Sculpt + Animación + Export 3D Printing (UNIFIED)
Cuatro modos en una sola app sin cambiar de herramienta.
- Modo CAD: constraints paramétricos, sketch, extrusion
- Modo Sculpt: brushes, symmetry, dynamesh
- Modo Animation: keyframes, rigging básico
- Export: STL/OBJ/STEP con manifold validation
- **Valor:** Reemplaza Shapr3D ($299) + Nomad ($15) + Blender (gratis pero sin iPad)

### D3. AI Generative Design (UNIQUE)
Sugerir geometrías basadas en constraints funcionales.
- Input: "Necesito un bracket que soporte 5kg entre dos puntos a 10cm"
- Output: geometría generativa tipo topology optimization
- **Inspiración:** Fusion 360 Generative Design (solo desktop, $545/año)
- **Implementación:** Modelo local on-device (CoreML) para sugerencias básicas

### D4. Real-Time Collaboration (parcial en Shapr3D)
Edición multiusuario en tiempo real del mismo modelo.
- Similar a Google Docs para modelos 3D
- Shapr3D tiene share básico pero no edición simultánea
- **Implementación:** WebSocket + Operational Transform sobre geometría

### D5. Sheet Metal Design (solo en Fusion 360 desktop)
Doblar, desdoblar, calcular desarrollos de chapa metálica.
- Fusion 360 tiene sheet metal pero solo en desktop/mac
- **GAP:** Nadie lo tiene en iPad

### D6. AR Preview con LiDAR (parcial)
Ver el modelo 3D en espacio real usando ARKit + LiDAR del iPad Pro.
- Shapr3D tiene AR viewer básico
- **Mejora:** Medir en AR, editar dimensiones desde AR, ver tolerancias

### D7. Fotogrametría Directa (UNIQUE)
Importar mallas 3D desde fotos tomadas con el iPad (LiDAR + cámara).
- Usar ARKit Scene Reconstruction + RealityKit
- Convertir scan a mesh editable con sculpt/CAD
- **Nadie lo tiene integrado con CAD paramétrico**

### D8. Topology Optimization (solo Fusion 360 desktop)
Optimizar geometría para mínimo peso con constraints de carga.
- Algoritmo BESO (Bi-directional Evolutionary Structural Optimization)
- **GAP:** Solo disponible en Fusion 360 ($545/año) desktop

---

## Prioridad de Implementación

| Feature | Esfuerzo | Impacto | Competencia | Prioridad |
|---------|----------|---------|-------------|-----------|
| D1. Escultura Paramétrica | Alta | Máximo | Nadie | **P1** |
| D2. App Unificada | Media | Máximo | Parcial | **P1** |
| D3. AI Generative Design | Alta | Alto | Solo desktop | **P2** |
| D6. AR Preview | Media | Medio | Parcial | **P2** |
| D8. Topology Optimization | Alta | Medio | Solo desktop | **P3** |
| D5. Sheet Metal | Alta | Medio | Solo desktop | **P3** |
| D7. Fotogrametría | Media | Medio | Nadie | **P3** |
| D4. Real-Time Collab | Muy alta | Alto | Parcial | **P4** |

---

## Roadmap Recomendado

### Fase 1 (Q2-Q3 2026) — Unificación + Escultura Paramétrica
- [ ] Completar integración CAD (items 22-38 del TODO)
- [ ] Conectar solver paramétrico con sculpt engine (D1)
- [ ] UI unificada con 4 modos (D2)

### Fase 2 (Q4 2026) — Diferenciación
- [ ] AR Preview con LiDAR (D6)
- [ ] AI Generative Design básico (D3)
- [ ] Topology Optimization (D8)

### Fase 3 (2027) — Expansión
- [ ] Sheet Metal Design (D5)
- [ ] Fotogrametría Directa (D7)
- [ ] Real-Time Collaboration (D4)

---

## Conclusión

AppForge Studio NO compite con Shapr3D o Fusion 360 en su propio terreno.
**Compita en el espacio que NADIE ocupa:** la app unificada de creación 3D en iPad
que combina escultura paramétrica, CAD, animación y fabricación.

Estrategia: "El canifláutico de la creación 3D" — una app que hace todo,
bien, sin cambiar de herramienta, a un precio menor que Shapr3D solo.
