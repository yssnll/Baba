#!/usr/bin/env bash
# Compile Tilawa localement sur un Mac et produit une IPA non signée.
#
#   ./build-ipa.sh
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

echo "→ Empaquetage de l'IPA…"
rm -rf Payload Tilawa-unsigned.ipa
mkdir -p Payload
cp -R "$APP" Payload/
zip -qry Tilawa-unsigned.ipa Payload
rm -rf Payload

echo
echo "✓ Tilawa-unsigned.ipa  ($(du -h Tilawa-unsigned.ipa | cut -f1))"
echo
echo "Prochaine étape : signer et installer avec Sideloadly ou AltStore."
echo "Pour ouvrir le projet dans Xcode :  open Tilawa.xcodeproj"
