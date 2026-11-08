#!/usr/bin/env bash
# Packages build/MagicMousePad.app into a drag-to-Applications DMG.
set -euo pipefail

cd "$(dirname "$0")/.."
APP="build/MagicMousePad.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="build/MagicMousePad-$VERSION.dmg"
STAGE="build/dmg"

[[ -d "$APP" ]] || { echo "Run scripts/build-app.sh first"; exit 1; }

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "MagicMousePad" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
echo "✓ Built $DMG"
