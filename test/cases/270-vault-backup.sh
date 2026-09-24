#!/usr/bin/env bash
# a file already at the destination is kept, not overwritten
#
# The second Mac always has a .zshrc of its own. Replacing it would
# throw it away, and letting it win would send a fresh Mac's default to
# every other Mac. The shared file wins, and the own one is kept next to
# it as .backup.

system mini <<'SYS'
brew "wget"
SYS
system macbook <<'SYS'
brew "wget"
SYS
export BIER_VAULT_PASS=probe
is_link() { [ -L "$1" ] && echo yes || echo no; }

printf 'von mini\n' >"$WORK/home-mini/.zshrc"
assert_ok bier mini vault add "$WORK/home-mini/.zshrc"
assert_ok bier mini sync

# The other Mac has one of its own, and it must survive.
printf 'von macbook\n' >"$WORK/home-macbook/.zshrc"
assert_ok bier macbook sync
assert_contains "$OUT" "kept: $WORK/home-macbook/.zshrc.backup" "the existing file has to be kept"
assert_eq "no" "$(is_link "$WORK/home-macbook/.zshrc")" "no link is put there"
assert_eq "von mini" "$(cat "$WORK/home-macbook/.zshrc")" "the shared file is in place"
assert_eq "von macbook" "$(cat "$WORK/home-macbook/.zshrc.backup")" \
	"while the old one waits in .backup"

# A second run must not make a second backup.
assert_ok bier macbook sync
assert_eq "no" "$([ -e "$WORK/home-macbook/.zshrc.backup.2" ] && echo yes || echo no)" \
	"a file already in place is left alone"
# And mini's file was not overwritten by macbook's own.
assert_ok bier mini sync
assert_eq "von mini" "$(cat "$WORK/home-mini/.zshrc")"

# An identical file needs no backup — there would be nothing to save.
printf 'gleich\n' >"$WORK/home-mini/.identisch"
assert_ok bier mini vault add "$WORK/home-mini/.identisch"
assert_ok bier mini sync
printf 'gleich\n' >"$WORK/home-macbook/.identisch"
assert_ok bier macbook sync
assert_eq "no" "$([ -e "$WORK/home-macbook/.identisch.backup" ] && echo yes || echo no)" \
	"so none is made"

# A link pointing somewhere else is not touched at all.
printf 'fremd\n' >"$WORK/home-macbook/fremdziel"
printf 'geteilt\n' >"$WORK/home-mini/.fremdlink"
assert_ok bier mini vault add "$WORK/home-mini/.fremdlink"
assert_ok bier mini sync
ln -sf "$WORK/home-macbook/fremdziel" "$WORK/home-macbook/.fremdlink"
assert_ok bier macbook sync
assert_contains "$OUT" "somewhere else" "a foreign link has to be reported"
assert_eq "fremd" "$(cat "$WORK/home-macbook/.fremdlink")" "and left as it was"

# The README install.sh leaves in the vault explains the folder. It is
# the same everywhere and must not travel, or it turns up as
# ~/README.txt on every Mac.
printf 'erklaerung\n' >"$WORK/home-mini/.bierfilevault/README.txt"
assert_ok bier mini sync
assert_eq "no" \
	"$([ -e "$WORK/mini/Safe/README.txt.gpg" ] && echo yes || echo no)" \
	"the README must not be sealed"
assert_ok bier macbook sync
assert_eq "no" "$([ -e "$WORK/home-macbook/README.txt" ] && echo yes || echo no)" \
	"and must not be linked into anyone's home"

# A vault holding nothing but bier's own README is empty as far as
# anybody cares, and must not demand a passphrase for it.
rm -rf "$WORK/home-macbook/.bierfilevault"
mkdir -p "$WORK/home-macbook/.bierfilevault"
printf 'erklaerung\n' >"$WORK/home-macbook/.bierfilevault/README.txt"
BIER_VAULT_PASS="" assert_ok bier macbook vault
assert_contains "$OUT" "0 entries" "a vault with only the README is empty"

# And the case that broke a real installation: syncing with nothing but
# the README in the vault demanded a passphrase for files that are not
# there. install.sh leaves that README behind, so every fresh Mac hit it.
rm -rf "$WORK/home-mini/.bierfilevault" "$WORK/mini/Safe"
mkdir -p "$WORK/home-mini/.bierfilevault"
printf 'erklaerung\n' >"$WORK/home-mini/.bierfilevault/README.txt"
BIER_VAULT_PASS="" assert_ok bier mini sync
assert_not_contains "$OUT" "no passphrase is set" \
	"a vault holding only the README must not ask for anything"
