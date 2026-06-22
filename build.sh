#!/bin/bash
# Builds TitleCase.app (a menu-bar app with a global hotkey) with no external
# dependencies, and installs it to ~/Applications.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$PROJECT_DIR/src"
APP_NAME="TitleCase"
INSTALL_DIR="$HOME/Applications"
APP="$INSTALL_DIR/$APP_NAME.app"

# Use the first .icon document found in the project directory. Its base name
# (e.g. "TitleCaseApp") is the asset name actool expects and the Info.plist
# keys must reference.
ICON_SRC="$(/bin/ls -d "$PROJECT_DIR"/*.icon 2>/dev/null | head -1 || true)"
ICON_NAME=""
if [ -n "$ICON_SRC" ] && [ -d "$ICON_SRC" ]; then
    ICON_NAME="$(basename "$ICON_SRC" .icon)"
fi

echo "==> Compiling (universal: arm64 + x86_64)…"
BUILD="$(mktemp -d)"
DEPLOY="12.0"
swiftc -O -target "arm64-apple-macos$DEPLOY"  "$SRC"/*.swift -o "$BUILD/tc-arm64"
swiftc -O -target "x86_64-apple-macos$DEPLOY" "$SRC"/*.swift -o "$BUILD/tc-x86_64"
BIN="$BUILD/$APP_NAME"
lipo -create "$BUILD/tc-arm64" "$BUILD/tc-x86_64" -o "$BIN"

echo "==> Assembling bundle…"
mkdir -p "$INSTALL_DIR"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>     <string>Title Case</string>
    <key>CFBundleExecutable</key>      <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>      <string>com.mkclvrt.titlecase</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>12.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHumanReadableCopyright</key><string>mkclvrt</string>
</dict>
</plist>
PLIST

if [ -n "$ICON_NAME" ]; then
    echo "==> Compiling icon ($ICON_NAME.icon)…"
    actool "$ICON_SRC" \
        --compile "$APP/Contents/Resources" \
        --app-icon "$ICON_NAME" \
        --platform macosx \
        --minimum-deployment-target 26.0 \
        --output-partial-info-plist "$(mktemp)" \
        --output-format human-readable-text >/dev/null
    # Point the bundle at the compiled icon.
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string $ICON_NAME" \
        -c "Add :CFBundleIconName string $ICON_NAME" "$APP/Contents/Info.plist"
else
    echo "==> No .icon document found in project, skipping icon."
fi

# Prefer a stable self-signed identity (see setup-cert.sh) so TCC permissions
# like Accessibility persist across rebuilds. Fall back to ad-hoc if absent.
CERT_NAME="TitleCase Self-Signed"
if security find-identity -p codesigning 2>/dev/null | grep -q "$CERT_NAME"; then
    echo "==> Signing with '$CERT_NAME'…"
    codesign --force --deep --sign "$CERT_NAME" "$APP"
else
    echo "==> No self-signed identity found (run ./setup-cert.sh); using ad-hoc…"
    codesign --force --deep --sign - "$APP"
fi

echo "==> Installed: $APP"
echo "    Launch with:  open \"$APP\""
