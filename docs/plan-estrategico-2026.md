# AppForge Studio — Plan Estratégico 2026
> Open-source CAD/CAM 3D unificado para iPad
> Fecha: 2026-05-07

## 1. Análisis Competitivo

### Shapr3D ($299/año)
- **Fortalezas**: Parasolid kernel (precisión industrial), timeline paramétrico, AR/Vision Pro, iPad/mac/Win
- **Debilidades**: NO tiene paint 3D, NO tiene sculpt, $299/año, curva de aprendizaje para paramétrico
- **Revenue estimado**: ~$15-20M/año (200K+ suscriptores)
- **Kernel**: Parasolid (licencia Siemens, cara)

### Fusion 360 ($545/año)
- **Fortalezas**: CAD/CAM/CAE/PCB integrado, generativo, simulación FEM, 5-axis CAM, nube
- **Debilidades**: No corre nativo en iPad, UI compleja (400-1200h aprendizaje), caro, requiere internet
- **Revenue**: ~$500M+/año (Autodesk)
- **Kernel**: Geometric Modeling Kernel propio

### Nomad Sculpt ($14.99)
- **Fortalezas**: Excelente sculpt en iPad, UI táctil, precio bajo
- **Debilidades**: Sin CAD, sin animación, sin export avanzado
- **Revenue**: ~$5-10M (pago único)

### Blender (gratis — donaciones $2M/año)
- **Fortalezas**: Modelado+sculpt+anim+render+VFX, comunidad masiva
- **Debilidades**: No corre en iPad, no es CAD paramétrico industrial

## 2. Ventaja Diferencial de AppForge

**"La única app iOS que unifica paint 3D + sculpt + CAD paramétrico + animación + export a impresión 3D"**

| Feature | Shapr3D | Fusion 360 | Nomad | Blender | AppForge |
|---------|---------|------------|-------|---------|----------|
| Paint 3D | ✗ | ✗ | ✗ | ✓ | **✓** |
| Sculpt | ✗ | ✗ | ✓ | ✓ | **✓** |
| CAD paramétrico | ✓ | ✓ | ✗ | parcial | **✓** |
| Animación | ✗ | ✗ | ✗ | ✓ | **✓** |
| Export 3D print | ✓ | ✓ | ✓ | ✓ | **✓** |
| iPad nativo | ✓ | ✗ | ✓ | ✗ | **✓** |
| Apple Pencil | ✓ | ✗ | ✓ | ✗ | **✓** |
| Open-source | ✗ | ✗ | ✗ | ✓ | **✓** |
| Precio | $299/año | $545/año | $14.99 | Gratis | **Gratis** |

## 3. Modelo de Monetización Open-Source

### Estrategia Principal: Publicidad No Intrusiva + Open-Core

Basado en eCPM iOS 2026:
- **Rewarded Video**: $10-15 eCPM — usuario ve un video a cambio de créditos para features premium (30s)
- **Interstitial**: $5-8 eCPM — entre cambios de modo (1 por sesión, máximo)
- **Banner nativo**: $0.50-1.50 eCPM — barra inferior sutil, no obstructiva

### Proyección de ingresos:
| Usuarios activos/mes | Revenue ads/año |
|---------------------|-----------------|
| 5,000 | $3,000 - $8,000 |
| 20,000 | $12,000 - $32,000 |
| 100,000 | $60,000 - $160,000 |

### Modelo Open-Core:
- **Core gratuito**: paint 3D + sculpt básico + CAD paramétrico + export STL/OBJ
- **Premium (suscripción mensual/App Store)**: $4.99/mes o $39.99/año
  - Export USDZ, STEP, IGES
  - Animación avanzada (morph targets, rigging)
  - Simulación física
  - Sin publicidad
  - Cloud sync

### Ingresos complementarios:
- **GitHub Sponsors**: meta $500/mes primer año
- **Corporate Sponsors**: hardware vendors (Shapr3D muestra anuncios de tiendas online)
- **Affiliate**: impresoras 3D, filamentos, tablets recomendadas
- **Donationware**: como Blender, PayPal/OpenCollective

## 4. Roadmap para Superar a Shapr3D + Fusion

### Fase 1 — Refuerzo del Core CAD (Q2 2026)
- [ ] Completar CAD timeline paramétrico (history-based, no solo constraint solver)
- [ ] Operaciones booleanas CSG con OCCTSwift
- [ ] Assembly modeling (jerarquía de partes)
- [ ] Sketch 2D completo (líneas, arcos, splines, cotas, relaciones)

### Fase 2 — Diferenciadores Clave (Q3 2026)
- [ ] **Paint 3D sobre CAD** — pintar directamente sobre modelos paramétricos
- [ ] **Sculpt paramétrico** — esculpir manteniendo historial CAD
- [ ] **IBL+PBR completo** — lighting realista (ya en progreso: diffuse irradiance + specular prefilter)
- [ ] Apple Pencil hover + tilt para sculpt/paint

### Fase 3 — Lo que Shapr3D/Fusion NO tienen (Q4 2026)
- [ ] **Real-time Collaboration** — editar el mismo modelo en vivo (WebRTC + CRDT)
- [ ] **AI-powered**: generación de modelos por texto, auto-retopology, auto-UV
- [ ] **XR CAD** — editar en AR/VR con Vision Pro + gestos
- [ ] **Export directo a impresoras 3D** (WiFi a Bambu Lab, Prusa, Creality)

### Fase 4 — CAM + Simulación (2027)
- [ ] CAM básico: 2.5-axis milling (como Fusion pero en iPad)
- [ ] Simulación FEM básica (stress analysis en GPU)
- [ ] PCB design básico (integración con KiCad)

## 5. Próximos Pasos Inmediatos

1. Completar IBL+PBR (diffuse irradiance, specular prefilter, BRDF LUT) — ya en TODO.md
2. Integrar texture maps en PBRMaterialUniforms (albedo/roughness/metallic/normal) — ya en TODO.md
3. Tangent space en shaders para normal maps
4. CAD-8 y CAD-9: verificar integración con CADModeView + conectar constraint manager
5. Beta testing con AltStore/TestFlight
6. Compilar en macOS para verificar Hi-Rez/Satin API compatibility
7. Generar .ipa para AltStore

## 6. Estrategia de Comunidad & Crecimiento

- **TikTok/Instagram Reels**: timelapses de modelado en iPad, comparativas directas Shapr3D vs AppForge
- **YouTube**: tutoriales, reviews, "cómo reemplacé Fusion360 con AppForge"
- **Reddit**: r/3Dprinting, r/iPadPro, r/cad — posts mostrando features
- **GitHub**: bien documentado, CI/CD, issues etiquetados para contribuidores
- **TestFlight**: beta abierta con comunidad de early adopters

## 7. KPIs

| Métrica | Mes 1 | Mes 6 | Mes 12 |
|---------|-------|-------|--------|
| Usuarios | 500 | 5,000 | 50,000 |
| Revenue ads | $50 | $1,000 | $8,000 |
| Suscripciones premium | 10 | 100 | 1,000 |
| GitHub stars | 100 | 1,000 | 5,000 |
| Contributors | 3 | 10 | 30 |
| Downloads TestFlight | 200 | 2,000 | 15,000 |
