#!/usr/bin/env bash
# retire: taking a Mac out, and taking bier off a Mac
#
# A Mac that broke or was wiped without uninstalling would otherwise
# stay in Brewfiles/ and in every group for ever. And removing bier from
# a Mac has to put the vault files back first -- an installation from
# before copy mode has links into the vault, and tidying up without that
# leaves a home full of dead links.

system mini <<'SYS'
brew "wget"
SYS
system macbook <<'SYS'
brew "wget"
SYS
export BIER_VAULT_PASS=probe

# Both have to have published, or the other one is not known here yet.
assert_ok bier macbook sync
assert_ok bier mini sync
assert_ok bier mini vault group alle mini macbook

# A name nobody knows.
assert_fails bier mini retire gibtsnicht
assert_contains "$OUT" "no Mac called" "an unknown Mac cannot be retired"

# Yourself, by name: refused, with the way that does work.
assert_fails bier mini retire mini
assert_contains "$OUT" "bier knockout" "it has to point at the right way"

# The other one, for real.
answer y
bier mini retire macbook
assert_contains "$OUT" "is out" "the Mac has to be taken out"
assert_eq "no" "$([ -f "$(bf mini macbook)" ] && echo yes || echo no)" \
	"its inventory has to be gone"
assert_ok bier mini vault group
assert_not_contains "$OUT" "macbook" "and its group membership with it"

# --unlink turns links from before copy mode into the files they
# pointed at, without touching what travels.
printf 'inhalt\n' >"$WORK/home-mini/.probe"
assert_ok bier mini vault add "$WORK/home-mini/.probe"
assert_ok bier mini sync
assert_eq "no" "$([ -L "$WORK/home-mini/.probe" ] && echo yes || echo no)" \
	"bier leaves a plain file where it was"
rm -f "$WORK/home-mini/.probe"
ln -s "$WORK/home-mini/.barrel/vault/dot_probe" "$WORK/home-mini/.probe"

assert_ok bier mini vault --unlink
assert_eq "no" "$([ -L "$WORK/home-mini/.probe" ] && echo yes || echo no)" \
	"unlink has to leave a plain file"
assert_eq "inhalt" "$(cat "$WORK/home-mini/.probe")" "with its content"
assert_eq "yes" "$([ -f "$WORK/mini/Safe/dot_probe.gpg" ] && echo yes || echo no)" \
	"and the encrypted copy has to stay — other Macs still want it"
