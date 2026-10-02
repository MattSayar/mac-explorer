#!/usr/bin/env bash
# Builds MacExplorer and assembles a runnable MacExplorer.app bundle.
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/MacExplorer"

APP="$ROOT/build/MacExplorer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacExplorer"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature so macOS will grant the bundle file-access permissions.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || \
    echo "warning: ad-hoc codesign failed; the app may not be able to request folder access"

echo "Built $APP"
echo "Run with: open '$APP'"
