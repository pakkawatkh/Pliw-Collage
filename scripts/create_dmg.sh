#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "🔨 Ensuring latest release build of Pliw Collage.app..."
./scripts/build_app.sh

if [ -d "$(cd "${PROJECT_DIR}/.." && pwd)/public" ]; then
    PLIW_DIR="$(cd "${PROJECT_DIR}/.." && pwd)/public/pliw-collage"
else
    PLIW_DIR="$(cd "${PROJECT_DIR}/.." && pwd)/Pliw-App/pliw-collage"
fi
mkdir -p "${PLIW_DIR}"

DMG_TMP="$(mktemp -d)"
trap 'rm -rf "${DMG_TMP}"' EXIT
DMG_OUTPUT="${PLIW_DIR}/pliw-collage-Installer.dmg"
ZIP_OUTPUT="${PLIW_DIR}/pliw-collage.zip"

echo "📦 Preparing DMG installer directory structure..."
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
rm -f "${DMG_OUTPUT}" "${PROJECT_DIR}/pliw-collage-Installer.dmg"
hdiutil create -volname "Pliw Collage Installer" -srcfolder "${DMG_TMP}" -ov -format UDZO "${DMG_OUTPUT}"

echo "🗜️ Creating ZIP archive: ${ZIP_OUTPUT}..."
rm -f "${ZIP_OUTPUT}" "${PROJECT_DIR}/pliw-collage.zip"
ditto -c -k --keepParent "${PROJECT_DIR}/Pliw Collage.app" "${ZIP_OUTPUT}"

# Remove temporary local .app bundle so build outputs stay only in public/
rm -rf "${PROJECT_DIR}/Pliw Collage.app"

echo "🎉 DMG and ZIP packages successfully created in ${PLIW_DIR}!"
ls -lh "${DMG_OUTPUT}" "${ZIP_OUTPUT}"
