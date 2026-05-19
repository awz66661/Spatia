#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_BIN="${SWIFT_BIN:-/usr/bin/swift}"
export CLANG_MODULE_CACHE_PATH="${ROOT_DIR}/.build/clang-module-cache"

mkdir -p "${CLANG_MODULE_CACHE_PATH}" "${ROOT_DIR}/.build/swiftpm-cache"

cd "${ROOT_DIR}"
"${SWIFT_BIN}" build \
  --disable-sandbox \
  --configuration debug \
  --cache-path "${ROOT_DIR}/.build/swiftpm-cache"
