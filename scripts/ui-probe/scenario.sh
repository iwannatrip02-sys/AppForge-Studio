#!/usr/bin/env bash
#
# scenario.sh v2 — capturas cronometradas del MODO PROBE interno de la app.
#
# CAMBIO DE ENFOQUE (v1 → v2): v1 dependía de idb (toques externos) para salir
# del onboarding y manejar la app. Eso resultó FRÁGIL en CI: la app se quedaba
# en el carrusel de onboarding y no veíamos nada más (corrida 1).
#
# v2 usa el patrón estándar de UI-testing por LAUNCH-ARGUMENT: la app trae un
# arnés interno (Sources/Services/UIProbeMode.swift) que se activa SOLO con
# `-UIProbeMode`. Al activarse: sella el onboarding, pide landscape, abre un
# proyecto y corre una secuencia cronometrada de modelado B-rep REAL
# (caja → cilindro → seleccionar cara → push/pull → boolean), logueando cada
# paso con os_log como "PROBE-STEP N: ...". Este script solo tiene que:
#   1) (re)lanzar la app CON el flag, y
#   2) tomar screenshots numerados cada ~3s durante ~45s (step-00..step-14).
# Los toques idb son ahora un BONUS opcional al final, NO un requisito.
#
# HONESTIDAD: esto ejercita view models → kernel OCCT → Metal/Satin (lógica +
# render de punta a punta), NO gestos táctiles crudos. El feel táctil se calibra
# en device real.
#
# Uso:  scenario.sh <UDID> <ARTIFACTS_DIR>
#
# Filosofía: MEJOR ESFUERZO. Ningún fallo aquí debe tumbar el workflow (el step
# que lo invoca lleva continue-on-error). Por eso NO usamos `set -e`.

set -x
set -o pipefail

UDID="${1:?falta UDID}"
ART="${2:?falta ARTIFACTS_DIR}"
SHOTS="$ART/screenshots"
mkdir -p "$SHOTS"

# Bundle ID real de la app (verificado en project.yml).
BUNDLE_ID="${BUNDLE_ID:-com.appforgestudio.app}"

# --- helpers ---------------------------------------------------------------

# shot "step-NN" -> guarda una captura numerada via simctl (siempre best-effort).
shot() {
  local name="$1"
  xcrun simctl io "$UDID" screenshot "$SHOTS/${name}.png" \
    || echo "shot ${name} falló (continuo)"
}

# --- 1. Relanzar la app CON el arnés activado ------------------------------
# Terminamos cualquier instancia previa (el workflow ya lanzó la app SIN flag
# para el 00-launch base) y relanzamos con -UIProbeMode para arrancar el arnés
# desde cero: onboarding sellado, landscape, workspace, secuencia programada.
echo "=== Relanzando $BUNDLE_ID con -UIProbeMode ==="
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
sleep 1
xcrun simctl launch "$UDID" "$BUNDLE_ID" -UIProbeMode \
  || echo "launch -UIProbeMode devolvió no-cero (continuo; capturaremos igual)"

# Dar tiempo a Metal/Satin a levantar el primer frame del workspace.
sleep 4
shot "step-00-probe-boot"

# --- 2. Captura cronometrada de la secuencia interna -----------------------
# El arnés deja ~3s entre pasos (UIProbeMode.stepInterval). Capturamos a la
# misma cadencia para alinear cada screenshot con un "PROBE-STEP N" del log.
# 14 tomas x ~3s ≈ 42s cubren caja→cilindro→cara→push/pull→boolean→idle.
for n in $(seq 1 14); do
  sleep 3
  label=$(printf 'step-%02d' "$n")
  shot "$label"
done

# --- 3. Idle final ---------------------------------------------------------
sleep 3
shot "step-15-idle-final"

# --- 4. BONUS opcional: árbol de accesibilidad + un toque, si hay idb ------
# NO es requerido; si idb no está o falla, el arnés interno ya produjo toda la
# evidencia de arriba. Solo enriquece el diagnóstico cuando está disponible.
if command -v idb >/dev/null 2>&1; then
  echo "=== idb disponible: volcando árbol de accesibilidad (bonus) ==="
  idb ui describe-all --udid "$UDID" > "$ART/ui-tree.json" 2>>"$ART/ui-tree.err" \
    || echo "describe-all falló (ui-tree.json puede quedar vacío)"
  # Un toque en el centro del viewport como prueba de vida del hit-testing.
  idb ui tap --udid "$UDID" 700 500 || echo "tap bonus falló (continuo)"
  sleep 2
  shot "step-16-bonus-tap"
else
  echo "=== idb no disponible: el arnés interno ya cubrió la evidencia ==="
fi

echo "=== Escenario v2 completado. Capturas en $SHOTS ==="
ls -la "$SHOTS" || true
exit 0
