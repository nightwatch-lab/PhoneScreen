#!/usr/bin/env bash
# Build PhoneScreen.app from the Swift package. Run this on a Mac.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/PhoneScreen"
APP="build/PhoneScreen.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/PhoneScreen"
cp Support/Info.plist "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/PhoneScreen"

# App icon: Support/AppIcon.png (1024×1024) -> AppIcon.icns
mkdir -p "$APP/Contents/Resources"
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Support/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d Support/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP"
fi

echo "已生成 $(pwd)/$APP"
echo "命令行: $APP/Contents/MacOS/PhoneScreen status"
