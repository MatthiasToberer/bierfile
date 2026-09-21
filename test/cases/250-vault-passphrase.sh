#!/usr/bin/env bash
# the passphrase is asked twice, and the prompt stays out of it
#
# Two things went wrong here. The prompt was printed to stdout while
# the answer was read through $(...), so the prompt ended up inside the
# passphrase -- consistent enough to look right, and wrong enough that
# "gpg -d" by hand could never have opened the file. And an empty vault
# has nothing to check a first passphrase against, so a typo would
# encrypt everything with something nobody could ever type again.

system mini <<'SYS'
brew "wget"
SYS

# BIER_VAULT_PASS keeps the real keychain out of this: --init still
# asks and still checks, it just does not store.
export BIER_VAULT_PASS=probe

# Two different answers are refused.
printf 'eins\nzwei\n' >"$WORK/.in"
assert_fails bier mini vault --init
assert_contains "$OUT" "do not match" "a mismatch has to be refused"

# The same answer twice is accepted.
printf 'gleich\ngleich\n' >"$WORK/.in"
assert_ok bier mini vault --init
assert_contains "$OUT" "Remembered" "matching answers have to be accepted"

# The real proof that the prompt stayed out of the value: seal a file,
# change the passphrase interactively, and then open the file by hand
# with gpg and exactly what was typed. That is what
# Safe/README-recovery.txt promises, so it has to be true.
printf 'inhalt\n' >"$WORK/home-mini/.probe"
assert_ok bier mini vault add "$WORK/home-mini/.probe"
assert_ok bier mini sync

printf 'neu\nneu\n' >"$WORK/.in"
assert_ok bier mini vault --passphrase
assert_contains "$OUT" "re-encrypted" "everything has to be re-encrypted"

out=$(printf 'neu' | GNUPGHOME=$GPGHOME gpg --batch --quiet --passphrase-fd 0 \
	--pinentry-mode loopback -d "$WORK/mini/Safe/dot_probe.gpg" 2>/dev/null)
assert_eq "inhalt" "$out" \
	"gpg by hand has to open it with exactly what was typed"
