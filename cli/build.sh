#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
out=${1:-"$here/build/bier-peer"}

swift build --package-path "$root" -c release --product bier-peer >/dev/null
bin=$(swift build --package-path "$root" -c release --show-bin-path)/bier-peer
mkdir -p "$(dirname "$out")"
cp "$bin" "$out"
chmod 700 "$out"
printf '%s\n' "built: $out"
