#!/usr/bin/env bash
# settings bier may not read are reported, never taken for deleted
#
# macOS guards app containers: without Full Disk Access a program sees
# a file there but cannot read it, or cannot look into the folder at
# all. Taken for a change, that aborted the sync; taken for a deletion,
# it would have sent the settings to the Trash on every other Mac.

system mini <<'SYS'
brew "wget"
SYS
system macbook <<'SYS'
brew "wget"
SYS
export BIER_VAULT_PASS=probe

app="Library/Application Support/TestApp"
mkdir -p "$WORK/home-mini/$app"
printf 'window=1\n' >"$WORK/home-mini/$app/settings.ini"
assert_ok bier mini vault add --app TestApp "$WORK/home-mini/$app"
assert_ok bier mini sync
assert_ok bier macbook sync
assert_eq 'window=1' "$(cat "$WORK/home-macbook/$app/settings.ini")"

# Locked away on this Mac: reported, and nothing leaves the safe.
chmod 000 "$WORK/home-mini/$app"
bier mini status
assert_contains "$OUT" "$WORK/home-mini/$app/settings.ini no access -- see: bier access"
assert_not_contains "$OUT" "deleted here"
assert_ok bier mini sync
assert_ok bier macbook sync
assert_eq 'window=1' "$(cat "$WORK/home-macbook/$app/settings.ini")" "the other Mac must keep its settings"
[ ! -e "$WORK/trash-macbook/settings.ini" ] || fail "nothing may go to the Trash"
chmod 755 "$WORK/home-mini/$app"
bier mini status
assert_not_contains "$OUT" "no access"

# Locked away on the receiving Mac: nothing written, no abort, and it
# arrives once access is there.
printf 'window=2\n' >"$WORK/home-mini/$app/settings.ini"
assert_ok bier mini sync
chmod 000 "$WORK/home-macbook/$app"
assert_ok bier macbook sync
assert_contains "$OUT" "no access: $WORK/home-macbook/$app/settings.ini"
chmod 755 "$WORK/home-macbook/$app"
assert_ok bier macbook sync
assert_eq 'window=2' "$(cat "$WORK/home-macbook/$app/settings.ini")"

# bier access says what to do.
assert_ok bier mini access
assert_contains "$OUT" "Full Disk Access"
assert_contains "$OUT" "$WORK/home-mini/.barrel/BierMenu.app"
