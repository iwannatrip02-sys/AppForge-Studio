# CATÁLOGO DE HERRAMIENTAS — estado real, verificado herramienta por herramienta
> 2026-07-09 · Auditoría honesta contra el código + feedback de device. Este doc es
> EL checklist maestro hacia la beta: cada herramienta con su estado, cómo debe
> funcionar a nivel Shapr3D/Nomad, y su conexión con las demás. Se actualiza en
> cada ola. Leyenda: ✅ funciona · 🟡 parcial/mediocre · ❌ no existe o placebo.

---

## 1. CAD — estado actual del toolbar

| Herramienta | Estado | Realidad verificada | Para nivel Shapr3D falta |
|---|---|---|---|
| Seleccionar | 🟡 | Cara→highlight brasa ✓; arista→barra Redondear ✓ | Selección de CUERPO completo (tap y queda seleccionado con outline), puntos/vértices, multi-selección, deselección clara, selección persistente entre herramientas |
| Mover | 🟡 nuevo | Drag directo sobre cuerpo → mueve en plano de cámara + bake B-rep (Ola Transformar, pendiente device) | Gizmo con ejes X/Y/Z restringibles, snapping a grilla, valores numéricos en vivo, mover caras/aristas (no solo cuerpos) |
| Rotar | 🟡 nuevo | Drag horizontal → rota eje Y + bake | Gizmo de anillos (3 ejes), pivote elegible, ángulos exactos, global vs local |
| Escalar | 🟡 nuevo | Drag vertical → escala uniforme + bake | Escala por eje, desde cara, valores exactos |
| Push/Pull | ✅ | Tap cara → slider distancia → boss/pocket B-rep real | Drag-en-cara EN VIVO (v2), número editable con teclado, preview antes de aplicar |
| Extruir | 🟡 | Solo desde sketch con perfil; flujo confuso | Extruir región de sketch con drag directo, extruir cara existente, ambos lados, hasta-objeto |
| Corte (loop cut) | ❌ | Ejecuta al tap sobre índices fijos — resultado impredecible ("formas extrañas") | Corte real con plano/línea interactiva y preview |
| Bisel | ❌ | Igual: opera sobre índices 0-1 hardcodeados — placebo | Bisel de arista seleccionada con radio en vivo (ya existe Redondear selectivo — CONSOLIDAR: bisel = chaflán por arista) |
| Unir/Restar/Intersecar | ✅ | Flujo A/B + booleana B-rep OCCT exacta | Preview coloreado antes de aplicar, boolean por gesto (arrastrar un cuerpo dentro de otro), mantener originales opcional |
| Redondear | ✅ | Global (toolbar) + SELECTIVO por arista tocada (único en tablet junto a Shapr3D) | Radio variable, cadenas de aristas tangentes, preview |
| Chaflán | 🟡 | Solo global (todas las aristas) | Por arista (API OCCT lo permite: chamferedTwoDistances), asimétrico |
| Vaciar | ✅ | Shell B-rep real (cara mayor abierta) | Elegir la cara abierta tocándola, grosor por cara |
| Barrer | 🟡 | Genera geometría pero con path HARDCODEADO | Barrer perfil real a lo largo de curva dibujada |
| Loft | ❌ oculto | LoftEngine espera Wire; puente no existe (F3) | Loft entre 2+ perfiles de sketch |
| Medir | ✅ nuevo | Dos toques sobre el modelo → distancia mm exacta | Medir arista (longitud), cara (área), ángulos, cotas persistentes en pantalla |
| Primitivas (5) | ✅ | B-rep reales, colocadas en fila | Tamaño/posición al crear (drag para dimensionar como Shapr3D), más primitivas (tubo, cuña, prisma) |

## 2. SKETCH — el corazón, y el más deficiente (P1 absoluto)

| Pieza | Estado | Para nivel Shapr3D falta |
|---|---|---|
| Línea/Círculo/Rect/Arco | ❌ inutilizable | Trazo EN TIEMPO REAL (hoy no se ve mientras dibujas), radios/dimensiones en vivo, círculo por centro+radio, rect por 2 esquinas, arco por 3 puntos |
| Regiones cerradas | ❌ | Detección de ciclos → sombreado tocable → tap = extruir (LA mecánica de Shapr3D) |
| Constraints | ❌ UI | Motor existe (ConstraintEngine); falta inferencia visible (paralela/perpendicular/tangente como badges tocables) |
| Planos de trabajo | ❌ | Dibujar en plano XY/XZ/YZ o sobre CARA de un sólido (fundamental); datum planes |
| Cotas/dimensiones | ❌ | Dimensión editable al dibujar (tap número → teclado) |
| Recortar/Extender | ❌ | Trim/extend entre curvas |
| Spline | ❌ | Curva por puntos de control con Pencil |
| Proyección | ❌ | Proyectar aristas/curvas de un sólido al plano de sketch |

## 3. SCULPT — motor conectado, experiencia por construir

| Pieza | Estado | Para nivel Nomad falta |
|---|---|---|
| 10 deformers | ✅ | Miniaturas del efecto en el selector, más pinceles (clay buildup, dam standard, stamp/alphas) |
| Radio/Fuerza laterales | ✅ | Curva de falloff editable |
| Pincel inverso | ✅ | — |
| Simetría | ✅ eje X | Ejes elegibles, radial |
| Presión Pencil | ✅ | Curva de presión configurable |
| Voxel remesh | 🟡 | Slider de resolución + conteo antes de aplicar (hoy botón fijo en Híbrido) |
| Dyntopo | ❌ cableado | Engine existe; conectar al stroke con toggle |
| Máscaras | ❌ | Pintar máscara, invertir, blur, extract — la mitad del workflow pro |
| Multires | ❌ | Niveles de subdivisión navegables |
| Capas morph | ❌ | LayerManager existe; falta delta+slider |
| Esfera inicial en modo Sculpt | ❌ | El cubo CAD no es el lienzo natural de escultura |

## 4. VISOR / VISUALIZACIÓN

| Pieza | Estado | Falta |
|---|---|---|
| Sombreado real | ✅ nuevo | Materiales visibles (matcaps baratos primero), AO |
| Grilla universal | ✅ nuevo | Ejes X/Y/Z coloreados en el origen, tamaño adaptativo al zoom |
| Wireframe / Rayos-X | ❌ | Modos de visualización (sólido/aristas/transparente) — pedido explícito |
| Aristas de sólidos | ❌ | Edge overlay acero (identidad ⬡) — los sólidos deben mostrar sus aristas |
| Sombra de contacto | ❌ | Sombra suave bajo el objeto (percepción de apoyo) |
| ViewCube | 🟡 | Caras tocables (frente/lado/arriba), estética premium |

## 5. ESTRUCTURA DE APP

| Pieza | Estado | Falta |
|---|---|---|
| Inicio/Proyectos | ❌ | Galería de documentos (crear/abrir/duplicar/eliminar), persistencia en disco |
| Panel de objetos | ❌ | Árbol jerárquico izquierdo (cuerpos/grupos/visibilidad/aislar) con badges ⬡/〰 |
| Historial | 🟡 | Registra; falta panel LATERAL plegable + time-travel por tap |
| Configuración | ❌ | Unidades, zurdo/diestro, sensibilidades, tema |
| Export | 🟡 | Formatos reales; falta detalle por formato, AR realista (materiales PBR en USDZ) |
| Capas / jerarquía dual | ❌ | Diseño pendiente: cómo conviven cuerpos CAD y mallas sculpt en un árbol (Forge Flow §3.2) |

## 6. Orden de ataque (actualiza BLUEPRINT §3.6 con la realidad del device)
1. **Transformar en device** (esta ola — validar feel y sensibilidades).
2. **Selección de cuerpo + outline** (sin esto ninguna herramienta se siente anclada).
3. **SKETCH PROFESIONAL** (sección 2 completa — la promesa de la app; varias olas).
4. Wireframe/aristas/rayos-X + ejes en grilla (visualización pro).
5. Panel de objetos + historial lateral.
6. Consolidar herramientas placebo (Corte/Bisel → flujos reales o fuera del toolbar).
7. Sculpt pro (máscaras → dyntopo → multires).
8. Inicio/proyectos + configuración.
9. Patrones (lineal/circular), mirror, offset de cara, draft (catálogo Shapr3D fase 2).

*Regla de siempre: herramienta que no alcance su fila "✅" con flujo claro, no se
muestra en el toolbar. Placebo detectado = placebo retirado.*
