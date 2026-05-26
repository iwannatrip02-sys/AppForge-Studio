#!/bin/bash
# Script de compilacion AppForge Studio para macOS
# Ejecutar en terminal macOS desde la raiz del proyecto

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IOS_APP_DIR="$PROJECT_DIR/ios-app/AppForgeStudio"
BUILD_DIR="$PROJECT_DIR/build"

cd "$IOS_APP_DIR"

echo "=== Paso 0: Verificar toolchain ==="
xcode-select -p || { echo "ERROR: Xcode no instalado"; exit 1; }
swift --version || { echo "ERROR: Swift no disponible"; exit 1; }

echo "=== Paso 1: Resolver dependencias SPM ==="
swift package resolve

echo "=== Paso 2: Compilar para iOS Simulator ==="
xcodebuild -scheme AppForgeStudio \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4' \
  build 2>&1 | xcbeautify || { echo "ERROR: Compilacion fallida"; exit 1; }

echo "=== Paso 3: Ejecutar tests ==="
xcodebuild -scheme AppForgeStudio \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4' \
  test 2>&1 | xcbeautify || { echo "ERROR: Tests fallaron"; exit 1; }

echo "=== Paso 4: Archive para TestFlight ==="
mkdir -p "$BUILD_DIR"
xcodebuild -scheme AppForgeStudio \
  -destination 'generic/platform=iOS' \
  archive -archivePath "$BUILD_DIR/AppForgeStudio.xcarchive" \
  2>&1 | xcbeautify || { echo "ERROR: Archive fallido"; exit 1; }

echo "=== Paso 5: Exportar IPA ==="
xcodebuild -exportArchive \
  -archivePath "$BUILD_DIR/AppForgeStudio.xcarchive" \
  -exportPath "$BUILD_DIR/AppForgeStudio.ipa" \
  -exportOptionsPlist "$PROJECT_DIR/ExportOptions.plist" \
  2>&1 | xcbeautify || { echo "ERROR: Export IPA fallido"; exit 1; }

echo "=== LISTO ==="
echo "IPA generado en: $BUILD_DIR/AppForgeStudio.ipa"
echo "Subir a TestFlight via Transporter o Xcode Organizer"
