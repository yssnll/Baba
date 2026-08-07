#!/usr/bin/env bash
# Compile Tilawa localement sur un Mac et produit une IPA.
#
#   ./build-ipa.sh
#
# Sans DEVELOPMENT_TEAM, le script produit une IPA non signée destinée à la
# vérification ou à une resignature ultérieure. Une IPA utilisable avec le
# widget doit être signée avec une équipe Apple possédant l'App Group.
#
# Exemple signé :
#   DEVELOPMENT_TEAM=ABC1234567 ./build-ipa.sh
#
# Prérequis : Xcode (App Store) + Homebrew.
set -euo pipefail

cd "$(dirname "$0")"

command -v xcodebuild >/dev/null || { echo "Xcode est requis (xcodebuild introuvable)."; exit 1; }

if ! command -v xcodegen >/dev/null; then
  echo "→ Installation de XcodeGen…"
  command -v brew >/dev/null || { echo "Homebrew requis : https://brew.sh"; exit 1; }
  brew install xcodegen
fi

echo "→ Génération du projet Xcode…"
xcodegen generate

TEAM_ID="${DEVELOPMENT_TEAM:-${TEAM_ID:-}}"
rm -rf build Payload Tilawa.ipa Tilawa-unsigned.ipa

if [ -n "$TEAM_ID" ]; then
  echo "→ Compilation et signature Release pour l'équipe Apple $TEAM_ID…"
  xcodebuild \
    -project Tilawa.xcodeproj \
    -scheme Tilawa \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -archivePath build/Tilawa.xcarchive \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    archive

  cat > build/ExportOptions.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>__TEAM_ID__</string>
</dict>
</plist>
PLIST
  sed -i.bak "s/__TEAM_ID__/$TEAM_ID/" build/ExportOptions.plist
  rm -f build/ExportOptions.plist.bak

  echo "→ Export de l'IPA signée…"
  xcodebuild \
    -exportArchive \
    -archivePath build/Tilawa.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist build/ExportOptions.plist

  IPA="build/export/Tilawa.ipa"
  [ -f "$IPA" ] || { echo "Échec : $IPA introuvable."; exit 1; }
  cp "$IPA" Tilawa.ipa
  echo
  echo "✓ Tilawa.ipa signée ($(du -h Tilawa.ipa | cut -f1))"
  echo "  L'équipe Apple doit avoir activé l'App Group group.app.tilawa."
else
  echo "→ Compilation (Release, non signée)…"
  xcodebuild \
    -project Tilawa.xcodeproj \
    -scheme Tilawa \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath build \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    clean build

  APP="build/Build/Products/Release-iphoneos/Tilawa.app"
  [ -d "$APP" ] || { echo "Échec : $APP introuvable."; exit 1; }
  [ -d "$APP/PlugIns/TilawaWidget.appex" ] || {
    echo "Échec : l'extension WidgetKit n'est pas embarquée dans Tilawa.app."
    exit 1
  }

  echo "→ Empaquetage de l'IPA non signée…"
  mkdir -p Payload
  cp -R "$APP" Payload/
  zip -qry Tilawa-unsigned.ipa Payload
  rm -rf Payload

  echo
  echo "✓ Tilawa-unsigned.ipa  ($(du -h Tilawa-unsigned.ipa | cut -f1))"
  echo "  Cette IPA ne peut pas activer le widget avant resignature."
fi

echo
echo "Pour ouvrir le projet dans Xcode : open Tilawa.xcodeproj"
