#!/usr/bin/env bash
# prune removes what was deleted elsewhere — taps last
#
# brew refuses to untap while a cask from the tap is still there. Try the
# tap first and it stays behind.

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
assert_ok bier mini dump

# Removed on the other Mac.
seed_file macbook Brewfiles/main <<'EOF'
brew "wget"
EOF

answer y
bier mini prune
out=$OUT
assert_contains "$out" "Removed elsewhere, still installed here"

assert_file_lacks "$WORK/sys-mini" "sikarugir" "the cask has to be gone"
assert_file_lacks "$WORK/sys-mini" "sikarugir-app/sikarugir" "the tap has to be gone too"
assert_not_contains "$out" "Not removed and still reported"
