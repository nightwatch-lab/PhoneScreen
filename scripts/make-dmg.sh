#!/usr/bin/env bash
# Build PhoneScreen.app and package it as build/PhoneScreen.dmg. Run on a Mac.
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/make-app.sh

STAGE="build/dmg-stage"
DMG="build/PhoneScreen.dmg"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R build/PhoneScreen.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname PhoneScreen -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
echo "已生成 $(pwd)/$DMG"
