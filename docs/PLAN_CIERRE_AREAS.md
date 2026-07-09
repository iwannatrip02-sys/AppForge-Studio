# PLAN DE CIERRE POR ÁREAS — taxonomía completa Shapr3D → AppForge
> 2026-07-09 · Investigación de la organización REAL de herramientas de Shapr3D
> (manual + screenshot del usuario) mapeada contra nuestro estado. Define EL
> PROCESO para cerrar cada área de forma sólida antes de abrir la siguiente.
> Complementa CATALOGO_HERRAMIENTAS.md (estado por herramienta).

---

## 0. EL PROCESO DE CIERRE (obligatorio por área)

Un área se declara CERRADA solo cuando cumple los 6 pasos:
1. **Inventario**: lista completa de piezas del área (de este doc) con estado real.
2. **Implementación**: cada pieza funciona con su flujo completo (no placebo).
3. **Conexiones**: verificadas contra las demás áreas (selección→herramienta→
   historial→render→export). Escribir las conexiones en el commit.
4. **Tests**: oráculos exactos por pieza (volúmenes, longitudes, matrices).
5. **Verificación en device**: screenshot/syslog por el agente (túnel) + feel
   del usuario. Sensibilidades calibradas.
6. **Acta de cierre**: actualizar CATALOGO (✅) + este doc + BRAIN.

Regla dura: NO se abre un área nueva con la anterior a medias. Los bugs de
áreas cerradas se atienden de inmediato (regresión = el área se reabre).

---

## 1. CÓMO ORGANIZA SHAPR3D SUS HERRAMIENTAS (investigación)

Shapr3D NO tiene un toolbar plano: tiene **4 espacios** (rail izquierdo del
screenshot) y dentro de Modelado agrupa por INTENCIÓN. El menú es contextual:
muestra herramientas según la selección actual (1 arista → Desfasar arista,
Plano en curva; 1 cuerpo → Dividir, Patrón…).

### Espacios
| Espacio | Contenido |
|---|---|
| **Modelado** | sketch + sólidos + transformaciones (el taller) |
| **Visualización** | materiales, apariencia, render |
| **Dibujos** | planos 2D acotados (nuestro DXF/PDF ya existe) |
| **Elementos** | árbol jerárquico: carpetas, cuerpos, bocetos, patrones |

### Grupos de MODELADO (taxonomía completa del manual)
**A. Boceto (sketch)** — sobre plano o cara:
Línea, Arco (3 modos), Círculo, Elipse, Rectángulo (centro/esquinas), Polígono,
Ranura (slot), Spline (control/through points), Texto, Punto de construcción,
Fillet 2D, Recortar (trim), Dividir curva, Desfasar (offset 2D), Proyectar
(aristas 3D→plano), Espejo 2D, Cotas + restricciones automáticas e
inferencia visual (paralela/perpendicular/tangente/coincidente).

**B. Añadir/quitar material (features)**:
Extruir (drag directo desde región, ambos lados, hasta objeto), Revolución,
Barrido (sweep por curva real), Solevado (loft entre perfiles), Tubería (pipe),
Vaciar (shell con cara abierta tocable), Desfasar cara (offset face),
Inclinar cara (draft), Redondear/Chaflán (arista/cadena/cara, radio variable),
Agujero (hole con estándares).

**C. Booleanas / cuerpo**:
Unir, Restar, Intersecar (con preview), Dividir cuerpo (split por plano/cara),
Combinar/separar, Escalar (uniforme y NO uniforme).

**D. Duplicación estructural** *(los "efectos" que menciona el usuario — NO
mutan la forma base, la multiplican)*:
**Patrón lineal**, **Patrón circular**, **Espejo (mirror 3D)**, Copiar+pegar
con transformación. Viven como grupos en el árbol de Elementos (editables).

**E. Posicionamiento**:
Mover/Girar (gizmo completo: 3 flechas + 3 arcos + plano), Trasladar (exacto
numérico), Girar alrededor de eje/arista, **Alinear** (cara-a-cara), Anclar.

**F. Referencia y medición**:
Planos de construcción (offset/ángulo/3 puntos/en curva), Ejes, Medir
(distancia/ángulo/área/volumen persistente), Sección (vista de corte en vivo),
Aislar, Rayos X.

### Lecciones estructurales
1. El toolbar plano NUestro debe evolucionar a **grupos por intención**
   (Boceto / Formar / Combinar / Duplicar / Posicionar / Referencia).
2. El **menú contextual por selección** (nuestro selectionBar) es el camino
   correcto — Shapr3D lo confirma: la selección filtra el catálogo entero.
3. Los patrones/espejo son OBJETOS del árbol (editables después), no ops
   destructivas → exigen el panel de Elementos (ÁREA 4) antes de implementarse
   bien.

---

## 2. ÁREAS Y SU CONTENIDO EXACTO (con estado)

### ÁREA 1 — Selección y manipulación 🟡 EN CIERRE (esta semana)
- [x] Selección cuerpo→cara/arista (2 taps) + outline brasa + barra contextual
- [x] Métricas vivas (longitud/área/volumen exactos)
- [x] Gizmo v1: flechas 3 ejes, drag restringido, rotación por eje tocado
- [x] Cámara: orbit + pan relativo + zoom + **roll 2 dedos** (tercer eje) +
      doble tap encuadre isométrico
- [ ] Gizmo v2: arcos de rotación VISUALES + manija de plano + global/local
- [ ] Trasladar/Rotar EXACTO (campo numérico al tocar el valor)
- [ ] Alinear (cara-a-cara) · Escala no uniforme (vía transformed(matrix:) 12)
- [ ] Multi-selección (2º cuerpo con tap = añadir) → habilita booleanas por selección
- [ ] Calibración de sensibilidades EN DEVICE (feel)

### ÁREA 2 — Sketch profesional ❌ (la promesa; 3-4 tramos)
Todo el grupo A de arriba. Orden interno: planos de trabajo (XY/XZ/YZ + sobre
cara) → trazo EN VIVO con Línea/Círculo/Rect/Arco reales y cotas al dibujar →
regiones cerradas sombreadas → **extruir región con drag** → constraints
visibles → spline/offset/trim → proyectar.

### ÁREA 3 — Formar y combinar (features B-rep) 🟡
- [x] Push/Pull, Redondear (global+arista), Chaflán global, Vaciar, booleanas A/B
- [ ] Extruir cara existente · Revolución real · Sweep por curva del sketch
- [ ] Desfasar cara · Draft · Dividir cuerpo · Chaflán por arista · Agujero
- [ ] Booleanas desde multi-selección + preview coloreado
- (Loft/pipe cuando exista el puente Wire — depende del ÁREA 2)

### ÁREA 4 — Elementos y estructura ❌
Panel árbol izquierdo (cuerpos/bocetos/carpetas/visibilidad/aislar, badges
⬡/〰) → historial lateral con time-travel → **patrones lineal/circular +
espejo 3D como objetos del árbol** → inicio/proyectos con persistencia →
configuración.

### ÁREA 5 — Visualización ❌→🟡
- [x] Sombreado real, grilla con ejes, outline
- [ ] Rayos X / wireframe / aristas de sólidos siempre visibles (acero ⬡)
- [ ] Sección en vivo · Aislar · Materiales por cuerpo (drag&drop) · Matcaps
- [ ] Sombra de contacto · ViewCube con caras tocables

### ÁREA 6 — Sculpt nivel Nomad 🟡 (motor ✓, experiencia ❌)
Máscaras → dyntopo cableado → multires → capas morph → pinceles con miniatura
→ remesh con slider → esfera inicial en modo Sculpt.

### ÁREA 7 — Export/Render/AR 🟡
Export con detalle por formato · AR Quick Look con PBR real (materiales que
responden a luz de la escena) · Render con iluminación editable.

## 3. Orden de ejecución
1 (cerrar ya) → 2 (sketch, el grande) → 3 → 5 → 4 → 6 → 7.
Cada tramo: implementación amplia → CI → verificación por el agente en device
→ release única del área.
