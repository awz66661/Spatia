#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_BIN="${SWIFT_BIN:-/usr/bin/swift}"
INFO_PLIST="${ROOT_DIR}/Resources/Info.plist"
VERSION_FILE="${ROOT_DIR}/VERSION"
APP_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "${INFO_PLIST}")"
APP_VERSION="$(tr -d '[:space:]' < "${VERSION_FILE}")"
APP_DIR="$("${ROOT_DIR}/Scripts/package-app.sh" | tail -n 1)"
DIST_DIR="${ROOT_DIR}/dist"
VOLUME_NAME="${APP_NAME} ${APP_VERSION}"
TEMP_DMG="${DIST_DIR}/${APP_NAME}-${APP_VERSION}-rw.dmg"
DMG_PATH="${ROOT_DIR}/dist/${APP_NAME}-${APP_VERSION}.dmg"
SHA256_PATH="${DMG_PATH}.sha256"
MOUNT_ROOT=""
MOUNT_POINT=""

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-${ROOT_DIR}/.build/clang-module-cache}"
mkdir -p "${CLANG_MODULE_CACHE_PATH}"

detach_image() {
  local mount_point="$1"

  for _ in 1 2 3 4 5; do
    if hdiutil detach "${mount_point}" -quiet; then
      return 0
    fi
    sleep 1
  done

  hdiutil detach "${mount_point}" -force -quiet
}

cleanup() {
  if [[ -n "${MOUNT_POINT}" && -d "${MOUNT_POINT}" ]]; then
    detach_image "${MOUNT_POINT}" || true
  fi

  if [[ -n "${MOUNT_ROOT}" && -d "${MOUNT_ROOT}" ]]; then
    rm -rf "${MOUNT_ROOT}"
  fi

  rm -f "${TEMP_DMG}"
  rm -rf "${ROOT_DIR}/dist/dmg-staging"
}

trap cleanup EXIT

rm -f "${TEMP_DMG}" "${DMG_PATH}" "${SHA256_PATH}"
rm -rf "${ROOT_DIR}/dist/dmg-staging"

APP_SIZE_MB="$(du -sm "${APP_DIR}" | awk '{ print $1 }')"
DMG_SIZE_MB=$((APP_SIZE_MB + 80))
MOUNT_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/spatia-dmg.XXXXXX")"

hdiutil create \
  -quiet \
  -volname "${VOLUME_NAME}" \
  -size "${DMG_SIZE_MB}m" \
  -fs HFS+ \
  -ov \
  "${TEMP_DMG}"

hdiutil attach \
  -quiet \
  -readwrite \
  -noverify \
  -noautoopen \
  -mountroot "${MOUNT_ROOT}" \
  "${TEMP_DMG}"

MOUNT_POINT="$(find "${MOUNT_ROOT}" -mindepth 1 -maxdepth 1 -type d -print -quit)"
if [[ -z "${MOUNT_POINT}" || ! -d "${MOUNT_POINT}" ]]; then
  echo "Failed to mount temporary DMG." >&2
  exit 1
fi

cp -R "${APP_DIR}" "${MOUNT_POINT}/${APP_NAME}.app"
ln -s /Applications "${MOUNT_POINT}/Applications"

"${SWIFT_BIN}" \
  "${ROOT_DIR}/Scripts/generate-dmg-background.swift" \
  "${MOUNT_POINT}/.background/background.png"

osascript <<EOF
tell application "Finder"
  set volumeFolder to POSIX file "${MOUNT_POINT}" as alias
  tell folder volumeFolder
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, 760, 520}

    set iconViewOptions to the icon view options of container window
    set arrangement of iconViewOptions to not arranged
    set icon size of iconViewOptions to 96
    set text size of iconViewOptions to 13
    set label position of iconViewOptions to bottom
    set background picture of iconViewOptions to POSIX file "${MOUNT_POINT}/.background/background.png"

    tell container window
      set position of item "${APP_NAME}.app" to {170, 215}
      set position of item "Applications" to {490, 215}
    end tell

    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

for _ in 1 2 3 4 5 6 7 8 9 10; do
  if [[ -f "${MOUNT_POINT}/.DS_Store" ]]; then
    break
  fi
  sleep 0.5
done

if [[ ! -f "${MOUNT_POINT}/.DS_Store" ]]; then
  echo "Finder did not write DMG layout metadata." >&2
  exit 1
fi

sync
detach_image "${MOUNT_POINT}"
MOUNT_POINT=""

hdiutil convert \
  -quiet \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  -o "${DMG_PATH}" \
  "${TEMP_DMG}"

shasum -a 256 "${DMG_PATH}" > "${SHA256_PATH}"

echo "${DMG_PATH}"
