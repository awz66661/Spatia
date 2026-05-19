#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_BIN="${SWIFT_BIN:-/usr/bin/swift}"
INFO_PLIST="${ROOT_DIR}/Resources/Info.plist"
APP_ICON="${ROOT_DIR}/Resources/AppIcon.icns"
VERSION_FILE="${ROOT_DIR}/VERSION"
APP_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "${INFO_PLIST}")"
APP_VERSION="$(tr -d '[:space:]' < "${VERSION_FILE}")"
APP_DIR="${ROOT_DIR}/dist/${APP_NAME}-${APP_VERSION}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

"${ROOT_DIR}/Scripts/check-version.sh" >&2

export CLANG_MODULE_CACHE_PATH="${ROOT_DIR}/.build/clang-module-cache"
mkdir -p "${CLANG_MODULE_CACHE_PATH}" "${ROOT_DIR}/.build/swiftpm-cache"

cd "${ROOT_DIR}"
"${SWIFT_BIN}" build \
  --disable-sandbox \
  --configuration release \
  --cache-path "${ROOT_DIR}/.build/swiftpm-cache"

BIN_DIR="$("${SWIFT_BIN}" build \
  --disable-sandbox \
  --configuration release \
  --cache-path "${ROOT_DIR}/.build/swiftpm-cache" \
  --show-bin-path)"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BIN_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
cp "${INFO_PLIST}" "${CONTENTS_DIR}/Info.plist"
cp "${APP_ICON}" "${RESOURCES_DIR}/AppIcon.icns"

if [[ "${SKIP_CODESIGN:-0}" == "1" ]]; then
  echo "Skipping code signing because SKIP_CODESIGN=1" >&2
elif command -v codesign >/dev/null 2>&1; then
  CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
  codesign --force --deep --sign "${CODESIGN_IDENTITY}" "${APP_DIR}"
else
  echo "codesign is unavailable; set SKIP_CODESIGN=1 for unsigned packaging." >&2
  exit 1
fi

echo "${APP_DIR}"
