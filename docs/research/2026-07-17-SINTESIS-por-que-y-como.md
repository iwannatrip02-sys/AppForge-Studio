# SÍNTESIS — Por qué se siente que no avanzamos, y el camino corregido

*2026-07-17. Cruza los 4 informes de `docs/research/` (estado real del repo, metodología solo-dev, kernels/motores, código de sketchers reales) contra las 3 restricciones declaradas por el fundador: CAD potente en 3-4 semanas, presupuesto $0, Fase 1 = CAD con bases holísticas.*

---

## 1. Por qué estamos fallando (las causas, con evidencia)

**1.1 Construimos en amplitud y fachada, no en profundidad.** El patrón de fracaso #1 documentado en todos los post-mortems de software grande en solitario. Evidencia nuestra: ~90 documentos de planes en `docs/`, un catálogo donde ~80% de las herramientas eran placebo (auditoría 2026-07-11), un god-file de 3.759 líneas (`CADModeView`), y capas de código sin integrar (el hit-testing de cuerpos 3D existe — 333 líneas — pero nunca se cableó a la UI: la capacidad no existe para el usuario aunque el código sí).

**1.2 La definición de "hecho" era débil.** "CI verde" y "el código existe" no son "un usuario lo usa y funciona". Esto ya se corrigió (regla device-first del 15/07 + contrato de Fase 1), y es la corrección más importante de todas: es la misma que Shapr3D aplicó desde el día 1 (István Csanády verificaba en iPad desde el primer commit).

**1.3 Doble sistemas y espiral de reescritura.** Dos sistemas de sketch en paralelo con semánticas contradictorias (el legacy `CADSketchEngine` sigue vivo junto al kernel nuevo). Cada sistema paralelo duplica el costo de todo lo que toca.

**1.4 La vara de medir estaba mal puesta.** Comparábamos contra la superficie completa de un producto de 10 años (Shapr3D 2014→hoy) en vez de medir capacidades de usuario completas de punta a punta. Con esa vara, TODO proyecto se siente estancado siempre. Dato duro: Shapr3D v1 tardó **4 años de su fundador** con Parasolid y D-Cubed comprados; Plasticity, **2 años full-time** de un dev experto con Parasolid; Onshape, 3+ años de 5 ex-SolidWorks con capital VC. Nuestro sentimiento de "no avanzar" es en gran parte un error de vara, no (solo) de ejecución.

**Lo que NO está fallando:** la elección de OCCT (único kernel profesional gratuito que existe; Shapr3D puede igualarse ~90% con él y la brecha actual es de UX, no de kernel), el render PBR, la persistencia/STEP, y la arquitectura del kernel de sketch nuevo — cuyo modelo de topología compartida (PointID único por esquina) es objetivamente superior en táctil al modelo de FreeCAD/SolveSpace (drag sin solver = cero latencia).

## 2. Decisiones técnicas que la investigación cierra (no reabrir)

| Decisión | Veredicto | Fuente |
|---|---|---|
| Kernel 3D | OCCT se queda; no hay alternativa a $0 | motores-kernels |
| Solver de restricciones | Snap-first basta para v1; para v2 un **mini-solver propio** (~1.500 líneas Swift, Newton-Raphson, 8 restricciones). libslvs es GPL (bloqueado legal); planegcs LGPL es engorroso en iOS por el linking estático | mecanicas-sketch |
| Robustez OCCT | Envolver booleanos con **fuzzy tolerance** + **ShapeFix** antes/después de toda operación (el aprendizaje que a FreeCAD le costó años) | motores-kernels |
| Historial paramétrico | NO atacar el Topological Naming Problem (10+ años de bugs en FreeCAD); usar re-aplicación de lista de features | motores-kernels |
| Regiones | Segunda pasada de cierre tolerante cuando el grafo dé 0 regiones con sketch visualmente cerrado | mecanicas-sketch |
| Mecánicas a copiar ya | Commit H/V si ángulo < 10°; bit `isConstruction`; trim con las intersecciones ya existentes; entrada numérica al dibujar (la brecha #1 de sensación vs Shapr3D) | mecanicas-sketch |
| Diferenciador barato futuro | HLR de OCCT (planos técnicos 2D) — ya expuesto en OCCTSwift | motores-kernels |

## 3. La aritmética honesta contra el horizonte de 3-4 semanas

Paridad total con Shapr3D: **18-24 meses** (dos informes independientes coinciden). Eso NO cabe en 3-4 semanas y prometerlo sería un botón falso a escala de proyecto.

**Lo que SÍ cabe en 3-4 semanas** (con agentes IA en paralelo y foco absoluto): el **core loop CAD profundo** — la vara de la v1 de Shapr3D, no la de su año 10:

> *Un usuario diseña una pieza mecánica real en el iPad en <30 minutos, con gusto: dibuja con snap/guías/cotas numéricas → cierra perfiles → extruye/corta/redondea con preview vivo → exporta STEP válido. Y NADA de lo visible falla.*

### Semana 1 — Sketch sólido (cerrar el contrato Fase 1)
- Retirar `CADSketchEngine` legacy (un solo sistema).
- Entrada numérica al dibujar (longitud/ángulo/radio editables en vivo) — la brecha #1.
- Arco en toolbar, spline 2 modos en UI, trim, geometría de construcción, commit H/V.
- Verificación del usuario en iPad por entrega (cadencia actual de betas).

### Semana 2 — El puente 2D→3D sin costuras
- **Selección de cuerpos/caras/aristas integrada** (bloqueador T0 de la auditoría).
- Extrude/corte/booleanos con preview vivo continuo bajo el dedo + fuzzy booleans + ShapeFix.
- Doble tap = perímetro; multiselección de aristas → fillet/chamfer selectivos.

### Semana 3 — Sensación profesional
- Pasada FORGE GLASS real sobre sketch + toolbar reorganizado (fuera herramientas de arriba).
- Gizmos rediseñados (nunca tapados), aristas nítidas, rendimiento (nunca se pega).
- Export STEP verificado contra receptor real (Fusion/FreeCAD).

### Semana 4 — Endurecimiento y cierre
- Pruebas de usuario reales (el fundador + 1-2 externos si es posible) sobre 3 piezas de referencia.
- Golden files geométricos de las 3 piezas (regresión automática).
- Todo bug visible de la lista se cierra antes de features nuevas.

**Después (v2, siguientes meses):** mini-solver propio, historial paramétrico por re-aplicación, HLR/planos, y las fases del proyecto másico (sculpt/manufacture) sobre el documento único ya diseñado en `WORKSPACES_Y_MANUFACTURE.md` — la base holística ya está pensada; no hay que construirla toda ahora, solo no violarla.

## 4. Reglas de proceso (de los casos que sí funcionaron)

1. **Un vertical slice por entrega**, medido como capacidad de usuario verificada en iPad — nunca "módulo terminado".
2. **Congelar todo lo que no sea el slice** (nada de sculpt/animación/manufacture hasta cerrar el core loop CAD).
3. **Cero documentos de plan nuevos** — este y el contrato de Fase 1 son los únicos vivos.
4. **La vara pública del proyecto**: las 3 piezas de referencia diseñables de punta a punta, no el número de herramientas.
5. **El fundador aprende 4 cosas** (en este orden, ~8h total): arquitectura por capas como contratos; tests como especificación ejecutable; leer un diff; exigir evidencia (video/screenshot de device, no "CI verde"). Con eso dirige con poder real.
