#!/usr/bin/env bash
# a vault change reaches every Mac, even when a peer pushed it in first
#
# A paired Mac puts its history straight into the other Mac's data
# repository. The next sync there sealed before it opened, took the old
# file in its vault for a change of its own, and wrote it back over the
# new one. The edit was gone on both Macs.

system mini <<'SYS'
brew "wget"
SYS
system macbook <<'SYS'
brew "wget"
SYS

BIER_VAULT_PASS=probe
export BIER_VAULT_PASS
printf 'eins\n' >"$WORK/home-mini/.fakezshrc"
assert_ok bier mini vault add "$WORK/home-mini/.fakezshrc"
assert_ok bier mini sync
assert_ok bier macbook sync
assert_eq eins "$(cat "$WORK/home-macbook/.fakezshrc")"

# mini changes the file, and a peer delivers the result directly into
# macbook's data repository, as the agent does.
printf 'zwei\n' >"$WORK/home-mini/.fakezshrc"
assert_ok bier mini sync
git -C "$WORK/macbook" pull -q --rebase

assert_ok bier macbook sync
assert_eq zwei "$(cat "$WORK/home-macbook/.fakezshrc")" "the change has to arrive"
assert_contains "$OUT" "updated: $WORK/home-macbook/.fakezshrc"
assert_ok bier mini sync
assert_eq zwei "$(cat "$WORK/home-mini/.fakezshrc")" "and must not be undone on the first Mac"

# Changed on both sides: nothing is overwritten, the other version is
# put next to the file, and the next sync keeps what is there then.
printf 'drei-mini\n' >"$WORK/home-mini/.fakezshrc"
assert_ok bier mini sync
git -C "$WORK/macbook" pull -q --rebase
printf 'drei-macbook\n' >"$WORK/home-macbook/.fakezshrc"
assert_ok bier macbook sync
assert_contains "$OUT" "changed here and on another Mac"
assert_eq drei-macbook "$(cat "$WORK/home-macbook/.fakezshrc")" "the own version must stay"
assert_eq drei-mini "$(cat "$WORK/home-macbook/.fakezshrc.from-safe")" "the other one must be kept next to it"
printf 'drei-beide\n' >"$WORK/home-macbook/.fakezshrc"
assert_ok bier macbook sync
assert_ok bier mini sync
assert_eq drei-beide "$(cat "$WORK/home-mini/.fakezshrc")" "the merged version has to travel"

# A Mac that has never recorded what it agreed on -- after moving from
# links, or with its state lost -- is not guessed at: the shared version
# wins, and its own is kept next to it.
rm -rf "$WORK/home-mini/.barrel/state"
printf 'vier\n' >"$WORK/home-mini/.fakezshrc"
assert_ok bier mini sync
assert_contains "$OUT" "kept: $WORK/home-mini/.fakezshrc.backup"
assert_eq drei-beide "$(cat "$WORK/home-mini/.fakezshrc")"
assert_eq vier "$(cat "$WORK/home-mini/.fakezshrc.backup")"
# From then on it knows, and a change travels as usual.
cp "$WORK/home-mini/.fakezshrc.backup" "$WORK/home-mini/.fakezshrc"
assert_ok bier mini sync
assert_ok bier macbook sync
assert_eq vier "$(cat "$WORK/home-macbook/.fakezshrc")" "after that, the own version travels"
