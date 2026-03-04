#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUILD_DIR="$DIST_DIR/build"
APP_NAME="CourseIslandApp"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_PATH="$CONTENTS_DIR/Info.plist"
ZIP_PATH="$DIST_DIR/$APP_NAME-macOS-arm64.zip"

echo "==> Building release binary"
swift build -c release --product "$APP_NAME" --package-path "$ROOT_DIR"

BIN_DIR="$(swift build -c release --show-bin-path --package-path "$ROOT_DIR")"
EXECUTABLE_PATH="$BIN_DIR/$APP_NAME"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "Release executable not found: $EXECUTABLE_PATH" >&2
  exit 1
fi

echo "==> Preparing app bundle"
rm -rf "$APP_BUNDLE" "$BUILD_DIR" "$ZIP_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"

cat > "$PLIST_PATH" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>课程岛</string>
    <key>CFBundleExecutable</key>
    <string>CourseIslandApp</string>
    <key>CFBundleIdentifier</key>
    <string>local.courseisland.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>课程岛</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.education</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>课程岛需要读取 Apple Music 或 Spotify 的当前播放信息，用于在顶部胶囊显示正在播放。</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>课程岛需要访问日历，以便将课程表同步到 Apple Calendar。</string>
    <key>NSCalendarsUsageDescription</key>
    <string>课程岛需要访问日历，以便将课程表同步到 Apple Calendar。</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Applying ad-hoc signature"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Verifying bundle"
codesign --verify --deep --strict "$APP_BUNDLE"

echo "==> Creating zip archive"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo ""
echo "Done."
echo "App bundle: $APP_BUNDLE"
echo "Zip archive: $ZIP_PATH"
echo "Note: this build is ad-hoc signed. For smooth external distribution, sign with Developer ID and notarize."
