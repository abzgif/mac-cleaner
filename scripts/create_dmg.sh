#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="CleanMac"
APP_BUNDLE="${PROJECT_DIR}/build/${APP_NAME}.app"
DMG_NAME="CleanMac-1.0.0.dmg"
FINAL_DMG="${PROJECT_DIR}/build/${DMG_NAME}"
TMP_DMG="${PROJECT_DIR}/build/${APP_NAME}_rw.dmg"
STAGING_DIR="${PROJECT_DIR}/build/dmg_staging"
VOL_NAME="${APP_NAME}"

echo "=================================================="
echo "  Creating Professional macOS Drag-to-Install DMG"
echo "=================================================="

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "❌ Error: ${APP_BUNDLE} not found. Please run ./scripts/build_app.sh first."
    exit 1
fi

# Ensure clean slate
echo "🧹 Cleaning previous staging & temporary DMGs..."
# Unmount existing volume if still mounted
if [ -d "/Volumes/${VOL_NAME}" ]; then
    echo "Unmounting existing /Volumes/${VOL_NAME}..."
    hdiutil detach "/Volumes/${VOL_NAME}" -force || true
    sleep 1
fi

rm -rf "${STAGING_DIR}"
rm -f "${TMP_DMG}"
rm -f "${FINAL_DMG}"
mkdir -p "${STAGING_DIR}/.background"

# 1. Generate Retina background image
echo "🎨 Generating custom retina DMG background..."
swift "${SCRIPT_DIR}/generate_dmg_background.swift" "${STAGING_DIR}/.background/background.png"

# 2. Prepare staging contents
echo "📦 Staging application bundle and /Applications symlink..."
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

# 3. Calculate volume size with headroom for filesystem metadata and DS_Store
STAGING_SIZE_KB=$(du -sk "${STAGING_DIR}" | awk '{print $1}')
DMG_SIZE_KB=$((STAGING_SIZE_KB + 30720)) # +30MB headroom

echo "💾 Creating temporary read-write disk image (${DMG_SIZE_KB} KB)..."
hdiutil create -size "${DMG_SIZE_KB}k" -fs HFS+ -volname "${VOL_NAME}" "${TMP_DMG}"

# 4. Mount writable DMG
echo "💿 Mounting temporary DMG..."
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "${TMP_DMG}")
DEV_NAME=$(echo "${MOUNT_OUTPUT}" | head -n 1 | awk '{print $1}')
MOUNT_DIR="/Volumes/${VOL_NAME}"

if [ ! -d "${MOUNT_DIR}" ]; then
    echo "❌ Error: Failed to mount disk image at ${MOUNT_DIR}"
    exit 1
fi

# 5. Populate volume
echo "🚚 Copying files to mounted volume..."
cp -R "${STAGING_DIR}/${APP_NAME}.app" "${MOUNT_DIR}/"
cp -R "${STAGING_DIR}/.background" "${MOUNT_DIR}/"
ln -s /Applications "${MOUNT_DIR}/Applications"

# 6. Apply Finder styling via AppleScript
echo "🖥️  Configuring Finder window geometry and icon layout..."
osascript <<EOF
tell application "Finder"
    tell disk "${VOL_NAME}"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {300, 180, 900, 560} -- 600 width, 380 height
        
        set viewOptions to the icon view options of container window
        set icon size of viewOptions to 120
        set text size of viewOptions to 12
        set arrangement of viewOptions to not arranged
        set background picture of viewOptions to file ".background:background.png"
        
        -- Position CleanMac on left, Applications on right
        set position of item "${APP_NAME}.app" of container window to {140, 175}
        set position of item "Applications" of container window to {460, 175}
        
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Ensure all filesystem operations are flushed
echo "⏳ Flushing filesystem buffers..."
sync
sleep 2

# 7. Unmount temporary volume
echo "⏏️  Unmounting temporary disk image..."
hdiutil detach "${DEV_NAME}" -force || hdiutil detach "${MOUNT_DIR}" -force
sleep 2

# 8. Convert to compressed, read-only UDZO DMG
echo "🗜️  Converting to high-compression read-only DMG..."
hdiutil convert "${TMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${FINAL_DMG}"

# Also create unversioned alias CleanMac.dmg
cp "${FINAL_DMG}" "${PROJECT_DIR}/build/${APP_NAME}.dmg"

# 9. Clean up
echo "🧹 Cleaning temporary build files..."
rm -rf "${STAGING_DIR}"
rm -f "${TMP_DMG}"

echo "=================================================="
echo "🎉 Drag-to-Install DMG created successfully!"
echo "   Output: ${FINAL_DMG}"
echo "=================================================="
