#!/usr/bin/env bash
# dump does not discard a recorded entry just because it is missing
#
# Otherwise everything picked with take but not yet installed is lost.

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
EOF
system mini <<'EOF'
brew "wget"
EOF
assert_ok bier mini dump

# Picked by hand, but not installed.
printf 'cask "font-meslo"\n' >>"$(bf mini mini)"

assert_ok bier mini dump
assert_file_has "$(bf mini mini)" 'cask "font-meslo"' "the pick has to survive the dump"

bier mini status
out=$OUT
assert_contains "$out" "Recorded but not installed on mini"
