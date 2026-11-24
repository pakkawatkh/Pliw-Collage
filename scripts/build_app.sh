#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "🔨 Building Pliw Collage (Release mode)..."
swift build -c release -Xswiftc -cross-module-optimization

RELEASE_BIN="${PROJECT_DIR}/.build/release/pliw-collage"
APP_DIR="${PROJECT_DIR}/Pliw Collage.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Assembling Pliw Collage.app bundle..."
rm -rf "${PROJECT_DIR}/pliw-cut.app" "${PROJECT_DIR}/Pliw Cut.app" "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${RELEASE_BIN}" "${MACOS_DIR}/pliw-collage"
strip "${MACOS_DIR}/pliw-collage"
chmod +x "${MACOS_DIR}/pliw-collage"

if [ -d "${PROJECT_DIR}/Resources" ]; then
    cp -R "${PROJECT_DIR}/Resources/"* "${RESOURCES_DIR}/" || true
fi

cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>pliw-collage</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.pliw-collage</string>
    <key>CFBundleName</key>
    <string>Pliw Collage</string>
    <key>CFBundleDisplayName</key>
    <string>Pliw Collage</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>3.1.2</string>
    <key>CFBundleVersion</key>
    <string>3.1.2</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.video</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo "🔏 Code signing Pliw Collage.app..."
SIGN_CERT="MonkeyToolsDeveloper"
if ! security find-certificate -c "${SIGN_CERT}" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
    if security find-certificate -c "MonkeyCopyDeveloper" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
        SIGN_CERT="MonkeyCopyDeveloper"
    fi
fi
codesign --force --deep --sign "${SIGN_CERT}" "${APP_DIR}" || codesign --force --deep --sign - "${APP_DIR}"

echo "✅ Successfully built: ${APP_DIR}"

if [ -z "${SKIP_INSTALL}" ]; then
    echo "📲 Updating /Applications/Pliw Collage.app..."
    pkill -9 -f "Pliw Collage.app" || true
    pkill -9 -f "Pliw Cut.app" || true
    pkill -9 -f "pliw-cut.app" || true
    rm -rf "/Applications/pliw-cut.app" "/Applications/Pliw Cut.app" "/Applications/Pliw Collage.app" "/Applications/ClipCollage.app"
    cp -R "${APP_DIR}" "/Applications/Pliw Collage.app"
    echo "🎉 Installed /Applications/Pliw Collage.app"
else
    echo "⏭️ Skipping install to /Applications because SKIP_INSTALL is set."
fi
