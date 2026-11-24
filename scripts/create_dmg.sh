#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "🔨 Ensuring latest release build of Tiffy Cut.app..."
./scripts/build_app.sh

DMG_TMP="${PROJECT_DIR}/.build_dmg"
DMG_OUTPUT="${PROJECT_DIR}/tiffy-cut-Installer.dmg"

echo "📦 Preparing DMG installer directory structure..."
rm -rf "${DMG_TMP}"
mkdir -p "${DMG_TMP}"

cp -R "${PROJECT_DIR}/Tiffy Cut.app" "${DMG_TMP}/Tiffy Cut.app"
ln -s /Applications "${DMG_TMP}/Applications"

cat << 'EOF' > "${DMG_TMP}/How to Install.txt"
===================================================
  ✂️ Tiffy Cut — Video Editor & Collage Studio for Mac
===================================================

1. INSTALLATION:
   Drag "Tiffy Cut.app" into the "Applications" shortcut icon.

2. FIRST-TIME OPEN (macOS Gatekeeper):
   If macOS warns "cannot be opened because the developer cannot be verified":
   - Open System Settings > Privacy & Security -> click "Open Anyway".
   - Or run in Terminal:
     xattr -cr "/Applications/Tiffy Cut.app"

3. FEATURES (v2.0.2):
   - Multi-Track Video Editor: 4-Pane Dark Studio with Split (⌘B), Trim, Speed,
     7 Filters, Transitions, Text Overlays, and 720p–4K H.264/HEVC MP4 export.
   - Collage Studio: 9:16, 4:5, 1:1, 16:9, and custom grids up to 6×6.
===================================================
EOF

echo "📀 Creating DMG disk image: ${DMG_OUTPUT}..."
rm -f "${DMG_OUTPUT}"
hdiutil create -volname "Tiffy Cut Installer" -srcfolder "${DMG_TMP}" -ov -format UDZO "${DMG_OUTPUT}"
rm -rf "${DMG_TMP}"

ZIP_OUTPUT="${PROJECT_DIR}/tiffy-cut.zip"
echo "🗜️ Creating ZIP archive: ${ZIP_OUTPUT}..."
rm -f "${ZIP_OUTPUT}"
ditto -c -k --keepParent "${PROJECT_DIR}/Tiffy Cut.app" "${ZIP_OUTPUT}"

TIFFY_DIR="$(cd "${PROJECT_DIR}/.." && pwd)/tiffy-app/tiffy-cut"
mkdir -p "${TIFFY_DIR}"
echo "📦 Syncing DMG and ZIP to ${TIFFY_DIR}..."
cp -f "${DMG_OUTPUT}" "${TIFFY_DIR}/tiffy-cut-Installer.dmg"
cp -f "${ZIP_OUTPUT}" "${TIFFY_DIR}/tiffy-cut.zip"

echo "🎉 DMG and ZIP packages successfully created!"
ls -lh "${DMG_OUTPUT}" "${ZIP_OUTPUT}"
