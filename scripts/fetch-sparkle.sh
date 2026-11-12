#!/bin/sh
# Download the pinned Sparkle release into vendor/ (not committed).
set -e
cd "$(dirname "$0")/.."
VERSION=2.10.1
SHA256=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
DIR=vendor/Sparkle-$VERSION
[ -d "$DIR/Sparkle.framework" ] && exit 0
mkdir -p "$DIR"
TARBALL="vendor/Sparkle-$VERSION.tar.xz"
curl -fsSL -o "$TARBALL" "https://github.com/sparkle-project/Sparkle/releases/download/$VERSION/Sparkle-$VERSION.tar.xz"
echo "$SHA256  $TARBALL" | shasum -a 256 -c -
tar -xJf "$TARBALL" -C "$DIR"
rm "$TARBALL"
echo "Sparkle $VERSION ready in $DIR"
