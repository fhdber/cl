#!/usr/bin/env bash
# Builds Clipline.app into ./build and (optionally) copies it to /Applications.
#   ./scripts/build-app.sh            → build/Clipline.app
#   ./scripts/build-app.sh --install  → also copies to /Applications and launches it
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Clipline"

APP="build/Clipline.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Clipline"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS can remember the Accessibility permission.
codesign --force --deep --sign - "$APP"

echo "✓ $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Clipline 2>/dev/null || true
  rm -rf /Applications/Clipline.app
  cp -R "$APP" /Applications/
  open /Applications/Clipline.app
  echo "✓ installiert & gestartet"
fi
