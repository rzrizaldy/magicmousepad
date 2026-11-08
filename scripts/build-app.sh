#!/usr/bin/env bash
# Builds a universal (Apple silicon + Intel) MagicMousePad.app into ./build.
#
#   scripts/build-app.sh                 # ad-hoc signed
#   SIGN_IDENTITY="Developer ID Application: …" scripts/build-app.sh
set -euo pipefail

cd "$(dirname "$0")/.."
APP_NAME="MagicMousePad"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
ARCHS="${ARCHS:-arm64 x86_64}"

arch_flags=()
for a in $ARCHS; do arch_flags+=(--arch "$a"); done

echo "→ Compiling (${ARCHS})…"
swift build -c release "${arch_flags[@]}"
BIN_DIR="$(swift build -c release "${arch_flags[@]}" --show-bin-path)"

echo "→ Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if [[ -n "${VERSION:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
fi

echo "→ Signing…"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi

echo "✓ Built $APP"
