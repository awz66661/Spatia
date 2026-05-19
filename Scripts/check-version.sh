#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="${ROOT_DIR}/VERSION"
INFO_PLIST="${ROOT_DIR}/Resources/Info.plist"

if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "VERSION file is missing." >&2
  exit 1
fi

VERSION="$(tr -d '[:space:]' < "${VERSION_FILE}")"
if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must use X.Y.Z format; got '${VERSION}'." >&2
  exit 1
fi

PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${INFO_PLIST}")"
if [[ "${PLIST_VERSION}" != "${VERSION}" ]]; then
  echo "Resources/Info.plist CFBundleShortVersionString (${PLIST_VERSION}) must match VERSION (${VERSION})." >&2
  exit 1
fi

BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${INFO_PLIST}")"
if [[ ! "${BUILD_VERSION}" =~ ^[1-9][0-9]*$ ]]; then
  echo "Resources/Info.plist CFBundleVersion must be a positive integer; got '${BUILD_VERSION}'." >&2
  exit 1
fi

REF_NAME="${GITHUB_REF_NAME:-}"
if [[ -z "${REF_NAME}" && "${GITHUB_REF:-}" == refs/tags/* ]]; then
  REF_NAME="${GITHUB_REF#refs/tags/}"
fi

if [[ "${GITHUB_REF_TYPE:-}" == "tag" || "${GITHUB_REF:-}" == refs/tags/* ]]; then
  EXPECTED_TAG="v${VERSION}"
  if [[ "${REF_NAME}" != "${EXPECTED_TAG}" ]]; then
    echo "Release tag must be ${EXPECTED_TAG}; got '${REF_NAME}'." >&2
    exit 1
  fi
fi

echo "Version OK: ${VERSION} (build ${BUILD_VERSION})"
