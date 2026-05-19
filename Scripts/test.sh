#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_BIN="${SWIFT_BIN:-/usr/bin/swift}"
export CLANG_MODULE_CACHE_PATH="${ROOT_DIR}/.build/clang-module-cache"

mkdir -p "${CLANG_MODULE_CACHE_PATH}" "${ROOT_DIR}/.build/swiftpm-cache"

if ! xcrun --sdk macosx --show-sdk-platform-path >/dev/null 2>&1; then
  echo "XCTest platform path is unavailable."
  echo "Install/select full Xcode, then rerun: ./Scripts/test.sh"
  exit 1
fi

cd "${ROOT_DIR}"
"${SWIFT_BIN}" test \
  --disable-sandbox \
  --cache-path "${ROOT_DIR}/.build/swiftpm-cache"
