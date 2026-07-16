# ARQUITECTURA DE RENDIMIENTO — "Nunca se pega"
> 2026-07-10 · El pilar técnico no-negociable: AppForge carga y edita un COHETE
> COMPLETO (motor + cableado, miles de features, millones de triángulos) sin
> un solo frame perdido — en el mismo iPad donde Shapr3D se pega con una vasija.
> Este doc explica POR QUÉ se pegan los demás y QUÉ arquitectura lo evita.
> Benchmark de referencia permanente: el modelo del motor de cohete
> (INGENIERIA_INVERSA_CAD.md §4… ahora "examen final" también de rendimiento).

---

## 0. POR QUÉ SE PEGA SHAPR3D (diagnóstico del enemigo)

Shapr3D usa Parasolid (kernel de Siemens, licencia). Sus cuelgues con modelos
densos delatan 4 decisiones de arquitectura que NO debemos copiar:

1. **Kernel acoplado al hilo de UI**: al editar, la operación booleana/fillet
   corre y la UI espera. Con B-reps densos (la "vasija de muchos polígonos" =
   superficie con miles de caras spline) cada op tarda segundos → beachball.
2. **Re-teselado total**: cambias una feature y re-tesela TODO el cuerpo, no
   solo las caras afectadas.
3. **Sin LOD real en viewport**: renderizan la teselación de máxima calidad
   siempre, aunque el cuerpo ocupe 40px en pantalla.
4. **Historial lineal re-ejecutado completo**: editar la feature 3 de 200
   re-ejecuta las 197 siguientes aunque no dependan de ella.

Nuestra ventaja estructural: **CADHistoryTree ya es un DAG con snapshots B-rep
por nodo** — el recompute selectivo (solo el subárbol afectado, arrancando del
snapshot del padre) está en el modelo de datos desde el día 1. Falta hacerlo
cumplir en todas las rutas.

## 1. LOS 5 CONTRATOS (reglas duras, verificables, no aspiraciones)

| # | Contrato | Presupuesto | Cómo se verifica |
|---|---|---|---|
| C1 | El main thread NUNCA ejecuta kernel OCCT | 0 llamadas OCCT en main salvo lecturas triviales | assert en debug (`dispatchPrecondition(.notOnQueue(.main))` en OCCTBridge) |
| C2 | Toda op >100ms es async con preview fantasma + cancelable | commit visible ≤100ms (optimista); resultado real llega después | signpost por operación |
| C3 | Input táctil nunca espera al render ni al kernel | latencia trazo Pencil ≤16ms (predicted touches ~9ms) | Instruments/hang detector |
| C4 | 60fps mínimo SIEMPRE (120 ProMotion objetivo) durante órbita, aunque haya un recompute corriendo | frame time p99 <16.6ms | FPS HUD (debug) + MetricKit (campo) |
| C5 | Abrir proyecto = interactivo <2s aunque el archivo tenga 500 cuerpos | primer frame navegable <2s; el resto carga en streaming | signpost de cold-open |

**Regla de proceso**: MEDIR PRIMERO. Ninguna optimización sin un número antes
y después. El FPS HUD + os_signpost van ANTES que cualquier técnica de esta
lista. (Ya existe HUD parcial; formalizarlo como overlay debug permanente.)

## 2. CAPA KERNEL (OCCT) — el 80% del problema

### 2.1 Actor de geometría (C1)
- `GeometryActor` (Swift actor, cola serial propia): TODA op OCCT entra por ahí.
- La UI manda `GeometryRequest` (op + params + generation counter) y recibe
  `GeometryResult` (mesh + edges + brep snapshot) por AsyncStream.
- **Cancelación por generación**: si el usuario arrastra el fillet de 2→3→4mm,
  las requests 2 y 3 se descartan si aún no corrieron (solo se computa la
  última). OCCT no es interrumpible a mitad de op → la granularidad de
  cancelación es la operación entera; por eso el debounce de drag (≈80ms) va
  antes del actor.

### 2.2 Recompute selectivo por DAG (nuestra arma)
- `updateParameter(nodeID:)` ya invalida solo el subárbol downstream ✓.
- Recompute arranca del `brepSnapshot` del nodo ANTERIOR (ya cacheado ✓) —
  nunca desde el origen.
- Nodos hermanos (ramas independientes del DAG) se recomputan EN PARALELO
  (un task por rama; OCCT permite ops concurrentes sobre shapes distintos).
- Presupuesto de snapshots: LRU ~200MB en RAM; los fríos van a disco (mmap
  del paquete .appforge — la persistencia ya guarda .brep por modelo ✓).

### 2.3 Teselado adaptativo y parcial
- `BRepMesh_IncrementalMesh` con `Parallel=true` (OCCT tesela caras en
  paralelo internamente — flag que hay que confirmar expuesto en OCCTSwift;
  si no, exponerlo en el fork).
- **Deflection por tamaño en pantalla**: chordal deflection = f(bounding box
  proyectado). Cuerpo lejano → deflection grueso. Re-tesela al acercarse
  (histéresis 2× para no vibrar).
- **Teselado parcial**: tras una op booleana, solo las caras NUEVAS se teselan
  (OCCT conserva triangulación de caras intactas si no tocas el shape — evitar
  `Clean()` global).
- Preview fantasma SIEMPRE con deflection grueso fijo (LivePreviewEngine ya
  usa low-quality ✓ — mantener esa disciplina).

### 2.4 Booleanas incrementales (investigación — el "software que no existe")
Muro real: booleana de cuerpo complejo (500 caras) toma segundos en cualquier
kernel. Los CAD de escritorio lo tapan con hardware; en iPad hay que ser
más listo:
- **Fase A (corto plazo)**: booleana async + resultado optimista (mostrar CSG
  visual por stencil/shader mientras el B-rep real se computa detrás —
  BooleanComputeShaders.metal ya existe como base ✓).
- **Fase B (investigación)**: caja de recorte — computar la booleana solo en
  la región del bounding box de intersección y coser (OCCT `BOPAlgo` con
  argumentos parciales). Nadie lo hace en tablet; si funciona, es ventaja
  publicable.
- **Fase C (visión)**: kernel híbrido — mantener malla-firmada (SDF) paralela
  al B-rep para preview instantáneo de cualquier op, con reconciliación
  perezosa al B-rep exacto. (Esto es lo que Plasticity insinúa y nadie tiene
  completo en touch.)

## 3. CAPA RENDER (Metal/Satin) — que orbitar sea gratis

| Técnica | Detalle | Estado |
|---|---|---|
| LOD por distancia | LODManager existe ✓ — conectarlo al deflection del kernel (§2.3) para que render y teselado compartan criterio | ◐ |
| Frustum culling | Descarte por AABB contra frustum antes de encolar draw | ✗ trivial |
| Occlusion culling | Hi-Z en compute pass (M1+ lo regala) — para el cableado del cohete DENTRO del fuselaje | F-perf-3 |
| **Instancing de patrones** | Un patrón circular de 24 agujeros/tornillos = 1 draw call con 24 transforms, NO 24 mallas. El feature tree sabe qué es patrón → el render lo explota. Shapr3D no lo hace (cada copia es cuerpo) | ✗ CLAVE |
| Edges como líneas nativas | edgesMesh ya existe ✓ — verificar que son line primitives, no tubos triangulados | ◐ |
| Decimación en órbita | Durante gesto de órbita: LOD global -1; al soltar, restaurar. Imperceptible y duplica fps | ✗ fácil |
| Triple buffer + MTLHeaps | Sin allocaciones por frame; buffers de uniforms ring de 3 | verificar en SatinRenderer |
| Metal HUD / signposts GPU | `MTL_HUD_ENABLED` en debug builds | ✗ |

## 4. CAPA DATOS — abrir en <2s y no comerse la RAM

- **Carga streaming del .appforge**: primer frame = bounding boxes + LOD
  grueso de los N cuerpos visibles; teselado fino llega por prioridad
  (pantalla-céntrica). Nada de "loading spinner de 30s".
- **Out-of-core**: cuerpos ocultos (ojo cerrado / dentro de carpeta colapsada)
  liberan malla y B-rep de RAM (quedan en disco); rehidratación async al
  mostrarlos.
- **Undo por snapshots delta**: el undo stack guarda referencias a snapshots
  del DAG (ya es así ✓) — nunca copias profundas de escena.

## 5. INSTRUMENTACIÓN (va PRIMERO — Fase perf-0)

1. FPS HUD overlay debug: frame time, draw calls, tris en pantalla, memoria,
   cola del GeometryActor.
2. `os_signpost` en: cada op OCCT (nombre + duración), teselado, cold open,
   guardado.
3. Hang detector: watchdog que loguea stack si main thread >250ms sin heartbeat
   (en TestFlight/campo, MetricKit hang reports).
4. **Benchmark reproducible en CI**: proyecto sintético "cohete" (script que
   genera 300 features: brida + patrones de agujeros + tubos + booleanas) +
   test que mide recompute total y falla si regresa >20%. El benchmark ES el
   examen final automatizado.

## 6. FASES

- **perf-0 (con F-CAD-2)**: instrumentación completa (§5) + assert C1 + FPS HUD.
- **perf-1**: GeometryActor + cancelación por generación + debounce de drags.
  Todo el CAD pasa por él. (Es el cambio estructural grande — cuanto antes.)
- **perf-2**: deflection por pantalla + frustum culling + decimación en órbita
  + instancing de patrones + edges nativos verificados.
- **perf-3**: recompute paralelo por ramas + teselado parcial + streaming de
  apertura + out-of-core.
- **perf-4 (investigación)**: booleanas incrementales fase B; prototipo SDF
  paralelo (fase C) — con benchmark del cohete como juez.

## 7. RELACIÓN CON LA VISIÓN DE STARTUP UNIPERSONAL

La automatización total (soporte, releases, monitoreo con miles de clientes)
depende de esta capa: MetricKit + hang reports + benchmark en CI son los ojos
que permiten operar sin humanos. Un producto que "nunca se pega" genera ~0
tickets de soporte — el rendimiento ES la estrategia de automatización.
