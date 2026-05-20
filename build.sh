#!/usr/bin/env bash
# build.sh — build DuoSound.app and package as DuoSound.dmg
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="DuoSound"
BUNDLE_ID="com.duosound.app"
VERSION="1.0"
BUILD_DIR=".build"
APP_BUNDLE="dist/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "▶ Building ${APP_NAME} release…"
swift build -c release 2>&1

BINARY="${BUILD_DIR}/release/${APP_NAME}"
if [ ! -f "$BINARY" ]; then
  echo "✗ Build failed — binary not found at ${BINARY}"
  exit 1
fi

echo "▶ Assembling .app bundle…"
rm -rf dist
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Copy binary
cp "$BINARY" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist and resolve any remaining Xcode variable placeholders
cp "DuoSound/Info.plist" "${CONTENTS}/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ${APP_NAME}" "${CONTENTS}/Info.plist" 2>/dev/null || true

# Compile Assets.xcassets with actool (produces Assets.car)
ACTOOL=$(xcrun -f actool 2>/dev/null || echo "")
if [ -n "$ACTOOL" ] && [ -d "DuoSound/Assets.xcassets" ]; then
  echo "▶ Compiling Assets.xcassets…"
  "$ACTOOL" \
    --output-format human-readable-text \
    --notices --warnings \
    --export-dependency-info "${BUILD_DIR}/assetcatalog_dependencies" \
    --output-partial-info-plist "${BUILD_DIR}/assetcatalog_generated_info.plist" \
    --app-icon AppIcon \
    --compress-pngs \
    --enable-on-demand-resources NO \
    --platform macosx \
    --minimum-deployment-target 13.0 \
    --target-device mac \
    --compile "${RESOURCES_DIR}" \
    "DuoSound/Assets.xcassets" 2>&1 || true
fi

# Copy any compiled resources from SPM
RESOURCE_BUNDLE="${BUILD_DIR}/release/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
  cp -r "${RESOURCE_BUNDLE}/" "${RESOURCES_DIR}/"
fi

# Ad-hoc code sign (no entitlements needed — CoreAudio device management is user-level)
echo "▶ Code signing (ad-hoc)…"
codesign --force --sign - --timestamp=none "${APP_BUNDLE}" 2>&1 || true

echo "▶ Creating DMG…"
if ! command -v create-dmg &>/dev/null; then
  echo "⚠  create-dmg not found — install with: brew install create-dmg"
  echo "✓  App bundle ready at: ${APP_BUNDLE}"
  exit 0
fi

create-dmg \
  --volname "${APP_NAME}" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 160 \
  --icon "${APP_NAME}.app" 180 170 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 480 170 \
  "dist/${DMG_NAME}" \
  "${APP_BUNDLE}" 2>&1

echo ""
echo "✓  Done! Outputs:"
echo "   App:  ${APP_BUNDLE}"
echo "   DMG:  dist/${DMG_NAME}"
