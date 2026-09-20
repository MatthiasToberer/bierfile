#!/usr/bin/env bash
# take to here: the other Mac keeps its entry

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
EOF
seed_file macbook Brewfiles/macbook <<'EOF'
cask "font-meslo"
EOF

answer 1 h y n
bier mini take
out=$OUT
assert_contains "$out" "the others keep their entry"

assert_file_has "$(bf mini mini)" 'cask "font-meslo"'
assert_file_has "$(bf mini macbook)" 'cask "font-meslo"' "macbook must not lose it"
assert_file_lacks "$(bf mini main)" 'cask "font-meslo"' "main stays untouched"
