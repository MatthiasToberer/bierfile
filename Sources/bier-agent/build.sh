#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
out=${1:-"$here/build/bier-agent"}
version=$(git -C "$root" describe --tags --always 2>/dev/null || printf '%s' dev)
case $version in
v[0-9]*) ;;
*) version=dev ;;
esac
version_dir=$(mktemp -d /private/tmp/bier-agent-version.XXXXXX)
version_source=$version_dir/main.swift
trap 'rm -rf "$version_dir"' EXIT
{
	printf 'let agentVersion = "%s"\n' "$version"
	cat "$root/Sources/bier-core/swift/DataManifest.swift" "$root/Sources/bier-core/swift/DataSnapshot.swift" "$root/Sources/bier-core/swift/GitRepository.swift" "$root/Sources/bier-core/swift/GitBundleStore.swift" "$here/BierAgent.swift"
} >"$version_source"
mkdir -p "$(dirname "$out")"
swiftc -O -framework Foundation -framework Network -framework CryptoKit -o "$out" "$version_source"
printf '%s\n' "built: $out"
