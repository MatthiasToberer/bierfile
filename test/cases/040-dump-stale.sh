#!/usr/bin/env bash
# dump does not adopt what was removed elsewhere, --adopt does
#
# Without this, a dump on the second Mac cements the lost removal as a
# device-specific installation.

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
brew "ghidra"
EOF
system mini <<'EOF'
brew "wget"
brew "ghidra"
EOF
assert_ok bier mini dump

seed_file macbook Brewfiles/main <<'EOF'
brew "wget"
EOF

bier mini dump
out=$OUT
assert_contains "$out" "Not adopted, because removed elsewhere"
assert_file_lacks "$(bf mini mini)" 'brew "ghidra"'

bier mini dump --adopt
out=$OUT
assert_contains "$out" "Adopted although removed elsewhere"
assert_file_has "$(bf mini mini)" 'brew "ghidra"'
