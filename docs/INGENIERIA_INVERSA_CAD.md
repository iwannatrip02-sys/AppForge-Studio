# INGENIERÍA INVERSA CAD — Shapr3D + Fusion 360 → AppForge
> 2026-07-09 · Cómo funciona CADA herramienta por dentro (input→estado→preview→
> commit→historial), cómo se interconectan, qué roba-y-mejora de Fusion 360, y
> el camino verificado al MOTOR DE COHETE. Anclado a APIs OCCT confirmadas
> @v1.8.8. Este doc es el spec de implementación del módulo CAD completo.

---

## 0. EL PATRÓN UNIVERSAL (la ingeniería inversa del flujo Shapr3D)

Toda herramienta de Shapr3D es la MISMA máquina de estados:
```
ACTIVAR → PEDIR ENTRADA (selección/toque, con hint en banner)
        → PREVIEW EN VIVO (geometría fantasma + número editable)
        → COMMIT (tap fuera / botón / soltar) → HISTORIAL (re-editable)
        → LA HERRAMIENTA SIGUE ACTIVA para repetir (no vuelve a Select)
```
Reglas que se deducen usándola:
1. **La selección es un PARÁMETRO de la herramienta, no un modo previo**: puedes
   activar Extruir y LUEGO tocar la cara; o seleccionar y luego activar. Ambos
   órdenes funcionan. → Nuestro `activate()` debe aceptar selección pre/post.
2. **Preview fantasma SIEMPRE** (translúcido) antes del commit; el número vive
   junto a la geometría, editable.
3. **Nada te expulsa de la herramienta** al terminar: puedes encadenar (hacer
   5 agujeros seguidos). Escape = tap en vacío o Select.
4. **Todo es re-editable** desde Historial (paramétrico adaptativo).

## 1. SKETCH — ingeniería inversa por herramienta

| Herramienta | Cómo funciona por dentro | API nuestra |
|---|---|---|
| Línea/Arco AUTO | Un solo tool. Traza recto = línea; un quiebre rápido del trazo al final = conmuta a arco tangente. Cada segmento se ancla al anterior (cadena). Cotas de longitud/ángulo en vivo, editables al vuelo. | cadena ✓; arco tangente: `Wire.arc` ✓ (falta conmutador) |
| Spline | 2 modos: AJUSTE (pasa por los puntos que tocas) y CONTROL (polígono de control). Puntos arrastrables después. | `Wire.bspline(controlPoints:)` ✓ + `cubicBSpline` ✓ |
| Rectángulo | Diagonal (2 taps) o centro. Cotas W×H vivas. | ✓ hecho |
| Círculo/Elipse | centro→radio; elipse con 2 radios. | `Wire.circle` ✓; elipse: revisar API |
| Polígono | N lados paramétrico (triángulo default). | `Wire.polygon` ✓ |
| Desfasar (offset 2D) | Selecciona curva/cadena → offset paralelo con distancia viva. | Curve2D/offset APIs — revisar |
| Recortar (trim) | Pasas el dedo sobre los tramos a borrar; corta en INTERSECCIONES. Exige grafo de intersecciones del sketch. | motor propio (grafo 2D) |
| Constraints | Se INFIEREN al dibujar (H/V/paralela/tangente/coincidente) y se muestran como badges; el solver re-resuelve al arrastrar puntos. | ConstraintEngine existe; falta inferencia+badges+drag |
| Regiones | El sketch ES un grafo plano: toda ÁREA CERRADA (por intersecciones, no solo perfiles individuales) se vuelve región sombreada tocable. | motor propio (planar graph → caras) — CLAVE |
| **Dibujar sobre CARA** | Tocas cara plana → se vuelve plano de sketch (la cámara se alinea con "Normal a boceto"); las aristas del sólido se PROYECTAN como referencias. | plano desde `Face.normal`+origen ✓; proyección: `Drawing.project` ✓ |

**Interconexión maestra**: región cerrada → (Extruir | Revolucionar | Sweep-perfil
| Loft-sección). La región es EL puente sketch→3D. Sin motor de regiones por
intersección, el sketch se queda en "perfiles sueltos" (estado actual).

## 2. SÓLIDOS — ingeniería inversa por herramienta

| Herramienta | Por dentro | API @v1.8.8 |
|---|---|---|
| Extruir | Cara/región + drag de flecha normal; AMBOS lados; "hasta objeto" (tope en cara de otro cuerpo); si arrastras dentro de un sólido = RESTA automática (¡genial!) | `extrude` ✓ / boss-pocket via pushPull ✓; hasta-objeto: `prismUntilFace` ✓ |
| Revolucionar | Perfil + EJE (tocas arista/línea/eje del sketch); ángulo vivo con arco fantasma | `revolve(profile:axisOrigin:axisDirection:angle:)` ✓ (falta elegir eje tocando) |
| Barrido | Perfil ⊥ + CURVA dibujada (spline/cadena) | **`sweep(profile:along:)` ✓ VERIFICADO** |
| Transición (loft) | 2+ perfiles ordenados; opcional curvas guía | **`loft(profiles:solid:ruled:)` ✓ VERIFICADO** |
| Vaciado | Cuerpo + grosor; TOCAS las caras que quedan abiertas | `shelled(thickness:openFaces:)` ✓ (falta elegir cara tocando) |
| Desfasar cara | Cara + distancia (mueve la cara, el sólido se adapta) | `offsetFace` ✓ / pushPull ✓ |
| Chaflán/Empalme | Arista(s)/cadena + radio vivo; cadenas tangentes se seleccionan juntas | fillet por arista ✓; chamfer por arista: `chamferedTwoDistances` ✓ (falta faceIndex vecino — vía BRepGraph) |
| **Agujero** | Tap en cara → agujero ⊥ con Ø y profundidad (o pasante) | **`drilled(at:direction:radius:depth:)` ✓ LISTO** |
| Dividir cuerpo | Plano/cara de corte → 2 cuerpos | `split` APIs — revisar sección |
| Reemplazar cara | Cara A toma la superficie de cara B | `replaceFace` — revisar |
| Proyectar | Aristas/siluetas de un cuerpo → curvas en un sketch | `Drawing.project` ✓ |
| Envolver y grabar | Curvas del sketch envueltas sobre superficie curva (grabado) | avanzado — fase 3 |

## 3. LO QUE FUSION 360 TIENE Y SHAPR3D NO (nuestro superset)

Adoptables de alto valor para iPad (ordenados):
1. **Agujero PARAMÉTRICO con estándares** (pasante/ciego, avellanado, roscado
   M3-M12) — Fusion lo clava. Tenemos `drilled` + **ThreadFeatures (ISO 60°V)
   ✓ VERIFICADO** → agujeros ROSCADOS reales. Shapr3D ni siquiera rosca.
2. **Patrón DE FEATURES en el historial** (no solo de cuerpos): patrón circular
   de agujeros sobre una brida = 1 feature editable. Requiere historial
   paramétrico re-ejecutable (nuestra BRepHistory + ops con parámetros).
3. **Planos de construcción ricos**: offset, ángulo, 3 puntos, tangente,
   punto-medio. (`ConstructionLayer` ✓ existe en el kernel.)
4. **Cotas CONDUCTORAS** (editas la cota → la geometría se regenera) — el
   corazón paramétrico. Fase: tras el motor de regiones.
5. **Timeline con supresión** de features (probar variantes).
6. **Análisis**: sección en vivo ✓ (Section2D existe), interferencias entre
   cuerpos (`polygonInterference` ✓), draft analysis.
7. **pipeShell con LEY** (sección variable a lo largo — Fusion no lo expone
   así de directo): **toberas y conductos regenerativos de cohete** ✓.

## 4. EL EXAMEN FINAL: MOTOR DE COHETE (ingeniería inversa del objetivo)

Qué exige modelar un motor cohete (cámara+tobera+inyector+brida) y qué nos falta:

| Pieza del motor | Herramientas necesarias | Estado |
|---|---|---|
| Contorno cámara+tobera (campana) | Spline de AJUSTE + Revolucionar | spline API ✓ (falta tool) · revolve ✓ |
| Pared delgada | Vaciado con cara abierta elegible | shell ✓ (falta pick de cara) |
| Canales regenerativos | pipeShellWithLaw a lo largo de la campana | API ✓ (fase 3) |
| Brida con N agujeros | Círculo + Extruir + **Agujero** + **Patrón circular de features** | drilled ✓ HOY · patrón feature: fase 2 |
| Agujeros roscados | ThreadFeatures ISO | API ✓ (fase 2) |
| Inyector (placa multi-orificio) | Agujero + patrón circular ×N | drilled ✓ + patrón |
| Ensamble | Alinear + posicionar exacto | fase 2 |
| **RENDIMIENTO** (miles de features, millones de tris) | LOD por distancia, culling frustum, instancing de patrones, decimación en órbita, tesselado adaptativo (deflection por tamaño en pantalla), edges como línea nativa (no tubos) | workstream RENDIMIENTO (medir primero con FPS HUD opcional) |

## 5. ORDEN DE IMPLEMENTACIÓN DEL MÓDULO CAD (fases)

**F-CAD-1 (ya en curso)**: rail+flyouts ✓, selección directa multi ✓, sketch v1 ✓.
**F-CAD-2 — "el puente perfecto" (siguiente)**:
  a. **Agujero** (drilled): tap cara → Ø/profundidad vivas → encadenable. HOY.
  b. **Spline de ajuste** (bspline) como 4ª herramienta de dibujo.
  c. **Barrido real**: perfil + última curva dibujada (sweep verificado).
  d. **Transición (loft)** entre 2 perfiles cerrados.
  e. Revolucionar con ÁNGULO editable + eje = eje Z o arista tocada.
  f. Vaciado con cara abierta TOCADA.
**F-CAD-3 — regiones y paramétrico**: motor de regiones por intersección
  (grafo planar), cotas conductoras, constraints visibles, dibujar sobre cara
  con proyección de referencias, patrón de features, agujero roscado.
**F-CAD-4 — pro**: dividir cuerpo, reemplazar cara, planos de construcción
  ricos, alinear, análisis de interferencias, envolver/grabar.
**Transversal**: patrón universal de herramienta (§0) aplicado a TODAS: la
herramienta pide su entrada, preview fantasma, número editable, encadenable.
