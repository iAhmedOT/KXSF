#!/bin/sh
# Builds AppIcon.icns for the Mac app with Apple's iconutil from the ten Mac
# slots already referenced by AppIcon.appiconset/Contents.json, replacing the
# incomplete ICNS that actool emits. Runs after resource compilation and before
# code signing. Invoke as: /bin/sh make_mac_icns.sh <appiconset dir> <output .icns> <work dir>
set -eu
SRC="$1"; OUT="$2"; WORK="$3"
SET="$WORK/AppIcon.iconset"
rm -rf "$SET"
mkdir -p "$SET" "$(dirname "$OUT")"
cp "$SRC/AppIcon-mac-16x16@1x.png"   "$SET/icon_16x16.png"
cp "$SRC/AppIcon-mac-16x16@2x.png"   "$SET/icon_16x16@2x.png"
cp "$SRC/AppIcon-mac-32x32@1x.png"   "$SET/icon_32x32.png"
cp "$SRC/AppIcon-mac-32x32@2x.png"   "$SET/icon_32x32@2x.png"
cp "$SRC/AppIcon-mac-128x128@1x.png" "$SET/icon_128x128.png"
cp "$SRC/AppIcon-mac-128x128@2x.png" "$SET/icon_128x128@2x.png"
cp "$SRC/AppIcon-mac-256x256@1x.png" "$SET/icon_256x256.png"
cp "$SRC/AppIcon-mac-256x256@2x.png" "$SET/icon_256x256@2x.png"
cp "$SRC/AppIcon-mac-512x512@1x.png" "$SET/icon_512x512.png"
cp "$SRC/AppIcon-mac-512x512@2x.png" "$SET/icon_512x512@2x.png"
/usr/bin/iconutil -c icns "$SET" -o "$OUT"
