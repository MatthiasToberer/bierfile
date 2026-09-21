#!/usr/bin/env bash
# a file already at the destination is kept, not overwritten
#
# The second Mac always has a .zshrc of its own. Linking over it would
# throw it away, and the old behaviour -- link only when nothing is
# there -- was worse: no link, no word, and the file sitting decrypted
# in the vault where nobody looks.

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
assert_contains "$OUT" "kept" "the existing file has to be kept"
assert_eq "yes" "$(is_link "$WORK/home-macbook/.zshrc")" "and the link put there"
assert_eq "von mini" "$(cat "$WORK/home-macbook/.zshrc")" "showing the shared file"
assert_eq "von macbook" "$(cat "$WORK/home-macbook/.zshrc.backup")" \
	"while the old one waits in .backup"

# A second run must not make a second backup out of its own link.
assert_ok bier macbook sync
assert_eq "no" "$([ -e "$WORK/home-macbook/.zshrc.backup.2" ] && echo yes || echo no)" \
	"an existing link is left alone"

# An identical file needs no backup — there would be nothing to save.
printf 'gleich\n' >"$WORK/home-mini/.identisch"
assert_ok bier mini vault add "$WORK/home-mini/.identisch"
assert_ok bier mini sync
printf 'gleich\n' >"$WORK/home-macbook/.identisch"
assert_ok bier macbook sync
assert_contains "$OUT" "was the same file" "an identical file needs no backup"
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
