#!/usr/bin/env bash
# install brings main and the own device file onto the system
#
# This path went untested for a long time because on a real Mac it
# installs software. Against the stand-in it is harmless.

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
brew "git"
EOF
seed_file mini Brewfiles/mini <<'EOF'
cask "font-meslo"
EOF

# None of it is on the Mac yet.
system mini <<'EOF'
EOF

bier mini install
out=$OUT

assert_file_has "$WORK/sys-mini" 'brew "wget"' "main has to be installed"
assert_file_has "$WORK/sys-mini" 'cask "font-meslo"' "the device file too"

# Afterwards the system matches what is recorded.
bier mini status
assert_contains "$OUT" "matches the system"

bier mini state
assert_contains "$OUT" "STATE"$'\t'"ok"
