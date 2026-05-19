#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_BIN="${SWIFT_BIN:-/usr/bin/swift}"
APP_NAME="Spatia"
APP_DIR="${ROOT_DIR}/dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

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
cp "${ROOT_DIR}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"

if [[ "${SKIP_CODESIGN:-0}" != "1" ]] && command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "${APP_DIR}"
fi

echo "${APP_DIR}"
