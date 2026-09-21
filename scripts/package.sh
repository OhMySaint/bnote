#!/bin/zsh
# Build a Release .app, sign it with the available development identity, and
# wrap it in a DMG under dist/. Usage: scripts/package.sh [identity]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(sed -n 's/.*MARKETING_VERSION = \([0-9.]*\);.*/\1/p' BNote.xcodeproj/project.pbxproj | head -1)
IDENTITY="${1:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development[^"]*\)".*/\1/p' | head -1)}"

rm -rf dist build-release
mkdir -p dist/staging

xcodebuild -project BNote.xcodeproj -scheme BNote -configuration Release \
  -derivedDataPath build-release \
  CODE_SIGN_IDENTITY="$IDENTITY" CODE_SIGN_STYLE=Manual build | grep -E "error:|BUILD"

cp -R build-release/Build/Products/Release/BNote.app dist/staging/
codesign --verify --deep --strict dist/staging/BNote.app
ln -s /Applications dist/staging/Applications
cp "scripts/ĐỌC TRƯỚC.txt" dist/staging/

hdiutil create -volname "BNote" -srcfolder dist/staging -ov -format UDZO "dist/BNote-$VERSION.dmg" >/dev/null
echo "→ dist/BNote-$VERSION.dmg"
