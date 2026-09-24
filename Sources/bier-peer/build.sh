#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
out=${1:-"$here/build/bier-peer"}

# Built with swiftc, like the agent, not with swift build: SwiftPM's build
# system fails on some Command Line Tools installations ("Could not
# initialize build system ... Unknown error parsing property list"), and
# a Mac should not be kept from installing bier by that.
mkdir -p "$(dirname "$out")"
swiftc -O -parse-as-library -framework Foundation -framework CryptoKit -o "$out" \
	"$root"/Sources/bier-core/swift/*.swift "$here/main.swift"
chmod 700 "$out"
printf '%s\n' "built: $out"
