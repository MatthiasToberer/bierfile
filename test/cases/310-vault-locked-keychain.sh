#!/usr/bin/env bash
# a locked keychain is reported as locked, not as a missing passphrase
#
# Over SSH the login keychain is usually locked. bier read that as "no
# passphrase yet" and sent people to "bier vault --init" on a Mac that
# already knew the passphrase.

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

# Stored but locked away.
BIER_TEST_KEYCHAIN=locked
export BIER_TEST_KEYCHAIN
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

# --init does not invite a new passphrase over the lock.
answer probe
assert_fails bier mini vault --init
assert_contains "$OUT" "would not hand it out"
assert_contains "$OUT" "User interaction is not allowed"
assert_contains "$OUT" "security unlock-keychain"
unset BIER_TEST_KEYCHAIN
