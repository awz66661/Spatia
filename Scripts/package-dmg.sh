#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="${ROOT_DIR}/Resources/Info.plist"
VERSION_FILE="${ROOT_DIR}/VERSION"
APP_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "${INFO_PLIST}")"
APP_VERSION="$(tr -d '[:space:]' < "${VERSION_FILE}")"
APP_DIR="$("${ROOT_DIR}/Scripts/package-app.sh" | tail -n 1)"
STAGING_DIR="${ROOT_DIR}/dist/dmg-staging"
DMG_PATH="${ROOT_DIR}/dist/${APP_NAME}-${APP_VERSION}.dmg"
SHA256_PATH="${DMG_PATH}.sha256"

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
cp -R "${APP_DIR}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

rm -f "${DMG_PATH}" "${SHA256_PATH}"
hdiutil create \
  -volname "${APP_NAME} ${APP_VERSION}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

shasum -a 256 "${DMG_PATH}" > "${SHA256_PATH}"

echo "${DMG_PATH}"
