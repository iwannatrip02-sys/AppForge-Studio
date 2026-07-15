# FORGE GLASS — El lenguaje visual de AppForge Studio

> v1.0 · 2026-07-15 · Agente DESIGN BIBLE
> Fuente única de verdad de la dirección de arte. Se lee junto a
> `DESIGN_SYSTEM.md` (los cómo exactos) y `docs/DISENO_INTERFAZ.md` (el contrato
> de gestos — SAGRADO). Las imágenes citadas viven en `moodboard/` (git-ignoradas).

---

## 0. Qué es esto y por qué existe

Este documento fija el SENTIMIENTO y la FILOSOFÍA. No copia ninguna interfaz:
extrae PATRONES de las referencias que Andrés eligió y los destila en un lenguaje
propio. Un usuario debe reconocer la familia estética (vidrio oscuro, datos vivos,
limpieza radical) y jamás poder decir "esto es un clon de tal app".

La app compite contra Shapr3D y debe verse y sentirse MEJOR. Mejor no significa
"más cosas": significa menos ruido, más claridad, y una firma material que ninguno
de los competidores tiene.

---

## 1. El nombre: **Forge Glass**

**Acero fundido visto a través de vidrio esmerilado.**

El taller sigue siendo frío y oscuro (la herencia de *Acero & Brasa* — ver §7). Pero
la interfaz ya no es metal opaco: es una lámina de **vidrio de laboratorio** flotando
sobre el modelo. El vidrio deja pasar la luz de lo que trabajas: cuando algo está
caliente (una operación activa), su calor **sangra a través del panel** como un
resplandor difuso. Cuando todo está en reposo, el vidrio es neutro, casi invisible,
y el modelo 3D es lo único que brilla.

Tres palabras que gobiernan cada decisión:

- **CLARO** — cero ruido. Un dato por sitio. Espacio negativo generoso. Si dudas si
  algo sobra, sobra. (Es lo que Andrés pidió: "lo limpio y organizado".)
- **VIDRIO** — todo panel flota y es translúcido. Nunca una caja opaca sobre el
  viewport. El chrome no compite con el modelo; lo enmarca. (Es lo que Andrés pidió:
  "las semitransparencias, las opacidades".)
- **VIVO** — el color es información, no decoración. Solo lo que responde al tacto o
  reporta un estado se ilumina. El resto es grafito silencioso.

> Lema de trabajo: **"El vidrio no decora el modelo. Lo enmarca y deja pasar su calor."**

---

## 2. Los 5 patrones nucleares

Cada patrón nace de una referencia concreta y declara en qué NOS DIFERENCIAMOS.

### Patrón 1 — Vidrio esmerilado sobre negro OLED (`ref-06`, `ref-07`, `ref-01`)

**Inspiración:** las tarjetas de `ref-06` y `ref-07` flotan sobre un fondo OLED casi
puro; son paneles de vidrio esmerilado (`.ultraThinMaterial`) con un borde de 1px
apenas perceptible y una sombra suave que las despega del fondo. El fondo lleva un
**punteado sutil** (dot-grid) que da textura sin ruido.

**Nuestra versión:** el fondo OLED es el VIEWPORT 3D real, no un wallpaper. El
dot-grid se convierte en el **grid del suelo del taller**, que ya existe y se
desvanece al hacer zoom. Los paneles son de vidrio pero NUNCA superan al modelo en
brillo: el modelo (render PBR/IBL) es siempre el punto más luminoso de la pantalla.

**Diferenciación:** las apps de referencia son dashboards estáticos; nosotros ponemos
vidrio sobre una escena 3D viva y en movimiento. El blur tiene función: ves la
geometría a través del panel, nunca la tapas.

### Patrón 2 — Resplandor de color que sangra a través del vidrio (`ref-07`, `ref-04`)

**Inspiración:** en `ref-07` las tarjetas de salud tienen un **glow rojo/verde
ambiental** que se filtra por detrás del vidrio esmerilado — el color no está en el
borde ni en un icono, está en la luz que atraviesa el material. `ref-04` hace lo mismo
con un gradiente cálido difuso bajo una tarjeta translúcida.

**Nuestra versión:** ESTE es el reemplazo del "templado" de Acero & Brasa. Cuando una
operación está activa (push/pull, boolean, fillet), el panel de parámetros irradia un
**glow brasa difuso** desde su interior. Al confirmar, el glow **se enfría a acero** y
se disuelve en ~400ms. La firma de la app pasa de "borde que cambia de color" a "el
vidrio se enfría". Es más sutil, más caro de imitar, y más bello.

**Diferenciación:** en las referencias el glow es decorativo (estética de bienestar).
En Forge Glass el glow SIEMPRE significa "esto está caliente / editándose ahora". Es
la regla de oro de Acero & Brasa, ahora expresada en luz translúcida en vez de bordes.

### Patrón 3 — El número vivo, grande y monoespaciado (`ref-01`, `ref-07`, `ref-15`)

**Inspiración:** `ref-01` y `ref-07` muestran cifras enormes (`73`, `5.7%`, `113.1`)
con la unidad en pequeño al lado, en un peso ligero, dominando la tarjeta. El dato ES
el héroe del panel. `ref-15` (Shapr3D) pone la cota `14,3mm` como una píldora inline
pegada a la geometría.

**Nuestra versión:** toda medida en vivo (distancia de push/pull, radio de fillet,
grosor de shell) se muestra como **número grande monoespaciado en brasa**, con la
unidad en gris pequeño. Aparece EN el viewport, junto a la cara que se edita —nunca en
un panel lejano— siguiendo el contrato de "parámetros junto al efecto".

**Diferenciación:** las referencias usan cifras para lucir; nosotros para PRECISIÓN.
Monoespaciado siempre (una cota que baila de 9.9 a 10.0 es amateur). El número es
brasa solo mientras se edita; al confirmar se enfría a acero (dato sólido, confirmado).

### Patrón 4 — Chips-píldora y rails de herramienta legibles (`ref-05`, `ref-08`..`ref-12`)

**Inspiración:** `ref-05` usa **pills** (`Karma`, `Credits`, `Money`) y tarjetas con
un icono en círculo arriba-izquierda y una flecha de acción arriba-derecha: jerarquía
instantánea. Shapr3D (`ref-08`..`ref-12`) despliega **flyouts** con icono + label en
pastilla oscura desde un rail lateral estrecho.

**Nuestra versión:** adoptamos el rail izquierdo estrecho con **flyout de icono +
label** de Shapr3D (es el patrón correcto para descubribilidad táctil en iPad), pero
los flyouts son de VIDRIO Forge Glass, no cajas opacas grises. Los selectores de modo
y opción son chips-píldora translúcidos con estado brasa.

**Diferenciación:** Shapr3D es gris utilitario y su chrome opaco roba pantalla.
Nuestros rails y flyouts son vidrio: ligeros, translúcidos, con el modelo visible
detrás. Descubribilidad de Shapr3D + limpieza de las referencias premium.

### Patrón 5 — Densidad tranquila y jerarquía por espacio, no por líneas (`ref-05`, `ref-03`, `ref-06`)

**Inspiración:** en `ref-05`/`ref-06` las tarjetas se separan por **aire**, no por
divisores; la jerarquía la dan el tamaño y el peso, no las cajas. `ref-03` agrupa
métricas de crédito con enorme calma visual pese a mostrar mucho dato.

**Nuestra versión:** cero divisores duros. Los grupos se separan por espaciado del
grid de 4pt. Labels de grupo en 10pt UPPERCASE tracking amplio (voz de instrumento de
precisión). Máximo dos pesos tipográficos por pantalla; el énfasis lo da el color de
estado, no el negrita.

**Diferenciación:** el CAD tradicional (Fusion360) amontona con bordes y rejillas.
Nosotros heredamos la CALMA de las referencias premium — un instrumento profesional
que respira. Ese es el "MEJOR que Shapr3D" perceptual: no más features, menos ruido.

---

## 3. Qué tomamos y qué rechazamos de cada familia de referencias

| Referencia | TOMAMOS | RECHAZAMOS |
|---|---|---|
| `ref-01/02` (rondesignlab, deportivo) | glass oscuro, número grande, acento verde para "dato vivo", sparklines | verde como acento de marca (chocaría con brasa) → verde queda solo para EJE-Y / éxito |
| `ref-03/04/05` (crédito, iPad claro) | pills, tarjetas de icono+flecha, calma, gradiente cálido difuso | modo claro como default (somos dark-first taller); gradientes multicolor decorativos |
| `ref-06` (dashboard iPad limpio) | dot-grid sutil, grid de tarjetas aireado, tipografía tranquila | fondo blanco; densidad de dashboard (somos viewport-first) |
| `ref-07` (salud, glow bleed) | **el patrón clave**: glow de color sangrando por el vidrio = estado | glow puramente estético; múltiples glows a la vez |
| `ref-08..15` (Shapr3D) | rail estrecho + flyout icono/label, cota-píldora inline, section-view HUD, gizmo con HUD pegado | azul corporativo; paneles opacos grises; chrome que ocupa >15% |

**Regla de no-copia:** ninguna pantalla de AppForge debe reproducir el LAYOUT de una
referencia. Tomamos gramática (vidrio, glow-estado, número vivo, pills, aire), no
composiciones.

---

## 4. Sentimiento objetivo

Cuando alguien abra AppForge por primera vez debe sentir:

1. **"Esto es un instrumento, no una app de consumo."** Seco, preciso, oscuro,
   silencioso hasta que actúo.
2. **"Está impecablemente limpio."** No sé dónde mirar primero porque no hay ruido:
   miro mi modelo.
3. **"Reacciona a mí."** Toco algo y se enciende; confirmo y se enfría. La interfaz
   respira con mi trabajo.
4. **"Se ve caro."** El vidrio, el glow difuso y el espacio negravo dicen producto
   premium sin gritar.

Anti-sentimientos (si aparecen, es un bug de diseño): juguetón, tutorial, colorido,
amontonado, corporativo-genérico, "otro CAD de escritorio en tablet".

---

## 5. Cómo se usa este lenguaje (contrato de proceso)

1. **Nunca se improvisa UI.** Todo componente nuevo se arma con tokens y patrones de
   `DESIGN_SYSTEM.md`.
2. **Si un componente necesario ROMPE el sistema, primero se actualiza el sistema**
   (este doc + `DESIGN_SYSTEM.md` + `design_tokens.json`), con justificación, y LUEGO
   se construye. El código nunca va por delante del sistema.
3. **El contrato de gestos (`DISENO_INTERFAZ.md`) es superior a la estética.** Ningún
   patrón visual puede justificar violar "tocar geometría = actuar / tocar vacío =
   cámara" ni el chrome ≤15%.
4. **Una sola cosa caliente a la vez.** Regla heredada de Acero & Brasa, ahora en luz:
   dos glows brasa simultáneos = bug.

---

## 6. La estrella polar

> **Un ingeniero de Shapr3D, viendo un screenshot de AppForge, debe pensar dos cosas
> a la vez: "reconozco esta familia" y "esto se ve mejor que lo nuestro".**

---

## 7. Veredicto de identidad: ¿muere *Acero & Brasa*? — DECISIÓN DE ANDRÉS

El brief lo pide explícito: si la dirección de las referencias exige evolucionar o
reemplazar *Acero & Brasa* (`docs/IDENTIDAD_FORGE.md`), no matarla en silencio. Aquí
la comparación honesta.

### Lo que las referencias piden vs. lo que Acero & Brasa dice

| Eje | Acero & Brasa (actual) | Referencias de Andrés | ¿Conflicto? |
|---|---|---|---|
| Fondo | OLED oscuro, taller de noche | OLED oscuro (`ref-01/07`) | **Ninguno** — coinciden |
| Material del chrome | `ultraThinMaterial` + borde + sombra ("vidrio de taller", ya escrito en §5 de IDENTIDAD) | vidrio esmerilado translúcido | **Ninguno** — ya era vidrio |
| Acento | brasa `#FF7A45` = "editándose ahora" | verde/rojo como "dato vivo"; glow que sangra | **Parcial** — el mecanismo cambia (borde→glow), el acento cálido se conserva |
| Firma | *templado*: borde brasa→acero al confirmar | glow difuso que se enfría | **Evolución**, no conflicto |
| Claridad | ya pedía cero decoración | limpieza radical, aire | **Ninguno** — se refuerza |

### Veredicto: **EVOLUCIÓN, no reemplazo. Acero & Brasa VIVE dentro de Forge Glass.**

Acero & Brasa no era el problema: su alma (taller frío + calor = estado, cero
decoración, brasa solo donde responde al tacto) es EXACTAMENTE lo que las referencias
premium hacen con su glow-de-estado. Lo que cambia es la **piel**, no el esqueleto:

- **Se conserva** el 100% de la narrativa material (acero=reposo, brasa=caliente,
  steel/clay para B-rep vs malla, "una sola cosa caliente", ejes RGB, voz seca).
- **Se conserva** la paleta base OLED y los tokens brasa/steel/clay.
- **Evoluciona** la firma: el *templado* deja de ser un borde que cambia de color y
  pasa a ser un **glow que sangra por el vidrio y se enfría** (Patrón 2). Más sutil,
  más premium, más difícil de copiar.
- **Se añade** lo que faltaba y las referencias aportan: el número-vivo grande
  monoespaciado (Patrón 3), los pills/flyouts de vidrio (Patrón 4), la densidad
  tranquila por aire (Patrón 5), el dot-grid como grid de suelo (Patrón 1).

### Punto abierto para Andrés (única decisión pendiente)

Las referencias `ref-01/07` usan **verde** como acento de "dato vivo". En Forge Glass
el verde queda reservado al **eje Y** y a **éxito de sistema** (para no romper la
convención RGB de ejes ni competir con la brasa). Si Andrés quisiera acercarse más al
look verde de las referencias, la alternativa sería un **acento dual**: brasa para
"editándose", verde-menta para "dato confirmado/medido en reposo". Mi recomendación:
**mantener brasa como acento único** por coherencia con la narrativa de la forja; el
verde como acento secundario solo si tras verlo en device se siente frío. Decides tú.

**Nombre propuesto para el sistema evolucionado: Forge Glass (Acero & Brasa, ola de
vidrio).** Sustituye la dirección estética; conserva el corazón.
