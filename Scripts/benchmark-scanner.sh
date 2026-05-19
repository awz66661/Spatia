#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$ROOT_DIR/.build/benchmark-scanner"

mkdir -p "$CACHE_DIR/home" "$CACHE_DIR/module-cache" "$CACHE_DIR/swiftpm-cache" "$CACHE_DIR/scratch"

export HOME="$CACHE_DIR/home"
export CLANG_MODULE_CACHE_PATH="$CACHE_DIR/module-cache"
export SWIFTPM_CACHE_PATH="$CACHE_DIR/swiftpm-cache"

exec /usr/bin/swift run \
  --package-path "$ROOT_DIR" \
  --disable-sandbox \
  --cache-path "$CACHE_DIR/swiftpm-cache" \
  --scratch-path "$CACHE_DIR/scratch" \
  -c release \
  SpatiaBenchmarks
