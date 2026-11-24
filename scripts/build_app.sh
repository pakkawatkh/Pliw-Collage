#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "🔨 Building Tiffy Cut (Release mode)..."
swift build -c release -Xswiftc -cross-module-optimization

RELEASE_BIN="${PROJECT_DIR}/.build/release/tiffy-cut"
APP_DIR="${PROJECT_DIR}/Tiffy Cut.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Assembling Tiffy Cut.app bundle..."
rm -rf "${PROJECT_DIR}/tiffy-cut.app" "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${RELEASE_BIN}" "${MACOS_DIR}/tiffy-cut"
strip "${MACOS_DIR}/tiffy-cut"
chmod +x "${MACOS_DIR}/tiffy-cut"

if [ -d "${PROJECT_DIR}/Resources" ]; then
    cp -R "${PROJECT_DIR}/Resources/"* "${RESOURCES_DIR}/" || true
fi

cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>tiffy-cut</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.tiffy-cut</string>
    <key>CFBundleName</key>
    <string>Tiffy Cut</string>
    <key>CFBundleDisplayName</key>
    <string>Tiffy Cut</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.2</string>
    <key>CFBundleVersion</key>
    <string>2.0.2</string>
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

echo "🔏 Code signing Tiffy Cut.app..."
SIGN_CERT="MonkeyToolsDeveloper"
if ! security find-certificate -c "${SIGN_CERT}" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
    if security find-certificate -c "MonkeyCopyDeveloper" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
        SIGN_CERT="MonkeyCopyDeveloper"
    fi
fi
codesign --force --deep --sign "${SIGN_CERT}" "${APP_DIR}" || codesign --force --deep --sign - "${APP_DIR}"

echo "✅ Successfully built: ${APP_DIR}"

if [ -z "${SKIP_INSTALL}" ]; then
    echo "📲 Updating /Applications/Tiffy Cut.app..."
    pkill -9 -f "Tiffy Cut.app" || true
    pkill -9 -f "tiffy-cut.app" || true
    rm -rf "/Applications/tiffy-cut.app" "/Applications/Tiffy Cut.app" "/Applications/ClipCollage.app"
    cp -R "${APP_DIR}" "/Applications/Tiffy Cut.app"
    echo "🎉 Installed /Applications/Tiffy Cut.app"
else
    echo "⏭️ Skipping install to /Applications because SKIP_INSTALL is set."
fi
