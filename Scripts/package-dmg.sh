#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$("${ROOT_DIR}/Scripts/package-app.sh" | tail -n 1)"
DMG_PATH="${ROOT_DIR}/dist/Spatia.dmg"

rm -f "${DMG_PATH}"
hdiutil create \
  -volname "Spatia" \
  -srcfolder "${APP_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

echo "${DMG_PATH}"
