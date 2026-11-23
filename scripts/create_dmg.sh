#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "🔨 Ensuring latest release build of tiffy-cut.app..."
./scripts/build_app.sh

DMG_TMP="${PROJECT_DIR}/.build_dmg"
DMG_OUTPUT="${PROJECT_DIR}/tiffy-cut-Installer.dmg"

echo "📦 Preparing DMG installer directory structure..."
rm -rf "${DMG_TMP}"
mkdir -p "${DMG_TMP}"

cp -R "${PROJECT_DIR}/tiffy-cut.app" "${DMG_TMP}/tiffy-cut.app"
ln -s /Applications "${DMG_TMP}/Applications"

cat << 'EOF' > "${DMG_TMP}/How to Install.txt"
===================================================
  ✂️ tiffy-cut - Video Editor & Collage Studio for Mac
===================================================

1. INSTALLATION:
   Drag "tiffy-cut.app" into the "Applications" shortcut icon.

2. FIRST-TIME OPEN (macOS Gatekeeper):
   If macOS warns "cannot be opened because the developer cannot be verified":
   - Open System Settings > Privacy & Security -> click "Open Anyway".
   - Or run in Terminal:
     xattr -cr /Applications/tiffy-cut.app

3. FEATURES (v1.0.0):
   - Collage: Create 9:16 (TikTok/Reels), 4:5 (IG Feed), and 1:1 video collages
     with 8 grid layouts, pan/zoom framing, trim, per-slot audio, and 1080p MP4 export.
===================================================
EOF

echo "📀 Creating DMG disk image: ${DMG_OUTPUT}..."
rm -f "${DMG_OUTPUT}"
hdiutil create -volname "tiffy-cut Installer" -srcfolder "${DMG_TMP}" -ov -format UDZO "${DMG_OUTPUT}"
rm -rf "${DMG_TMP}"

ZIP_OUTPUT="${PROJECT_DIR}/tiffy-cut.zip"
echo "🗜️ Creating ZIP archive: ${ZIP_OUTPUT}..."
rm -f "${ZIP_OUTPUT}"
ditto -c -k --keepParent "${PROJECT_DIR}/tiffy-cut.app" "${ZIP_OUTPUT}"

TIFFY_DIR="$(cd "${PROJECT_DIR}/.." && pwd)/tiffy-app/tiffy-cut"
mkdir -p "${TIFFY_DIR}"
echo "📦 Syncing DMG and ZIP to ${TIFFY_DIR}..."
cp -f "${DMG_OUTPUT}" "${TIFFY_DIR}/tiffy-cut-Installer.dmg"
cp -f "${ZIP_OUTPUT}" "${TIFFY_DIR}/tiffy-cut.zip"

echo "🎉 DMG and ZIP packages successfully created!"
ls -lh "${DMG_OUTPUT}" "${ZIP_OUTPUT}"
