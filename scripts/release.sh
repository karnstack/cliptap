#!/bin/sh
# Build, sign, and publish a release to GitHub with a Sparkle appcast.
#
# Before running: bump VERSION, commit, and push.
# Needs: gh (logged in), and the Sparkle private key in your Keychain
#        (account "cliptap", created with vendor/Sparkle-*/bin/generate_keys --account cliptap).
# Optional: DEVELOPER_ID and NOTARY_PROFILE (an `xcrun notarytool store-credentials` profile)
#           to sign with Developer ID and notarize, so users get no Gatekeeper warning.
set -e
cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
TAG="v$VERSION"
REPO=karnstack/cliptap
ZIP="Cliptap.zip"

if [ -n "$(git status --porcelain)" ]; then echo "Commit your changes first."; exit 1; fi
if gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then echo "Release $TAG already exists. Bump VERSION."; exit 1; fi

./scripts/build.sh
rm -rf dist && mkdir dist

if [ -n "$DEVELOPER_ID" ] && [ -n "$NOTARY_PROFILE" ]; then
  ditto -c -k --keepParent build/Cliptap.app dist/notarize.zip
  xcrun notarytool submit dist/notarize.zip --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple build/Cliptap.app
  rm dist/notarize.zip
fi

ditto -c -k --sequesterRsrc --keepParent build/Cliptap.app "dist/$ZIP"

# sign_update prints: sparkle:edSignature="..." length="..."
SIGNATURE=$(vendor/Sparkle-2.10.1/bin/sign_update --account cliptap "dist/$ZIP")
BUILD=$(plutil -extract CFBundleVersion raw build/Cliptap.app/Contents/Info.plist)

cat > dist/appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Cliptap</title>
    <item>
      <title>Version $VERSION</title>
      <link>https://github.com/$REPO/releases/tag/$TAG</link>
      <sparkle:releaseNotesLink>https://github.com/$REPO/releases/tag/$TAG</sparkle:releaseNotesLink>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure url="https://github.com/$REPO/releases/download/$TAG/$ZIP" type="application/octet-stream" $SIGNATURE />
    </item>
  </channel>
</rss>
XML

gh release create "$TAG" "dist/$ZIP" dist/appcast.xml -R "$REPO" \
  --title "Cliptap $VERSION" --generate-notes
echo "Released $TAG"
