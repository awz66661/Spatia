#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Spatia development environment"
echo
echo "Root: ${ROOT_DIR}"
echo

if command -v swift >/dev/null 2>&1; then
  echo "Swift on PATH:"
  command -v swift
  swift --version
else
  echo "Swift on PATH: missing"
fi

echo
if [[ -x /usr/bin/swift ]]; then
  echo "System Swift:"
  /usr/bin/swift --version
fi

echo
echo "Developer directory:"
xcode-select -p || true

echo
echo "xcodebuild:"
if xcodebuild -version >/tmp/spatia-xcodebuild-version.txt 2>/tmp/spatia-xcodebuild-error.txt; then
  cat /tmp/spatia-xcodebuild-version.txt
else
  cat /tmp/spatia-xcodebuild-error.txt
  echo "Install/select full Xcode for native app development."
fi

echo
echo "Optional tools:"
for tool in swiftformat swiftlint xcodegen; do
  if command -v "${tool}" >/dev/null 2>&1; then
    echo "- ${tool}: $(command -v "${tool}")"
  else
    echo "- ${tool}: not installed"
  fi
done

echo
echo "Local cache paths used by scripts:"
echo "- SwiftPM: ${ROOT_DIR}/.build/swiftpm-cache"
echo "- Clang modules: ${ROOT_DIR}/.build/clang-module-cache"
echo "- Swift binary: \${SWIFT_BIN:-/usr/bin/swift}"
