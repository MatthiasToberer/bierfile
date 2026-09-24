#!/bin/bash
#
# Installs bier with one line, the way Homebrew does:
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/MatthiasToberer/bierfile/main/bootstrap.sh)"
#
# It fetches the latest release into ~/.barrel/bier, checks its signature
# against the key published on a host of its own, and runs install.sh
# from there. Everything bier keeps stays in ~/.barrel.
#
# Options are handed on to install.sh, for example --manual-inventory.

set -euo pipefail

BARREL=${BIER_BARREL:-$HOME/.barrel}
REPO_URL=${BIER_REPO_URL:-https://github.com/MatthiasToberer/bierfile.git}
TRUST_URL=${BIER_RELEASE_TRUST_URL:-https://bier.uber.space/bier/allowed_signers}

say() { printf '\n== %s\n' "$*"; }
ok() { printf '   %s\n' "$*"; }
die() {
	printf '\nbootstrap: %s\n' "$*" >&2
	exit 1
}

[ "$(uname)" = Darwin ] || die "bier runs on macOS only"

# git comes with the Command Line Tools. Without them, macOS offers to
# install them the moment anything asks; this says so first.
if ! xcode-select -p >/dev/null 2>&1 && [ -z "${BIER_TEST_SKIP_CLT:-}" ]; then
	xcode-select --install >/dev/null 2>&1 || true
	die "the Command Line Tools are missing. macOS is installing them now;
   run this line again when that has finished."
fi

if [ -d "$BARREL/bier/.git" ]; then
	say "bier is already installed in $BARREL"
	ok "running its installer again; to move to a newer release: bier upgrade"
	exec /bin/sh "$BARREL/bier/install.sh" "$@"
fi

say "Finding the latest release"
tag=$(git ls-remote --tags --refs "$REPO_URL" 'v*' 2>/dev/null |
	sed -nE 's#.*refs/tags/(v[0-9]+(\.[0-9]+)*)$#\1#p' | sort -V | tail -1)
[ -n "$tag" ] || die "no release found at $REPO_URL"
ok "$tag"

say "Fetching $tag into $BARREL/bier"
mkdir -p "$BARREL"
staging=$BARREL/bier.new
rm -rf "$staging"
trap 'rm -rf "$staging"' EXIT
git clone --quiet --branch "$tag" "$REPO_URL" "$staging" 2>/dev/null ||
	die "could not fetch $tag from $REPO_URL"
ok "fetched"

# The key comes from a host other than the one serving the code, so that
# taking over the code repository does not hand anybody the key.
say "Checking the signature"
signers=$(mktemp)
curl -fsSL --max-time 20 "$TRUST_URL" >"$signers" 2>/dev/null ||
	die "could not fetch the release key from $TRUST_URL"
grep -q 'ssh-ed25519' "$signers" || die "$TRUST_URL holds no release key"
git -C "$staging" -c gpg.ssh.allowedSignersFile="$signers" verify-tag "$tag" >/dev/null 2>&1 ||
	die "$tag is not signed with the published release key. Nothing was installed."
ok "$tag is signed with the release key:"
ssh-keygen -lf "$signers" 2>/dev/null | sed 's/^/     /' || true
ok "Compare that fingerprint with one you got some other way."

# Remembered, so that bier upgrade verifies every later release too.
mv "$signers" "$BARREL/allowed_signers"
printf '%s\n' "$TRUST_URL" >"$BARREL/allowed_signers.url"
mv "$staging" "$BARREL/bier"
trap - EXIT

exec /bin/sh "$BARREL/bier/install.sh" "$@"
