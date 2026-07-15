# UI Probe — ver y manejar la app sin iPad físico

Este carril nos independiza del device: un workflow de GitHub Actions bota un
**iPad Simulator** en el runner macOS, instala AppForgeStudio, la **maneja con
toques programados** y sube toda la evidencia visual/funcional como artifacts,
más el `.app` de simulador para subirlo a **Appetize.io** (device en el
navegador).

Con esto el orquestador puede VER la app (screenshots + video + árbol de
accesibilidad + syslog) y diagnosticarla sin tener un iPad enfrente.

## Archivos

- `.github/workflows/ui-probe.yml` — el workflow (trigger SOLO manual).
- `scripts/ui-probe/scenario.sh` — el escenario de toques, **versionado y editable**.
- `scripts/ui-probe/README.md` — este documento.

El setup (Xcode, xcodegen, generate, resolve SPM, flags de firma ad-hoc y de
`-Wno-c++11-narrowing`) está **replicado 1:1 de `build.yml`** — son invariantes
de CI ganados con sangre. No se toca `build.yml`.

## Dispararlo

```bash
gh workflow run ui-probe.yml --ref feature/fase-c
```

Ver la corrida en curso:

```bash
gh run list --workflow ui-probe.yml
gh run watch <run-id>          # sigue los logs en vivo
```

Es `workflow_dispatch` puro: no se activa con push/PR, así que **cero riesgo**
para el CI de build existente.

## Bajar los artifacts

```bash
# lista los artifacts de la última corrida
gh run view <run-id>

# descarga TODO a ./ui-probe-out/
gh run download <run-id> -D ui-probe-out

# o solo la evidencia:
gh run download <run-id> -n ui-probe-evidence-<run-id> -D ui-probe-out
```

Contenido de `ui-probe-evidence-*`:

| Artefacto             | Qué es                                                        |
|-----------------------|--------------------------------------------------------------|
| `screenshots/NN-*.png`| Captura numerada tras cada acción (`00-launch`, `03-home`, …)|
| `video.mp4`           | Grabación de toda la sesión del simulador                    |
| `ui-tree.json`        | Árbol de accesibilidad (labels + frames) vía `idb ui describe-all` |
| `app-log.txt`         | `log stream` filtrado al proceso de la app                   |
| `AppForgeStudio-sim.zip` | El `.app` de simulador comprimido → para Appetize.io      |

Si `idb` no pudo instalarse en el runner, no habrá `ui-tree.json` ni las
capturas numeradas del escenario, pero **sí** habrá `00-launch.png`,
`01/02-idle.png`, el video y el log: el job degrada con elegancia y nunca queda
rojo por culpa de la interacción.

## Editar el escenario de toques

Todo vive en `scripts/ui-probe/scenario.sh`. Patrón:

```bash
act "descripcion-de-la-accion" tap <x> <y>
```

- Cada `act` ejecuta la acción, deja asentar 2 s y guarda una **captura
  numerada** con nombre derivado de la descripción.
- Las coordenadas están en **puntos lógicos** del iPad (idb usa puntos, no
  píxeles). Están calibradas para un iPad Pro 13" (~1032 pt de ancho). Si el
  runner elige otro iPad, ajusta mirando los `frame` en `ui-tree.json`.
- Helpers disponibles: `tap x y`, y llamadas directas a
  `idb ui swipe --udid "$UDID" x1 y1 x2 y2 --duration D` para arrastres.

**Cómo re-calibrar con precisión:** corre el workflow una vez, baja
`ui-tree.json`, busca el label del control (p.ej. `"Nuevo proyecto"`,
`"Archivo"`, `"Modo rayos X"`) y toma el centro de su `frame` como `x y`. Los
labels de accesibilidad reales de la app (en español) incluyen: `Nuevo
proyecto`, `Panel de elementos`, `Deshacer punto`, `Borrar boceto`, `Plano de
boceto: suelo`, `Archivo`, `Agrupar ensamblaje`, `Modo rayos X`, `Reiniciar
medición`.

El escenario actual: sale del **onboarding** (un simulador recién instalado
arranca ahí), crea un **proyecto nuevo** desde Home, toca el **viewport 3D**
(tap + orbitar cámara) y prueba botones del **rail de herramientas** y la
**barra superior**, con captura numerada en cada paso.

## Camino Appetize.io (device en el navegador)

Appetize corre builds de **simulador** directamente — por eso subimos el `.app`
zipeado, no el IPA.

1. Baja `AppForgeStudio-sim.zip` del artifact.
2. Ve a <https://appetize.io/upload>, arrastra el zip (o `POST` a su API con tu
   token). Selecciona plataforma **iOS** y un modelo iPad.
3. Appetize devuelve una URL de sesión: abres la app en un iPad emulado en el
   navegador y la manejas con el ratón/teclado — útil para exploración manual
   cuando los toques programados no bastan.

> Nota: el `.app` de simulador **no** corre en un iPad físico (arquitectura del
> simulador). Para device real sigue siendo el `AppForgeStudio-unsigned-ipa` de
> `build.yml` + AltStore.
