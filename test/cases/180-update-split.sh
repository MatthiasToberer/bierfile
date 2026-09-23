#!/usr/bin/env bash
# update was split: sync for the Macs, upgrade for the program
#
# One word did two jobs, and nobody could say which of them they had
# just asked for — bringing the Macs into line, or installing a newer
# bier. Both have their own word since 0.12.0, and the old one has to
# say so rather than silently doing one of the two.

system mini <<'SYS'
brew "wget"
SYS

# The old word is gone and names both successors.
assert_fails bier mini update
assert_contains "$OUT" "bier sync" "update has to name the command for the Macs"
assert_contains "$OUT" "bier upgrade" "and the one for the program"

# The overview offers both and no longer offers the old one.
bier mini help
assert_contains "$OUT" "bier sync" "help lists the command for the Macs"
assert_contains "$OUT" "bier upgrade" "and the one for the program"
assert_not_contains "$OUT" "bier update" "the old word may not be advertised"

# upgrade looks at the program only and leaves the inventory alone.
assert_ok bier mini dump
before=$(cat "$(bf mini mini)")
assert_ok bier mini upgrade
assert_contains "$OUT" "up to date" "nothing newer on the code server"
assert_eq "$before" "$(cat "$(bf mini mini)")" \
	"upgrade must not touch the Brewfiles"

assert_file_has "$WORK/code-mini/Sources/bier-core/bier" 'install.sh" --yes --no-inventory'
