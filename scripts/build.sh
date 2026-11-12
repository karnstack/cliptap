#!/bin/sh
# Build build/Cliptap.app as a universal (Apple silicon + Intel) app.
#
#   scripts/build.sh            build only
#   scripts/build.sh --install  build, then copy to ~/Applications and open it
#
# Signing: set DEVELOPER_ID="Developer ID Application: Name (TEAMID)" to sign for
# distribution. Without it the app gets an ad-hoc signature (fine for local use).
set -e
cd "$(dirname "$0")/.."

./scripts/fetch-sparkle.sh >/dev/null
SPARKLE=vendor/Sparkle-2.10.1
VERSION=$(cat VERSION)
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 1)
APP=build/Cliptap.app

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$ARCH-apple-macosx14.0" \
    -F "$SPARKLE" -framework Sparkle \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    Sources/*.swift -o "build/Cliptap-$ARCH"
done
lipo -create build/Cliptap-arm64 build/Cliptap-x86_64 -output "$APP/Contents/MacOS/Cliptap"
rm build/Cliptap-arm64 build/Cliptap-x86_64

cp Resources/Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD" "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
ditto "$SPARKLE/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"

# Sign inside-out, as the Sparkle docs describe.
if [ -n "$DEVELOPER_ID" ]; then
  SIGN="codesign --force --timestamp --options runtime --sign"
  ID="$DEVELOPER_ID"
else
  SIGN="codesign --force --sign"
  ID="-"
fi
FW="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
$SIGN "$ID" "$FW/XPCServices/Installer.xpc"
$SIGN "$ID" --preserve-metadata=entitlements "$FW/XPCServices/Downloader.xpc"
$SIGN "$ID" "$FW/Autoupdate"
$SIGN "$ID" "$FW/Updater.app"
$SIGN "$ID" "$APP/Contents/Frameworks/Sparkle.framework"
$SIGN "$ID" "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP (version $VERSION, build $BUILD)"

if [ "$1" = "--install" ]; then
  pkill -x Cliptap 2>/dev/null || true
  mkdir -p ~/Applications
  rm -rf ~/Applications/Cliptap.app
  ditto "$APP" ~/Applications/Cliptap.app
  open ~/Applications/Cliptap.app
  echo "Installed to ~/Applications/Cliptap.app"
fi
