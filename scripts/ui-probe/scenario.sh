#!/usr/bin/env bash
#
# scenario.sh — escenario de toques versionado para el UI Probe.
#
# Maneja AppForgeStudio en un iPad Simulator ya booteado, con la app YA lanzada,
# usando idb (fb-idb). Produce:
#   - artifacts/ui-tree.json         (árbol de accesibilidad completo tras Home)
#   - artifacts/screenshots/NN-*.png (una captura NUMERADA tras cada acción)
#
# Filosofía: MEJOR ESFUERZO. Ningún fallo aquí debe tumbar el workflow — el step
# que lo invoca lleva `continue-on-error: true`. Por eso NO usamos `set -e`; cada
# acción es defensiva y siempre intentamos capturar el estado visual.
#
# Uso:  scenario.sh <UDID> <ARTIFACTS_DIR>
#
# Flujo de la app (verificado en AppForgeStudioApp.swift):
#   OnboardingFlow (si !onboardingComplete)  ->  HomeView (galería)  ->  Workspace
# Un simulador recién instalado arranca en ONBOARDING, así que primero hay que
# salir de él para llegar a Home y crear un proyecto.
#
# Cómo editarlo: añade bloques `act "descripcion" <comando idb>` en orden. El
# número de captura se autoincrementa. Coordenadas en PUNTOS lógicos del iPad
# (idb usa el sistema de puntos, no píxeles). Ver README para el catálogo de
# labels de accesibilidad reales de la app.

set -x
set -o pipefail

UDID="${1:?falta UDID}"
ART="${2:?falta ARTIFACTS_DIR}"
SHOTS="$ART/screenshots"
mkdir -p "$SHOTS"

STEP=1

# --- helpers ---------------------------------------------------------------

# shot "nombre"  -> guarda una captura NUMERADA (03-nombre.png) via simctl.
shot() {
  local name="$1"
  local n
  n=$(printf '%02d' "$STEP")
  xcrun simctl io "$UDID" screenshot "$SHOTS/${n}-${name}.png" || echo "shot ${name} falló (continuo)"
  STEP=$((STEP + 1))
}

# act "desc" <cmd...>  -> ejecuta una acción idb, deja asentar, captura.
act() {
  local desc="$1"; shift
  echo "=== ACCIÓN: $desc ==="
  "$@" || echo "acción '$desc' devolvió no-cero (continuo)"
  sleep 2
  # nombre de captura = desc en slug simple
  local slug
  slug=$(echo "$desc" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')
  shot "$slug"
}

# tap x y  -> toque puntual
tap() { idb ui tap --udid "$UDID" "$1" "$2"; }

# --- 0. árbol de accesibilidad del estado inicial --------------------------
# describe-all revela labels/frames reales; sirve para diagnosticar y para
# ajustar coordenadas si el layout del runner difiere.
echo "=== Volcando árbol de accesibilidad inicial ==="
idb ui describe-all --udid "$UDID" > "$ART/ui-tree.json" 2>>"$ART/ui-tree.err" \
  || echo "describe-all falló (ui-tree.json puede quedar vacío)"
shot "initial"

# --- 1. Salir del onboarding ----------------------------------------------
# OnboardingFlow suele ser un carrusel con botón de avanzar/empezar. Sin labels
# garantizados, avanzamos con taps en la zona inferior-central (donde vive el
# CTA "Empezar"/"Siguiente" en la mayoría de onboardings) varias veces.
# Coordenadas para iPad Pro 13" (~1032x1376 pt en landscape; el simulador
# arranca en portrait ~1032 de ancho). Zona baja-centro = CTA típico.
for i in 1 2 3 4; do
  act "onboarding-avanzar-$i" tap 516 1180
done

# Reintento: algunos onboardings cierran con un tap en "X" arriba-derecha.
act "onboarding-cerrar" tap 980 90

# Re-volcar árbol: si ya estamos en Home, aquí se verá "Nuevo proyecto".
idb ui describe-all --udid "$UDID" > "$ART/ui-tree-home.json" 2>/dev/null || true
shot "home"

# --- 2. Crear un proyecto nuevo desde Home --------------------------------
# HomeView: primera tarjeta = "Nuevo proyecto" (icono plus). En el LazyVGrid
# es la esquina superior-izquierda de la rejilla, bajo el header. Tap ahí.
act "crear-proyecto" tap 150 300

# Esperar a que Metal/Satin levante el viewport del workspace.
sleep 4
shot "workspace"

# --- 3. Interactuar con el viewport 3D ------------------------------------
# Tap en el centro del viewport para crear/seleccionar en el lienzo.
act "tap-viewport-centro" tap 516 700

# Arrastre corto = orbitar la cámara (gesto típico del canvas 3D).
act "orbitar-camara" idb ui swipe --udid "$UDID" 400 700 650 620 --duration 0.4

# --- 4. Tocar botones del rail de herramientas ----------------------------
# El rail vive normalmente en un borde. Probamos el borde izquierdo (herramientas
# de boceto en CADModeView) y el superior (barra Archivo/agrupar/rayos-X).
act "rail-izquierdo-1" tap 60 400
act "rail-izquierdo-2" tap 60 500
act "barra-superior" tap 60 60

# --- 5. Captura final ------------------------------------------------------
shot "final"

echo "=== Escenario completado. Capturas en $SHOTS ==="
ls -la "$SHOTS" || true
exit 0
