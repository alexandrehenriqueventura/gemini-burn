#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="gemini-burn"
MODULE_NAME="GeminiBurnMac"
WIDGET_NAME="GeminiBurnWidget"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
PLUGINS_DIR="$APP_BUNDLE/Contents/PlugIns"
WIDGET_BUNDLE="$PLUGINS_DIR/$WIDGET_NAME.appex"
PYTHON_SRC="$PROJECT_DIR/../gemini-burn-widget"

UNIVERSAL=false
RUN_APP=false
INSTALL_APP=false

for arg in "$@"; do
    case "$arg" in
        --universal) UNIVERSAL=true ;;
        --run) RUN_APP=true ;;
        --install) INSTALL_APP=true ;;
    esac
done

echo "🔨 Building $APP_NAME..."

rm -rf "$APP_BUNDLE"
mkdir -p "$BUILD_DIR/release"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$RESOURCES_DIR"

PATH_MARKER="$BUILD_DIR/.project_path"
if [ ! -f "$PATH_MARKER" ] || [ "$(cat "$PATH_MARKER")" != "$PROJECT_DIR" ]; then
    rm -rf "$BUILD_DIR/ModuleCache"
    printf '%s' "$PROJECT_DIR" > "$PATH_MARKER"
fi

SDK_PATH=$(xcrun --show-sdk-path)
HOST_ARCH=$(uname -m)

compile_arch() {
    local arch="$1"
    local out_bin="$2"
    mkdir -p "$BUILD_DIR/ModuleCache"
    swiftc -O -target "${arch}-apple-macos14.0" -sdk "$SDK_PATH" \
        -module-cache-path "$BUILD_DIR/ModuleCache" \
        -module-name "$MODULE_NAME" \
        -emit-executable -parse-as-library \
        -o "$out_bin" \
        "$PROJECT_DIR/Sources/$MODULE_NAME"/*.swift \
        -framework Cocoa -framework WebKit -framework WidgetKit
}

compile_widget_arch() {
    local arch="$1"
    local out_bin="$2"
    mkdir -p "$BUILD_DIR/ModuleCache"
    swiftc -O -target "${arch}-apple-macos14.0" -sdk "$SDK_PATH" \
        -module-cache-path "$BUILD_DIR/ModuleCache" \
        -module-name "$WIDGET_NAME" \
        -emit-executable -parse-as-library -application-extension \
        -Xlinker -e -Xlinker _NSExtensionMain \
        -o "$out_bin" \
        "$PROJECT_DIR/Sources/$WIDGET_NAME"/*.swift \
        -framework SwiftUI -framework WidgetKit -framework Foundation
}

if [ "$UNIVERSAL" = true ]; then
    echo "📦 Compiling Universal Binary (arm64 + x86_64)..."
    compile_arch "arm64" "$BUILD_DIR/release/${APP_NAME}_arm64"
    compile_arch "x86_64" "$BUILD_DIR/release/${APP_NAME}_x86_64"
    lipo -create -output "$BUILD_DIR/release/$APP_NAME" \
        "$BUILD_DIR/release/${APP_NAME}_arm64" \
        "$BUILD_DIR/release/${APP_NAME}_x86_64"

    compile_widget_arch "arm64" "$BUILD_DIR/release/${WIDGET_NAME}_arm64"
    compile_widget_arch "x86_64" "$BUILD_DIR/release/${WIDGET_NAME}_x86_64"
    lipo -create -output "$BUILD_DIR/release/$WIDGET_NAME" \
        "$BUILD_DIR/release/${WIDGET_NAME}_arm64" \
        "$BUILD_DIR/release/${WIDGET_NAME}_x86_64"
else
    compile_arch "$HOST_ARCH" "$BUILD_DIR/release/$APP_NAME"
    echo "🧩 Building WidgetKit extension ($WIDGET_NAME)..."
    compile_widget_arch "$HOST_ARCH" "$BUILD_DIR/release/$WIDGET_NAME"
fi

cp "$BUILD_DIR/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "$PROJECT_DIR/Sources/$MODULE_NAME/Resources/Info.plist" "$APP_BUNDLE/Contents/"
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

mkdir -p "$WIDGET_BUNDLE/Contents/MacOS"
cp "$BUILD_DIR/release/$WIDGET_NAME" "$WIDGET_BUNDLE/Contents/MacOS/"
cp "$PROJECT_DIR/Sources/$WIDGET_NAME/Resources/Info.plist" "$WIDGET_BUNDLE/Contents/"

echo "📦 Copying Python runtime files..."
if [ -d "$PYTHON_SRC" ]; then
    DEST_PY="$RESOURCES_DIR/gemini-burn-widget"
    mkdir -p "$DEST_PY"
    cp "$PYTHON_SRC/main.py" "$DEST_PY/"
    rsync -a --exclude '__pycache__' --exclude '*.pyc' --exclude '.DS_Store' \
        "$PYTHON_SRC/gemini_burn" "$DEST_PY/"
    echo "✅ Python runtime copied to Resources/gemini-burn-widget"
else
    echo "❌ Python source not found at $PYTHON_SRC"
    exit 1
fi

echo "🔏 Ad-hoc signing WidgetKit extension and app bundle..."
codesign --force --sign - \
    --entitlements "$PROJECT_DIR/Sources/$WIDGET_NAME/Resources/GeminiBurnWidget.entitlements" \
    "$WIDGET_BUNDLE"
codesign --force --sign - "$APP_BUNDLE"

echo "✅ Build complete: $APP_BUNDLE"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
TARGET_APP="$APP_BUNDLE"

if [ "$INSTALL_APP" = true ]; then
    echo "📲 Installing to /Applications/$APP_NAME.app..."
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_BUNDLE" "/Applications/$APP_NAME.app"
    TARGET_APP="/Applications/$APP_NAME.app"
    echo "✅ Installed to $TARGET_APP"
fi

TARGET_WIDGET="$TARGET_APP/Contents/PlugIns/$WIDGET_NAME.appex"
"$LSREGISTER" -f "$TARGET_APP" 2>/dev/null || true
pluginkit -a "$TARGET_WIDGET" 2>/dev/null || true
pluginkit -e use -i "com.geminiburn.mac.widget" 2>/dev/null || true

if [ "$RUN_APP" = true ]; then
    open "$TARGET_APP"
fi
