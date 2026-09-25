#!/usr/bin/env bash
# dump records only what goes beyond main

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
assert_contains "$out" "1 not assigned, beside 2 for All Macs"
assert_file_has "$(bf mini mini)" 'brew "htop"'
assert_file_lacks "$(bf mini mini)" 'brew "wget"' "main entries do not belong in the device file"
