#!/usr/bin/env bash
# a locked keychain is reported as locked and can be unlocked on the spot
#
# Over SSH the login keychain is usually locked. bier read that as "no
# passphrase yet" and sent people to "bier vault --init" on a Mac that
# already knew the passphrase -- and --init then could not store it
# either, which is how an installation over SSH ended without one.

system mini <<'SYS'
brew "wget"
SYS

# A safe with something in it, sealed with a known passphrase.
BIER_VAULT_PASS=probe
export BIER_VAULT_PASS
printf 'inhalt\n' >"$WORK/home-mini/.probe"
assert_ok bier mini vault add "$WORK/home-mini/.probe"
assert_ok bier mini sync
unset BIER_VAULT_PASS

# Nothing stored: that really is a missing passphrase.
assert_ok bier mini vault
assert_contains "$OUT" "no passphrase yet"

# Locked, as over SSH, with nobody at a terminal.
BIER_TEST_KEYCHAIN=locked
export BIER_TEST_KEYCHAIN

# --init cannot store the passphrase and says how to get on.
answer probe
assert_fails bier mini vault --init
assert_contains "$OUT" "User interaction is not allowed"
assert_contains "$OUT" "security unlock-keychain"

# Stored earlier, but locked away now.
printf 'probe' >"$WORK/keychain"
assert_ok bier mini vault
assert_contains "$OUT" "the keychain is locked"
assert_not_contains "$OUT" "no passphrase yet"

# Sealing needs the passphrase, so this Mac stops and says how to go on.
assert_fails bier mini sync
assert_contains "$OUT" "would not hand it out"
assert_contains "$OUT" "security unlock-keychain"

# The other Mac only receives: it syncs and says why the safe stays closed.
assert_ok bier macbook sync
assert_contains "$OUT" "the keychain is locked"
assert_not_contains "$OUT" "no passphrase yet"

# At a terminal bier offers to unlock it. A wrong login password changes
# nothing.
BIER_TEST_TTY=1
export BIER_TEST_TTY
rm -f "$WORK/keychain"
answer probe
assert_fails bier mini vault --init
assert_contains "$OUT" "Unlock it with your macOS login password"
assert_contains "$OUT" "the keychain would not take the passphrase"
assert_file_has "$WORK/security.args" "login.keychain-db"

# The right one unlocks it, and the passphrase is stored.
BIER_TEST_UNLOCK=ok
export BIER_TEST_UNLOCK
answer probe
assert_ok bier mini vault --init
assert_contains "$OUT" "Remembered on this Mac."
assert_eq probe "$(cat "$WORK/keychain")" "the passphrase has to be in the keychain"

# And a locked keychain on the receiving Mac is unlocked during sync.
rm -f "$WORK/keychain-unlocked"
assert_ok bier macbook sync
assert_contains "$OUT" "Unlock it with your macOS login password"
assert_not_contains "$OUT" "they stay closed"
test -L "$WORK/home-macbook/.probe" || fail "the vault file has to arrive on the other Mac"
unset BIER_TEST_KEYCHAIN BIER_TEST_TTY BIER_TEST_UNLOCK
