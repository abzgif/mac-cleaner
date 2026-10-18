#!/usr/bin/env bash
set -e

echo "=================================================="
echo "  CleanMac — Native macOS App Builder & Packager"
echo "=================================================="

APP_NAME="CleanMac"
BUILD_DIR=".build/release"
OUTPUT_DIR="build"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"

echo "🔨 Building release binary with Swift 6..."
swift build -c release

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

echo "=================================================="
echo "🎉 Build successful! Application ready at:"
echo "   ${APP_BUNDLE}"
echo "=================================================="
echo "To notarize for distribution outside the App Store:"
echo "1. Create a zip archive:"
echo "   ditto -c -k --keepParent \"${APP_BUNDLE}\" \"${OUTPUT_DIR}/${APP_NAME}.zip\""
echo "2. Submit to Apple Notary Service:"
echo "   xcrun notarytool submit \"${OUTPUT_DIR}/${APP_NAME}.zip\" --keychain-profile \"MyNotaryProfile\" --wait"
echo "3. Staple ticket to the app:"
echo "   xcrun stapler staple \"${APP_BUNDLE}\""
echo "=================================================="
