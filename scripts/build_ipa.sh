#!/usr/bin/env bash
# ==============================================================================
# R Music - Script de Compilación Local de IPA para macOS / SSH
# ==============================================================================
set -e

APP_NAME="R_Music_v2.0.0"
OUTPUT_DIR="build/ios_ipa"
DEVELOPMENT_TEAM="${APPLE_TEAM_ID:-}"

echo "=========================================="
echo " Instando compilación de iOS IPA: $APP_NAME"
echo "=========================================="

# 1. Verificar herramientas necesarias
command -v flutter >/dev/null 2>&1 || { echo "❌ Error: Flutter no está instalado en PATH."; exit 1; }
command -v pod >/dev/null 2>&1 || { echo "❌ Error: CocoaPods no está instalado. Ejecuta: sudo gem install cocoapods"; exit 1; }
command -v xcodebuild >/dev/null 2>&1 || { echo "❌ Error: Xcode command line tools no encontrados."; exit 1; }

echo "✅ Entorno verificado: Flutter, CocoaPods y Xcode detectados."

# 2. Limpieza previa opcional y dependencias
echo "📦 Resolviendo dependencias de Flutter..."
flutter pub get

echo "📦 Descargando artefactos del motor iOS..."
flutter precache --ios

# 3. Instalación de CocoaPods
echo "☕ Instalando dependencias de CocoaPods..."
cd ios
pod install --repo-update
cd ..

# 4. Compilación
mkdir -p "$OUTPUT_DIR"

if [ -n "$DEVELOPMENT_TEAM" ]; then
  echo "🔑 Compilando con Apple Developer Team ID: $DEVELOPMENT_TEAM..."
  flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
  cp build/ios/ipa/*.ipa "$OUTPUT_DIR/${APP_NAME}.ipa"
else
  echo "📱 Compilando versión sin firma (ideal para Sideloadly / AltStore / TrollStore)..."
  flutter build ios --release --no-codesign

  echo "📦 Empaquetando Runner.app en formato .ipa..."
  rm -rf Payload
  mkdir -p Payload
  cp -r build/ios/iphoneos/Runner.app Payload/
  zip -r -9 "$OUTPUT_DIR/${APP_NAME}.ipa" Payload
  rm -rf Payload
fi

echo "=========================================="
echo "🎉 ¡Compilación completada con éxito!"
echo "📁 Archivo IPA generado: $OUTPUT_DIR/${APP_NAME}.ipa"
echo "=========================================="
