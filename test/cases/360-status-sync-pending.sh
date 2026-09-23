#!/usr/bin/env bash
# status says what the next sync carries, vault included
#
# A vault file changed here, or delivered by a peer and not opened yet,
# showed up nowhere until the next sync. Neither did commits that had
# not reached a peer. Brewfiles and vault files are reported alike now.

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

# Taken in, not sealed yet.
bier mini status
assert_contains "$OUT" "Sync (bier sync):"
assert_contains "$OUT" "$WORK/home-mini/.fakezshrc changed here"
assert_ok bier mini sync
assert_ok bier macbook sync
bier mini status
assert_not_contains "$OUT" "Sync (bier sync):" "after a sync nothing is pending"
bier mini state
assert_contains "$OUT" "STATE"$'\t'"ok"

# Changed here: pending, and the glass is empty.
printf 'zwei\n' >"$WORK/home-mini/.fakezshrc"
bier mini status
assert_contains "$OUT" "$WORK/home-mini/.fakezshrc changed here"
bier mini state
assert_contains "$OUT" "VAULT_OUT"$'\t'"$WORK/home-mini/.fakezshrc"
assert_contains "$OUT" "STATE"$'\t'"drift"
assert_ok bier mini sync

# Delivered to the other Mac, as a peer does: newer in the safe.
git -C "$WORK/macbook" pull -q --rebase
bier macbook status
assert_contains "$OUT" "$WORK/home-macbook/.fakezshrc newer in the safe"
bier macbook state
assert_contains "$OUT" "VAULT_IN"$'\t'"$WORK/home-macbook/.fakezshrc"
assert_ok bier macbook vault open
assert_eq zwei "$(cat "$WORK/home-macbook/.fakezshrc")"
bier macbook state
assert_not_contains "$OUT" "VAULT_"

# Changed on both sides, and the copy a conflict leaves behind.
printf 'drei\n' >"$WORK/home-mini/.fakezshrc"
assert_ok bier mini sync
git -C "$WORK/macbook" pull -q --rebase
printf 'vier\n' >"$WORK/home-macbook/.fakezshrc"
bier macbook state
assert_contains "$OUT" "VAULT_BOTH"$'\t'"$WORK/home-macbook/.fakezshrc"
assert_ok bier macbook sync
bier macbook status
assert_contains "$OUT" "$WORK/home-macbook/.fakezshrc.from-safe left from a conflict"
rm -f "$WORK/home-macbook/.fakezshrc.from-safe"
assert_ok bier macbook sync
assert_ok bier mini sync

# A Brewfile changed and not committed.
printf 'brew "tree"\n' >>"$(bf mini main)"
bier mini status
assert_contains "$OUT" "Brewfiles/main changed, not committed"
git -C "$WORK/mini" checkout -q -- Brewfiles/main

# Commits a paired Mac has not had yet.
cat >"$WORK/peer-client" <<'EOF'
#!/bin/sh
printf '%s\n' 'Bier data is in sync.'
EOF
chmod +x "$WORK/peer-client"
mkdir -p "$WORK/home-mini/.local/share/bier/agent"
ssh-keygen -q -t ed25519 -N '' -f "$WORK/home-mini/.local/share/bier/agent/identity"
BIER_PEER_CLIENT=$WORK/peer-client
export BIER_PEER_CLIENT
assert_ok bier mini peer add macbook.local
bier mini status
assert_contains "$OUT" "to macbook.local"
assert_contains "$OUT" "never synced"
assert_ok bier mini sync
bier mini status
assert_not_contains "$OUT" "to macbook.local"
printf 'brew "tree"\n' >>"$(bf mini main)"
git -C "$WORK/mini" commit -qam 'mini: tree for everyone'
bier mini status
assert_contains "$OUT" "1 commit(s) from here not sent yet"
bier mini state
assert_contains "$OUT" "SEND"$'\t'"macbook.local"$'\t'"1"
unset BIER_PEER_CLIENT
