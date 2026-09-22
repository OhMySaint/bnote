#!/bin/zsh
# Build a signed Release .app, wrap it in a DMG under dist/, optionally install it.
#
#   scripts/package.sh                 # bản ổn định (BNote)
#   scripts/package.sh dev             # bản thử nghiệm (BNote Dev) — dữ liệu riêng
#   scripts/package.sh dev --install   # build xong chép thẳng vào /Applications
#   scripts/package.sh --install        # cài bản ổn định
#   scripts/package.sh dev --identity "Apple Development: ..."
#
# Hai bản khác bundle id nên macOS cấp container riêng: trang, cài đặt và store
# của bản này không đụng bản kia. Bản Dev có nhãn cam "DEV" trong Tổng quan.
set -euo pipefail
cd "$(dirname "$0")/.."

FLAVOUR=stable
INSTALL=no
IDENTITY=""
while (( $# )); do
  case "$1" in
    dev|stable) FLAVOUR="$1" ;;
    --install) INSTALL=yes ;;
    --identity) IDENTITY="$2"; shift ;;
    *) echo "không hiểu tham số: $1"; exit 1 ;;
  esac
  shift
done

VERSION=$(sed -n 's/.*MARKETING_VERSION = \([0-9.]*\);.*/\1/p' BNote.xcodeproj/project.pbxproj | head -1)
: "${IDENTITY:=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development[^"]*\)".*/\1/p' | head -1)}"

if [[ "$FLAVOUR" == dev ]]; then
  APP_NAME="BNote Dev"
  BUNDLE_ID="com.hoangson.BNote.dev"
  DMG="dist/BNote-Dev-$VERSION.dmg"
else
  APP_NAME="BNote"
  BUNDLE_ID="com.hoangson.BNote"
  DMG="dist/BNote-$VERSION.dmg"
fi
STAGING="dist/staging-$FLAVOUR"
BUILD_DIR="build-release-$FLAVOUR"

rm -rf "$STAGING" "$BUILD_DIR"
mkdir -p "$STAGING"

xcodebuild -project BNote.xcodeproj -scheme BNote -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  PRODUCT_NAME="$APP_NAME" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CODE_SIGN_IDENTITY="$IDENTITY" CODE_SIGN_STYLE=Manual build | grep -E "error:|BUILD"

cp -R "$BUILD_DIR/Build/Products/Release/$APP_NAME.app" "$STAGING/"
codesign --verify --deep --strict "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"
cp "scripts/READ ME FIRST.txt" "$STAGING/"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
echo "→ $DMG  ($BUNDLE_ID)"

if [[ "$INSTALL" == yes ]]; then
  pkill -x "$APP_NAME" 2>/dev/null || true
  sleep 1
  rm -rf "/Applications/$APP_NAME.app"
  ditto "$STAGING/$APP_NAME.app" "/Applications/$APP_NAME.app"
  echo "→ đã cài /Applications/$APP_NAME.app"
fi
