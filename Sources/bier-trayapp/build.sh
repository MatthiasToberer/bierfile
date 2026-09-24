#!/bin/sh
#
# Builds BierMenu.app. Needs only the Command Line Tools, no Xcode project.
#
#   ./Sources/bier-trayapp/build.sh            builds BierMenu.app
#   ./Sources/bier-trayapp/build.sh --install  builds and installs it

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
BUILD=$HERE/build
APP=$BUILD/BierMenu.app

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

# The version number lives in bier-core/bier and is taken from there, so that
# app and script never drift apart. Hence an unquoted here-document:
# $VERSION is meant to be substituted.
VERSION=$(sed -nE 's/^BIER_VERSION=(.*)$/\1/p' "$ROOT/Sources/bier-core/bier")
[ -n "$VERSION" ] || VERSION=0

cat >"$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>BierMenu</string>
	<key>CFBundleDisplayName</key><string>Bier</string>
	<key>CFBundleIdentifier</key><string>net.toberer.biermenu</string>
	<key>CFBundleExecutable</key><string>BierMenu</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>$VERSION</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
	<!-- Menu bar app: no dock icon, no menu at the top left. -->
	<key>LSUIElement</key><true/>
</dict>
</plist>
EOF

printf 'APPL????' >"$APP/Contents/PkgInfo"

swiftc -O \
	-target arm64-apple-macos13.0 \
	-framework AppKit -framework ServiceManagement \
	-o "$APP/Contents/MacOS/BierMenu" \
	"$HERE/Glass.swift" "$HERE/main.swift"

# Ad-hoc signieren. Ohne Signatur verweigert macOS den Start als
# a login item, and SMAppService needs a stable identity.
# Die Ausgabe interessiert nur, wenn es schiefgeht.
if ! out=$(codesign --force --sign - --identifier net.toberer.biermenu "$APP" 2>&1); then
	printf '%s\n' "$out" >&2
	exit 1
fi

echo "built: $APP"

if [ "${1:-}" = "--install" ]; then
	mkdir -p "${BIER_BARREL:-$HOME/.barrel}"
	rm -rf "${BIER_BARREL:-$HOME/.barrel}/BierMenu.app"
	cp -R "$APP" "${BIER_BARREL:-$HOME/.barrel}/"
	echo "installed: ${BIER_BARREL:-$HOME/.barrel}/BierMenu.app"
fi
