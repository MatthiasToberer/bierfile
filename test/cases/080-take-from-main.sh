#!/usr/bin/env bash
# take --from-main: hand something out of main to one device

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
cask "mactex"
EOF

# Without device files there is no destination — both Macs record first.
system mini <<'EOF'
brew "wget"
cask "mactex"
EOF
system macbook <<'EOF'
brew "wget"
EOF
assert_ok bier mini dump
assert_ok bier macbook dump
share

# The device list is alphabetical: 1 = macbook, 2 = mini
answer 2 2 y n
bier mini take --from-main
out=$OUT
assert_contains "$out" "- Brewfiles/main"

assert_file_lacks "$(bf mini main)" 'cask "mactex"'
assert_file_has "$(bf mini mini)" 'cask "mactex"'
