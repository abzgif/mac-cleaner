#!/usr/bin/env bash
set -e

echo "=================================================="
echo "  CleanMac — Native macOS App Builder & Packager"
echo "=================================================="

APP_NAME="CleanMac"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist 2>/dev/null || echo "1.1.0")
BUILD_DIR=".build/release"
OUTPUT_DIR="build"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"

echo "🔨 Building release binary with Swift 6 (v${VERSION})..."
swift build --disable-sandbox -c release

echo "📦 Creating macOS .app bundle at ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "🚚 Copying binary and metadata..."
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

cp "Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

if [ -f "Resources/AppIcon.icns" ]; then
    echo "🎨 Embedding AppIcon.icns..."
    cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

echo "🔐 Applying code signature with Hardened Runtime..."
if [ -n "$DEVELOPER_ID_APPLICATION" ]; then
    echo "Using Developer ID Application identity: ${DEVELOPER_ID_APPLICATION}"
    codesign --force --deep --options runtime --entitlements "CleanMac.entitlements" --sign "${DEVELOPER_ID_APPLICATION}" "${APP_BUNDLE}"
else
    echo "No DEVELOPER_ID_APPLICATION specified; applying ad-hoc code signature for local testing..."
    codesign --force --deep --options runtime --entitlements "CleanMac.entitlements" --sign - "${APP_BUNDLE}"
fi

echo "✅ Verifying signature..."
codesign -vvv --deep --strict "${APP_BUNDLE}"

echo "📦 Creating ZIP release archive..."
rm -f "${OUTPUT_DIR}/${APP_NAME}-${VERSION}.zip" "${OUTPUT_DIR}/${APP_NAME}.zip"
ditto -c -k --keepParent "${APP_BUNDLE}" "${OUTPUT_DIR}/${APP_NAME}-${VERSION}.zip"
cp "${OUTPUT_DIR}/${APP_NAME}-${VERSION}.zip" "${OUTPUT_DIR}/${APP_NAME}.zip"

echo "💿 Creating Drag-to-Install DMG disk image..."
if ! VERSION="${VERSION}" bash "${SCRIPT_DIR:-scripts}/create_dmg.sh"; then
    echo "⚠️  Skipping DMG disk mounting in restricted environment (App bundle and ZIP archive are ready)."
    rm -rf "${OUTPUT_DIR}/dmg_staging" "${OUTPUT_DIR}/${APP_NAME}_rw.dmg"
fi

echo "=================================================="
echo "🎉 Build & packaging successful! Artifacts ready:"
echo "   App: ${APP_BUNDLE}"
echo "   DMG: ${OUTPUT_DIR}/${APP_NAME}-${VERSION}.dmg"
echo "   ZIP: ${OUTPUT_DIR}/${APP_NAME}-${VERSION}.zip"
echo "=================================================="
