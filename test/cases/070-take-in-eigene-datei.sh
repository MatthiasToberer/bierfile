#!/usr/bin/env bash
# take hierher: der andere Mac behält seinen Eintrag

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
EOF
seed_file macbook Brewfiles/macbook <<'EOF'
cask "font-meslo"
EOF

answer 1 h j n
bier mini take
out=$OUT
assert_contains "$out" "die anderen behalten ihren Eintrag"

assert_file_has "$(bf mini mini)" 'cask "font-meslo"'
assert_file_has "$(bf mini macbook)" 'cask "font-meslo"' "macbook darf ihn nicht verlieren"
assert_file_lacks "$(bf mini main)" 'cask "font-meslo"' "main bleibt unberührt"
