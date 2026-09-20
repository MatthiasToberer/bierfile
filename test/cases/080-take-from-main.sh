#!/usr/bin/env bash
# take --from-main: aus main heraus einem Gerät zuschlagen

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
cask "mactex"
EOF

# Ohne Gerätedateien gibt es kein Ziel — beide Macs erfassen erst.
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

# Geräteliste ist alphabetisch: 1 = macbook, 2 = mini
answer 2 2 j n
bier mini take --from-main
out=$OUT
assert_contains "$out" "- Brewfiles/main"

assert_file_lacks "$(bf mini main)" 'cask "mactex"'
assert_file_has "$(bf mini mini)" 'cask "mactex"'
