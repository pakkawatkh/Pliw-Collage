#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "🔨 Ensuring latest release build of Pliw Collage.app..."
./scripts/build_app.sh

DMG_TMP="${PROJECT_DIR}/.build_dmg"
DMG_OUTPUT="${PROJECT_DIR}/pliw-collage-Installer.dmg"

echo "📦 Preparing DMG installer directory structure..."
rm -rf "${DMG_TMP}"
mkdir -p "${DMG_TMP}"

cp -R "${PROJECT_DIR}/Pliw Collage.app" "${DMG_TMP}/Pliw Collage.app"
ln -s /Applications "${DMG_TMP}/Applications"

cat << 'EOF' > "${DMG_TMP}/How to Install.txt"
===================================================
  🧩 Pliw Collage — Video Collage Studio for Mac
===================================================

1. INSTALLATION:
   Drag "Pliw Collage.app" into the "Applications" shortcut icon.

2. FIRST-TIME OPEN (macOS Gatekeeper):
   If macOS warns "cannot be opened because the developer cannot be verified":
   - Open System Settings > Privacy & Security -> click "Open Anyway".
   - Or run in Terminal:
     xattr -cr "/Applications/Pliw Collage.app"

3. FEATURES (v3.1.2):
   - Video Collage Studio: 9:16, 4:5, 1:1, 16:9, and custom grids up to 6×6.
   - Drag & drop clips, pan/zoom framing, trim, border/corner styling, per-slot audio,
     hardware-accelerated MP4 export, and one-click in-app Auto-Updater.
===================================================
EOF

echo "📀 Creating DMG disk image: ${DMG_OUTPUT}..."
rm -f "${DMG_OUTPUT}"
hdiutil create -volname "Pliw Collage Installer" -srcfolder "${DMG_TMP}" -ov -format UDZO "${DMG_OUTPUT}"
rm -rf "${DMG_TMP}"

ZIP_OUTPUT="${PROJECT_DIR}/pliw-collage.zip"
echo "🗜️ Creating ZIP archive: ${ZIP_OUTPUT}..."
rm -f "${ZIP_OUTPUT}"
ditto -c -k --keepParent "${PROJECT_DIR}/Pliw Collage.app" "${ZIP_OUTPUT}"

if [ -d "$(cd "${PROJECT_DIR}/.." && pwd)/pliw-public" ]; then
    PLIW_DIR="$(cd "${PROJECT_DIR}/.." && pwd)/pliw-public/pliw-collage"
else
    PLIW_DIR="$(cd "${PROJECT_DIR}/.." && pwd)/Pliw-App/pliw-collage"
fi
mkdir -p "${PLIW_DIR}"
echo "📦 Syncing DMG and ZIP to ${PLIW_DIR}..."
cp -f "${DMG_OUTPUT}" "${PLIW_DIR}/pliw-collage-Installer.dmg"
cp -f "${ZIP_OUTPUT}" "${PLIW_DIR}/pliw-collage.zip"

echo "🎉 DMG and ZIP packages successfully created!"
ls -lh "${DMG_OUTPUT}" "${ZIP_OUTPUT}"
