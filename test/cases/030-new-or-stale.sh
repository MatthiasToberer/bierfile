#!/usr/bin/env bash
# An addition and something removed elsewhere are told apart
#
# was_tracked first considered everything removed that had ever been in
# the repository — including a package currently running on the other Mac.

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
brew "ghidra"
EOF

system mini <<'EOF'
brew "wget"
brew "ghidra"
EOF
assert_ok bier mini dump

# ghidra gets removed on the other Mac.
seed_file macbook Brewfiles/main <<'EOF'
brew "wget"
EOF

bier mini state
out=$OUT
assert_contains "$out" "STALE"$'\t''brew "ghidra"' "removed means STALE"

# A package that was never in the repository is an addition.
system mini <<'EOF'
brew "wget"
brew "ghidra"
brew "htop"
EOF
bier mini state
out=$OUT
assert_contains "$out" "NEW"$'\t''brew "htop"' "never recorded means NEW"

# A package running on the other Mac is new here as well — not removed.
seed_file macbook Brewfiles/macbook <<'EOF'
cask "font-meslo"
EOF
system mini <<'EOF'
brew "wget"
brew "htop"
cask "font-meslo"
EOF
bier mini state
out=$OUT
assert_contains "$out" "NEW"$'\t''cask "font-meslo"' "picked up from the other Mac is NEW"
assert_not_contains "$out" "STALE"$'\t''cask "font-meslo"'
