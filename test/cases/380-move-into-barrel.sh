#!/usr/bin/env bash
# an installation from before the barrel moves into ~/.barrel once
#
# Config, peers and trust lived in ~/.config/bier, the agent in
# ~/.local/share, the state in ~/.local/state, the data in ~/bierdata and
# the vault in ~/.bierfilevault, with links from the home folder into it.
# Everything moves into ~/.barrel, the links become plain files, and bier
# finds it all there afterwards.

old=$WORK/home-old
mkdir -p "$old/.config/bier" "$old/.local/share/bier/agent" "$old/.local/state/bier" \
	"$old/.local/bin" "$old/.bierfilevault"
git clone -q "$WORK/data.git" "$old/bierdata"
cat >"$old/.config/bier/config" <<EOF
root = $REPO
data = ~/bierdata
host = old
vault = $old/.bierfilevault
EOF
printf 'studio.local\n' >"$old/.config/bier/peers"
printf 'key\n' >"$old/.config/bier/allowed_signers"
printf 'identity\n' >"$old/.local/share/bier/agent/identity"
printf 'base\n' >"$old/.local/state/bier/vault-base"
printf 'export EDITOR=vim\n' >"$old/.bierfilevault/dot_zshrc"
ln -s "$old/.bierfilevault/dot_zshrc" "$old/.zshrc"
ln -s "$REPO/Sources/bier-core/bier" "$old/.local/bin/bier"

move() {
	HOME=$old BIER_TEST_SYSTEM=$WORK/sys-mini "$REPO/Sources/bier-core/move-into-barrel" "$@" \
		>"$WORK/.out" 2>&1 || return $?
	OUT=$(cat "$WORK/.out")
	assert_sane "$OUT"
}

# A dry run says what would move and moves nothing.
move --dry-run
assert_contains "$OUT" "$old/bierdata -> $old/.barrel/data"
assert_contains "$OUT" "$old/.bierfilevault -> $old/.barrel/vault"
[ ! -e "$old/.barrel" ] || fail "a dry run must not create the barrel"
[ -L "$old/.zshrc" ] || fail "a dry run must not touch the links"

move
for moved in config peers allowed_signers agent/identity state/vault-base data/.git vault/dot_zshrc; do
	[ -e "$old/.barrel/$moved" ] || fail "$moved has to be in the barrel"
done
for gone in .config/bier .local/share/bier/agent .local/state/bier bierdata .bierfilevault .local/bin/bier; do
	[ ! -e "$old/$gone" ] || fail "$gone has to be gone"
done
assert_eq "no" "$([ -L "$old/.zshrc" ] && echo yes || echo no)" "the link has to be a plain file"
assert_eq "export EDITOR=vim" "$(cat "$old/.zshrc")" "with its content"
assert_file_has "$old/.barrel/config" "data = $old/.barrel/data"
assert_file_has "$old/.barrel/config" "vault = $old/.barrel/vault"

# bier finds everything in its new place.
out=$(HOME=$old BIER_TEST_SYSTEM=$WORK/sys-mini "$REPO/Sources/bier-core/bier" vault 2>&1)
assert_contains "$out" "Vault:  $old/.barrel/vault"
assert_contains "$out" "Safe:   $old/.barrel/data/Safe"
out=$(HOME=$old BIER_TEST_SYSTEM=$WORK/sys-mini "$REPO/Sources/bier-core/bier" peer list 2>&1)
assert_contains "$out" "studio.local"

# Once is enough: a second run finds the barrel and does nothing.
move
assert_eq "" "$OUT" "a second run has nothing to do"

# A data folder of its own stays where it is.
other=$WORK/home-other
mkdir -p "$other/.config/bier"
git clone -q "$WORK/data.git" "$other/mydata"
printf 'root = %s\ndata = %s\nhost = other\n' "$REPO" "$other/mydata" >"$other/.config/bier/config"
HOME=$other "$REPO/Sources/bier-core/move-into-barrel" >/dev/null 2>&1
[ -d "$other/mydata/.git" ] || fail "a data folder set up elsewhere has to stay"
assert_file_has "$other/.barrel/config" "data = $other/mydata"
