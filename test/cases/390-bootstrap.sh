#!/usr/bin/env bash
# bootstrap installs the latest signed release into ~/.barrel
#
# One line, like Homebrew: fetch the newest release tag, check its
# signature against the key published elsewhere, and hand over to its
# install.sh. An unsigned or foreign tag installs nothing.

keys=$WORK/release-keys
mkdir -p "$keys"
ssh-keygen -q -t ed25519 -N '' -f "$keys/release"
ssh-keygen -q -t ed25519 -N '' -f "$keys/stranger"
printf 'bier-releases %s\n' "$(cat "$keys/release.pub")" >"$keys/allowed_signers"

release=$WORK/release-src
mkdir -p "$release"
git init -q --initial-branch=main "$release"
git -C "$release" config user.email test@example.com
git -C "$release" config user.name Test
cat >"$release/install.sh" <<'EOF'
#!/bin/sh
printf 'install.sh %s from %s\n' "$*" "$(cd "$(dirname "$0")" && pwd)" >>"$HOME/installed"
EOF
git -C "$release" add install.sh
git -C "$release" commit -qm 'release'
sign() {
	git -C "$release" -c gpg.format=ssh -c user.signingkey="$keys/$1" tag -s "$2" -m "bier $2"
}
sign release v1.0.0
printf '# newer\n' >>"$release/install.sh"
git -C "$release" commit -qam 'newer release'
sign release v1.2.0
git clone -q --bare "$release" "$WORK/release.git"

strap() {
	local home=$1 rc=0
	shift
	mkdir -p "$home"
	HOME=$home BIER_REPO_URL=$WORK/release.git BIER_TEST_SKIP_CLT=1 \
		BIER_RELEASE_TRUST_URL=file://$keys/allowed_signers \
		/bin/bash "$REPO/bootstrap.sh" "$@" >"$WORK/.out" 2>&1 || rc=$?
	OUT=$(cat "$WORK/.out")
	assert_sane "$OUT"
	return $rc
}

home=$WORK/home-new
assert_ok strap "$home" --manual-inventory
assert_contains "$OUT" "v1.2.0"
assert_contains "$OUT" "is signed with the release key"
assert_eq v1.2.0 "$(git -C "$home/.barrel/bier" describe --tags)" "the newest release has to be fetched"
assert_file_has "$home/installed" "install.sh --manual-inventory from $home/.barrel/bier"
assert_file_has "$home/.barrel/allowed_signers" "bier-releases"
assert_file_has "$home/.barrel/allowed_signers.url" "file://$keys/allowed_signers"

# Run again, it only runs the installed installer.
assert_ok strap "$home"
assert_contains "$OUT" "already installed"
assert_eq 2 "$(wc -l <"$home/installed" | tr -d ' ')"

# A newer tag signed by somebody else installs nothing.
sign stranger v2.0.0
git -C "$release" push -q "$WORK/release.git" v2.0.0
home=$WORK/home-stranger
assert_fails strap "$home"
assert_contains "$OUT" "not signed with the published release key. Nothing was installed."
[ ! -e "$home/.barrel/bier" ] || fail "nothing may be installed"
[ ! -e "$home/.barrel/bier.new" ] || fail "and nothing left half-fetched"
[ ! -e "$home/installed" ] || fail "and no installer run"

# Nor does an unsigned one.
git -C "$release" push -q "$WORK/release.git" :refs/tags/v2.0.0
git -C "$release" tag -a v2.1.0 -m 'unsigned'
git -C "$release" push -q "$WORK/release.git" v2.1.0
assert_fails strap "$home"
assert_contains "$OUT" "Nothing was installed."
