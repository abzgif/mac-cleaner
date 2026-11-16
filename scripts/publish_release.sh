#!/usr/bin/env bash
set -e

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist 2>/dev/null || echo "1.1.0")
TAG="v${VERSION}"
REPO="abzgif/mac-cleaner"

echo "=================================================="
echo "  CleanMac ${TAG} — GitHub Release Publisher"
echo "=================================================="

# 1. Build Drag-to-Install DMG if not already built
if [ ! -f "build/CleanMac-${VERSION}.dmg" ]; then
    echo "💿 Building Drag-to-Install DMG (build/CleanMac-${VERSION}.dmg)..."
    VERSION="${VERSION}" bash scripts/create_dmg.sh || true
fi

# 2. Push commit and tag to origin
echo "🚀 Pushing 'main' branch and tag '${TAG}' to GitHub..."
git push origin main
git push origin "${TAG}" --force

# 3. Create GitHub Release via gh CLI or GitHub REST API
if command -v gh >/dev/null 2>&1; then
    ASSETS=("build/CleanMac-${VERSION}.zip" "build/CleanMac.zip")
    if [ -f "build/CleanMac-${VERSION}.dmg" ]; then
        ASSETS+=("build/CleanMac-${VERSION}.dmg")
    fi
    gh release create "${TAG}" "${ASSETS[@]}" \
        --title "CleanMac ${TAG}" \
        --notes-file - <<EOF
## What's New in CleanMac ${TAG}

- **In-App Update Checker & One-Click Installer**: Check for updates directly in **Settings & Protection** and install new versions automatically.
- **Streamlined Minimal 4-Tab UI**: Rebuilt interface around **Smart Clean**, **Applications**, **Storage Explorer**, and **Settings & Protection** with live storage telemetry.
- **SDK & Developer Cache Cleanup**: Clean individual Android SDK images/NDKs/platforms, Gradle, Maven, Xcode/Simulator SDKs, and package manager caches on demand.
- **Multi-Select App Uninstaller**: Select multiple apps with checkboxes or \`Select All\` to batch-uninstall applications and clean their residual files.
- **Hardened App & IDE Protection**: Protects \`~/Library/Application Support\`, \`~/Library/Preferences\`, \`.app\` bundle signatures, JDownloader 2, and Android Studio IDE state.
EOF
    echo "🎉 GitHub Release ${TAG} published successfully!"
    exit 0
fi

TOKEN="${GITHUB_TOKEN:-$(printf "protocol=https\nhost=github.com\n\n" | git credential fill 2>/dev/null | sed -n 's/^password=//p')}"
if [ -z "$TOKEN" ]; then
    echo "ℹ️ To publish the GitHub Release assets via API, run:"
    echo "   GITHUB_TOKEN=your_token ./scripts/publish_release.sh"
    exit 0
fi

NOTES="## What's New in CleanMac ${TAG}\n\n- **In-App Update Checker & One-Click Installer**: Check for updates directly in Settings and install new versions automatically.\n- **Streamlined Minimal 4-Tab UI**: Rebuilt interface around Smart Clean, Applications, Storage Explorer, and Settings & Protection with live storage telemetry.\n- **SDK & Developer Cache Cleanup**: Clean individual Android SDK images/NDKs/platforms, Gradle, Maven, Xcode/Simulator SDKs, and package manager caches on demand.\n- **Multi-Select App Uninstaller**: Select multiple apps with checkboxes or Select All to batch-uninstall applications and clean their residual files.\n- **Hardened App & IDE Protection**: Protects ~/Library/Application Support, ~/Library/Preferences, .app bundle signatures, JDownloader 2, and Android Studio IDE state."

PAYLOAD=$(cat <<EOF
{
  "tag_name": "${TAG}",
  "target_commitish": "main",
  "name": "CleanMac ${TAG}",
  "body": "${NOTES}",
  "draft": false,
  "prerelease": false
}
EOF
)

RESPONSE=$(curl -sS -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${TOKEN}" \
  "https://api.github.com/repos/${REPO}/releases" \
  -d "${PAYLOAD}")

RELEASE_ID=$(echo "$RESPONSE" | sed -n 's/.*"id": \([0-9]*\).*/\1/p' | head -n 1)
HTML_URL=$(echo "$RESPONSE" | sed -n 's/.*"html_url": "\([^"]*\)".*/\1/p' | head -n 1)

if [ -n "$RELEASE_ID" ]; then
    for FILE in "build/CleanMac-${VERSION}.zip" "build/CleanMac.zip" "build/CleanMac-${VERSION}.dmg"; do
        if [ -f "$FILE" ]; then
            FILENAME=$(basename "$FILE")
            echo "⬆️ Uploading ${FILENAME}..."
            curl -sS -X POST \
              -H "Accept: application/vnd.github+json" \
              -H "Authorization: Bearer ${TOKEN}" \
              -H "Content-Type: application/octet-stream" \
              --data-binary @"$FILE" \
              "https://uploads.github.com/repos/${REPO}/releases/${RELEASE_ID}/assets?name=${FILENAME}" >/dev/null
        fi
    done
    echo "🎉 Release published at: ${HTML_URL}"
fi
