# Crítica del estado actual — 9 capturas iPad vs. Forge Glass

> v1.0 · 2026-07-15 · Agente DESIGN BIBLE
> Crítica DURA de las 9 capturas reales del iPad (`ipad_*.png`) contra
> `DESIGN_SYSTEM.md` v1.0. Cada pantalla lleva UI-Score (0–10) por 5 ejes.
> No es un juicio del código ni del esfuerzo: es la brecha perceptual contra
> "mejor que Shapr3D". Tono deliberadamente severo — para eso se pidió.

## Método de puntuación

5 ejes, 0 (roto) a 10 (nivel Forge Glass), promediados:
**Jerarquía · Ruido visual · Consistencia · Touch-UX · Profesionalismo**.

---

## Veredicto global

La app HOY es un **CAD de escritorio comprimido en un iPad**, no el instrumento de
vidrio de `VISION.md`. El viewport ya es oscuro y respeta el "modelo como héroe" (bien),
pero **todo el chrome traiciona el sistema**: barras horizontales apiladas arriba
estilo desktop, panel de elementos OPACO y minúsculo, rail de iconos sin label ni
estado, cero vidrio real, cero glow de estado, brasa mal usada (llena la barra inferior
en reposo, cuando debería marcar SOLO lo caliente). Densidad de información amateur:
texto microscópico, nombres truncados (`Cylinder_23TA...`), controles de 24–28pt
imposibles de tocar. **La distancia a Shapr3D es grande y perceptible en <5s.**

**Promedio global: 3.4 / 10.**

---

## Pantalla por pantalla

### 1. `ipad_v1.png` — vista general con 3 primitivas
El chrome superior son **~5 barras horizontales apiladas** (título+fecha, tabs
Modelar/Historial, iconos, Undo/Redo, "48 ago") — layout de escritorio, viola §2 (rail
izquierdo + barras efímeras). El panel de elementos es una caja **opaca** flotando
arriba-izquierda, minúscula, con nombres truncados. Rail izquierdo = iconos grises sin
label, sin estado activo visible. Un botón ⚙︎ **suelto** a la derecha, sin anclaje.
Barra inferior con 6 iconos **todos en brasa** (brasa mal usada: en reposo no debe
haber calor). "Snap" y "Mediciones" flotan sin agrupar.
- Jerarquía 3 · Ruido 4 · Consistencia 3 · Touch-UX 3 · Profesionalismo 4 → **3.4**

### 2. `ipad_shot1.png` — primitiva naranja gigante
Una malla **naranja brillante** llena media pantalla. Esto es **brasa como material del
modelo**, prohibido: brasa = "editándose ahora", jamás el color de un objeto en reposo.
Rompe la regla de oro (§1.2) de la forma más visible posible. El fondo se ve lavado por
el resplandor naranja. Un ingeniero de Shapr3D lo marca como error en 1 segundo.
- Jerarquía 3 · Ruido 2 · Consistencia 2 · Touch-UX 3 · Profesionalismo 2 → **2.4**

### 3. `ipad_shot2.png` — cubo + flyout de primitivas
El flyout "PRIMITIVAS" (Caja/Esfera/Cilindro/Cono/Toro) es una **caja opaca gris**, no
vidrio (§3). Aparece pegado al rail sin sombra ni jerarquía. El cubo se ve limpio (el
render PBR funciona), pero el flyout parece de otra app. Rail activo marcado con brasa
en un icono — bien conceptualmente, pero el resto del chrome no acompaña.
- Jerarquía 4 · Ruido 5 · Consistencia 3 · Touch-UX 4 · Profesionalismo 4 → **4.0**

### 4. `ipad_prim.png` — fila de 5 primitivas + lista
El panel de elementos muestra 6 filas con nombres **truncados** (`Box_870D50AT`,
`Cylinder_B718...`) — ilegibles, sin icono de tipo (⬡/〰), sin jerarquía. El flyout de
primitivas de nuevo opaco. La escena limpia, pero la lista es el eslabón más débil:
densidad de información de nivel "output de debug".
- Jerarquía 3 · Ruido 4 · Consistencia 3 · Touch-UX 3 · Profesionalismo 3 → **3.2**

### 5. `ipad_pushpull.png` — operación push/pull
Aparece un grupo "SKETCH" y un flyout "OFFSET" con opciones
(Push/Pull/Agujero/Extruir/Redondear/Chaflán/Vaciar) — otra vez **caja opaca**. Hay una
cota inline sobre el modelo (`1.11 × 3.86`) — **buen instinto** (§11.8) pero sin estilo
píldora, texto minúsculo, sin material. El número NO es el héroe (debería ser
`type.numberLive` brasa grande). No hay glow de estado en la operación activa: la
firma de la app está ausente justo donde más importa.
- Jerarquía 3 · Ruido 4 · Consistencia 4 · Touch-UX 3 · Profesionalismo 3 → **3.4**

### 6. `ipad_fillet.png` — fillet aplicado
Geometría redondeada correcta; el render se ve bien. Pero el chrome es idéntico al
resto: sin barra de parámetro de vidrio, sin número vivo, sin glow. La cota inline
(`1.11 × 3.86`) reaparece igual de débil. No hay confirmación visual (templado) de que
el fillet se aplicó — el usuario no recibe la firma "se templó".
- Jerarquía 4 · Ruido 5 · Consistencia 4 · Touch-UX 4 · Profesionalismo 4 → **4.2**

### 7. `ipad_chamfer.png` — chamfer, fila de primitivas
Rail izquierdo **sin ningún estado activo** visible (todos los iconos grises apagados),
imposible saber qué herramienta está seleccionada. Lista de elementos crece a 8 filas
truncadas, ya rozando el borde inferior del panel opaco. La escena limpia pero el
chrome comunica cero.
- Jerarquía 3 · Ruido 4 · Consistencia 3 · Touch-UX 3 · Profesionalismo 3 → **3.2**

### 8. `ipad_shell.png` — shell con barra de parámetro superior
Aquí SÍ hay una barra de parámetro ("Grosor", slider, `0.090`, botón **Aplicar** en
brasa) — pero está **arriba del todo**, lejos de la cara que se edita (viola "parámetros
junto al efecto", `DISENO_INTERFAZ.md §2`). El botón Aplicar en brasa es lo único
correcto. Coexisten DOS flyouts abiertos (SKETCH + PRIMITIVAS) = ruido. El valor
`0.090` es texto plano pequeño, no número vivo. Sin glow.
- Jerarquía 3 · Ruido 3 · Consistencia 3 · Touch-UX 4 · Profesionalismo 3 → **3.2**

### 9. `ipad_bool.png` — boolean intersección
Barra de estado de operación arriba ("Booleana · Intersección · Selecciona la pieza A")
con botón "Ejecutar" **deshabilitado gris** — la guía textual es buena idea, pero vive
en el chrome superior desktop, no como HUD sobre la geometría. Sin resaltado brasa de la
pieza que se debe seleccionar (debería estar caliente). Lista truncada de nuevo.
- Jerarquía 4 · Ruido 5 · Consistencia 4 · Touch-UX 4 · Profesionalismo 4 → **4.2**

---

## Problemas transversales (afectan a TODAS las capturas)

1. **Chrome de escritorio, no de vidrio.** Barras horizontales apiladas arriba en vez
   de rail izquierdo + barras efímeras (§2). El patrón está escrito como deuda #4 en
   `DISENO_INTERFAZ.md` — sigue sin resolverse.
2. **Cero vidrio real.** Todo panel/flyout es opaco. El pilar #1 de Forge Glass, y de lo
   que Andrés pidió ("semitransparencias, opacidades"), está ausente.
3. **Cero glow de estado.** La firma de la app (§3.4) no existe en ninguna operación.
4. **Brasa mal usada.** Llena la barra inferior en reposo (`ipad_v1`) y colorea un
   objeto entero (`ipad_shot1`). Debe marcar SOLO lo caliente, una cosa a la vez.
5. **Densidad amateur.** Texto de 8–10px real, nombres truncados, controles <44pt,
   labels sueltos. Viola §4, §5, §8 y el touch mínimo.
6. **Número no es héroe.** Las cotas existen pero minúsculas; falta `type.numberLive`.
7. **Estado de herramienta invisible.** Rail sin selección clara (§9 sin implementar).

---

## Top 10 de arreglos (priorizados por impacto perceptual)

| # | Arreglo | Impacto | Esfuerzo | Por qué primero |
|---|---|---|---|---|
| 1 | **Convertir TODO panel/flyout a `GlassPanel`** (receta §3.1) | Máximo | M | Es el pilar de la identidad y lo que Andrés pidió; transforma la percepción global de golpe. |
| 2 | **Quitar la brasa del objeto/reposo** (`ipad_shot1`, barra inferior) — brasa solo en lo caliente | Máximo | S | Corrige la violación más flagrante de la regla de oro; se detecta en 1s. |
| 3 | **Rediseñar el chrome: rail izquierdo 56pt + barras efímeras**, matar las barras apiladas superiores | Máximo | L | Deuda #4; sin esto seguimos siendo "CAD de escritorio en tablet". |
| 4 | **`ParamBar` de vidrio junto al efecto con glow de estado** (mover el de shell abajo, cerca de la cara) | Alto | M | Recupera "parámetros junto al efecto" + estrena la firma visual. |
| 5 | **`LiveNumber` grande monoespaciado brasa** para toda cota/valor en vivo | Alto | S | El número pasa a ser héroe (Patrón 3); percepción premium inmediata. |
| 6 | **Firma de templado** (glow `ember→steel` 400ms + haptic) al aplicar cada operación | Alto | M | Da la confirmación que hoy falta (fillet/bool/shell aplican en silencio). |
| 7 | **Estado activo claro en el rail** (icono `ember` `.medium` + fill 15%, §9) | Alto | S | Hoy es imposible saber qué herramienta está activa. |
| 8 | **`ElementRow` legible**: icono de tipo ⬡/〰, nombre sin truncar, `type.body`, hover | Medio | S | La lista es el eslabón más amateur; barato de arreglar. |
| 9 | **Tipografía a la escala §4** (subir tamaños, mono en cifras, group labels UPPERCASE) | Medio | S | Elimina la sensación de "output de debug". |
| 10 | **Guía de operación como `InlineHUD` sobre la geometría + pieza objetivo caliente** (`ipad_bool`) | Medio | M | Lleva la instrucción al modelo (contrato de gestos) y usa brasa con sentido. |

**Los 3 primeros solos** (vidrio + brasa disciplinada + rail/chrome) cierran la mayor
parte de la brecha con Shapr3D. El resto pule hacia "mejor que Shapr3D".
