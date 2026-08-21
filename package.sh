#!/bin/bash
# Builds Waymark.app from the SwiftPM executable.
#
# SwiftPM has no notion of an app bundle, so the bundle is assembled here:
# binary + Info.plist + icon, then ad-hoc signed (unsigned bundles get killed
# by Gatekeeper on launch). Run this instead of a bare `swift build` whenever
# you want to actually launch the app — a plain rebuild leaves the old binary
# inside Waymark.app.
#
#   ./package.sh             build, bundle, sign
#   ./package.sh --run       ...and launch it from here
#   ./package.sh --icon      ...regenerating AppIcon.icns from icon.png first
#   ./package.sh --install   ...and install into /Applications (see below)
#
# Spotlight only treats a bundle as an *application* when it lives in a
# recognized apps folder — /Applications or ~/Applications. A build sitting in
# this project directory will never come up for ⌘-Space, so --install is what
# makes the app searchable, and the installed copy is the one to launch day to
# day.

set -euo pipefail
cd "$(dirname "$0")"

APP="Waymark.app"
CONTENTS="$APP/Contents"
BUNDLE_ID="com.weicheng.waymark"

if [[ " $* " == *" --icon "* ]]; then
  echo "==> Regenerating AppIcon.icns from icon.png"
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z $size $size icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  mkdir -p Resources
  iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
fi

echo "==> Building release binary"
swift build -c release

echo "==> Assembling $APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp .build/release/Waymark "$CONTENTS/MacOS/Waymark"
cp Resources/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Waymark</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleName</key><string>Waymark</string>
  <key>CFBundleDisplayName</key><string>Waymark</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleSignature</key><string>????</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleShortVersionString</key><string>2.2</string>
  <key>CFBundleVersion</key><string>4</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.travel</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHumanReadableCopyright</key><string>Waymark</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Signing"
codesign --force --deep --sign - "$APP"
touch "$APP"

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
TARGET="$APP"

if [[ " $* " == *" --install "* ]]; then
  DEST="/Applications"
  [ -w "$DEST" ] || DEST="$HOME/Applications"
  mkdir -p "$DEST"
  echo "==> Installing to $DEST"
  rm -rf "$DEST/$APP"
  cp -R "$APP" "$DEST/$APP"
  touch "$DEST/$APP"
  TARGET="$DEST/$APP"

  # Register with Launch Services, then force a Spotlight index pass so the app
  # is findable from ⌘-Space immediately instead of whenever mds next sweeps.
  "$LSREGISTER" -f "$TARGET" 2>/dev/null || true
  mdimport "$TARGET" 2>/dev/null || true
else
  "$LSREGISTER" -f "$APP" 2>/dev/null || true
fi

echo "==> Done: $TARGET"

if [[ " $* " == *" --run "* ]]; then
  pkill -f "$APP" 2>/dev/null || true
  sleep 1
  open "$TARGET"
fi
