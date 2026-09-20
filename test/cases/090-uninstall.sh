#!/usr/bin/env bash
# uninstall removes cask and tap, short name included
#
# Homebrew knows casks by their short name, the Brewfile writes them
# fully qualified. And the short name matches tap as well as cask — that
# is what kind_of tripped over once, guessing the tap instead of the cask.

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
tap "sikarugir-app/sikarugir"
cask "sikarugir-app/sikarugir/sikarugir"
EOF
system mini <<'EOF'
brew "wget"
tap "sikarugir-app/sikarugir"
cask "sikarugir-app/sikarugir/sikarugir"
EOF

bier mini uninstall sikarugir sikarugir-app/sikarugir
out=$OUT
assert_contains "$out" "sikarugir (cask)" "the short name has to hit the cask, not the tap"
assert_contains "$out" "sikarugir-app/sikarugir (tap)"

assert_file_lacks "$(bf mini main)" "sikarugir"
assert_file_lacks "$(bf mini main)" "sikarugir-app/sikarugir"
assert_file_has "$(bf mini main)" 'brew "wget"'

# And both are gone from the system.
assert_file_lacks "$WORK/sys-mini" "sikarugir"
