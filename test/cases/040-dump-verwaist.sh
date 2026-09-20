#!/usr/bin/env bash
# dump übernimmt Gelöschtes nicht, --adopt schon
#
# Ohne das zementiert ein Dump auf dem zweiten Mac die verlorene
# Löschung als gerätespezifische Installation.

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
assert_contains "$out" "Nicht übernommen, weil anderswo gelöscht"
assert_file_lacks "$(bf mini mini)" 'brew "ghidra"'

bier mini dump --adopt
out=$OUT
assert_contains "$out" "Übernommen, obwohl anderswo gelöscht"
assert_file_has "$(bf mini mini)" 'brew "ghidra"'
