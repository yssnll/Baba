#!/usr/bin/env bash
# Vérifie une IPA déjà signée par eSign.
#
# Usage :
#   ./verify-app-group.sh /chemin/vers/Tilawa.ipa
#
# Le script ne modifie pas l'IPA. Il échoue si l'App Group n'est pas présente
# dans l'application principale ou dans l'extension WidgetKit.
set -euo pipefail

IPA="${1:-}"
GROUP="group.app.tilawa"

if [[ -z "$IPA" || ! -f "$IPA" ]]; then
  echo "Usage : $0 /chemin/vers/Tilawa.ipa" >&2
  exit 2
fi

command -v codesign >/dev/null || {
  echo "codesign est requis. Lance ce script sur macOS." >&2
  exit 2
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

unzip -q "$IPA" -d "$WORK"
APP="$(find "$WORK/Payload" -maxdepth 1 -type d -name '*.app' -print -quit)"
WIDGET="$APP/PlugIns/TilawaWidget.appex"

if [[ -z "$APP" || ! -d "$WIDGET" ]]; then
  echo "ÉCHEC : l'IPA ne contient pas Tilawa.app et TilawaWidget.appex." >&2
  echo "Dans eSign, signe l'IPA complète et conserve l'extension du widget." >&2
  exit 1
fi

check_entitlements() {
  local binary="$1"
  local label="$2"
  local output

  output="$(codesign -d --entitlements :- "$binary" 2>/dev/null || true)"
  if grep -Fq "$GROUP" <<<"$output"; then
    echo "OK : $label contient $GROUP"
  else
    echo "ÉCHEC : $label ne contient pas $GROUP" >&2
    return 1
  fi
}

check_entitlements "$APP" "Tilawa.app"
check_entitlements "$WIDGET" "TilawaWidget.appex"

echo
echo "App Group correcte dans les deux cibles."
echo "Si le widget reste bloqué, supprime-le de l'écran d'accueil,"
echo "redémarre l'iPhone, puis ajoute-le à nouveau après réinstallation."