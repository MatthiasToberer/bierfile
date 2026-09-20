#!/usr/bin/env bash
# dump schreibt nur, was über main hinausgeht

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
brew "git"
EOF

system mini <<'EOF'
brew "wget"
brew "git"
brew "htop"
EOF

bier mini dump
out=$OUT
assert_contains "$out" "1 zusätzlich zu 2 in main"
assert_file_has "$(bf mini mini)" 'brew "htop"'
assert_file_lacks "$(bf mini mini)" 'brew "wget"' "main-Einträge gehören nicht ins Gerätefile"
