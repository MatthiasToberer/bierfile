#!/usr/bin/env bash
# take nach main: rein in main, raus aus allen Gerätedateien

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
EOF
seed_file macbook Brewfiles/macbook <<'EOF'
cask "font-meslo"
mas "WireGuard", id: 123
EOF

answer 1 m j n
bier mini take
out=$OUT
assert_contains "$out" 'cask "font-meslo"'
assert_contains "$out" "+ Brewfiles/main"
assert_contains "$out" "- Brewfiles/macbook"

assert_file_has "$(bf mini main)" 'cask "font-meslo"'
assert_file_lacks "$(bf mini macbook)" 'cask "font-meslo"' "doppelt wäre falsch"
assert_file_has "$(bf mini macbook)" 'mas "WireGuard", id: 123' "der Rest bleibt, samt id"
