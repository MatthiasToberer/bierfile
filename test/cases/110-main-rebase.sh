#!/usr/bin/env bash
# main rebases the device files and warns about losses

seed_file macbook Brewfiles/macbook <<'EOF'
brew "wget"
cask "font-meslo"
EOF
system mini <<'EOF'
brew "wget"
brew "git"
EOF

bier mini main --no-push
out=$OUT
assert_contains "$out" "inventory of mini, 2 entries"

# Whatever is in main drops out of the device files.
assert_file_lacks "$(bf mini macbook)" 'brew "wget"' "wget is in main now"
assert_file_has "$(bf mini macbook)" 'cask "font-meslo"' "the rest stays"

# A second run warns about what would drop out of main.
seed_file mini Brewfiles/main <<'EOF'
brew "wget"
brew "git"
cask "only-on-the-other-one"
EOF
answer n
bier mini main --no-push || true
out=$OUT
assert_contains "$out" "Will drop out of main for good"
assert_contains "$out" "only-on-the-other-one"
assert_file_has "$(bf mini main)" "only-on-the-other-one" "cancelling must change nothing"
