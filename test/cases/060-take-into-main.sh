#!/usr/bin/env bash
# take into main: into main, out of every device file

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
EOF
seed_file macbook Brewfiles/macbook <<'EOF'
cask "font-meslo"
mas "WireGuard", id: 123
EOF

answer 1 m y n
bier mini take
out=$OUT
assert_contains "$out" 'cask "font-meslo"'
assert_contains "$out" "+ Brewfiles/main"
assert_contains "$out" "- Brewfiles/macbook"

assert_file_has "$(bf mini main)" 'cask "font-meslo"'
assert_file_lacks "$(bf mini macbook)" 'cask "font-meslo"' "listing it twice would be wrong"
assert_file_has "$(bf mini macbook)" 'mas "WireGuard", id: 123' "the rest stays, id included"
