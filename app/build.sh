#!/bin/sh
#
# Baut BierMenu.app. Braucht nur die Command Line Tools, kein Xcode-Projekt.
#
#   ./app/build.sh              baut nach app/build/BierMenu.app
#   ./app/build.sh --install    baut und kopiert nach /Applications

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
BUILD=$HERE/build
APP=$BUILD/BierMenu.app

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

# Die Versionsnummer steht in bin/bier und wird hier übernommen, damit
# App und Skript nie auseinanderlaufen. Deshalb ein unquotiertes
# Here-Dokument: $VERSION soll eingesetzt werden.
VERSION=$(sed -nE 's/^BIER_VERSION=(.*)$/\1/p' "$HERE/../bin/bier")
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
	<!-- Menüleisten-App: kein Dock-Symbol, kein Menü oben links. -->
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
# Anmelde-Objekt, und SMAppService braucht eine stabile Identität.
# Die Ausgabe interessiert nur, wenn es schiefgeht.
if ! out=$(codesign --force --sign - --identifier net.toberer.biermenu "$APP" 2>&1); then
	printf '%s\n' "$out" >&2
	exit 1
fi

echo "gebaut: $APP"

if [ "${1:-}" = "--install" ]; then
	rm -rf /Applications/BierMenu.app
	cp -R "$APP" /Applications/
	echo "installiert: /Applications/BierMenu.app"
fi
