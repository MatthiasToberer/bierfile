#!/usr/bin/env bash
# Neuzugang und anderswo Gelöschtes werden unterschieden
#
# was_tracked hielt anfangs alles für gelöscht, was jemals im Repo
# stand — auch ein Paket, das gerade auf dem anderen Mac läuft.

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
brew "ghidra"
EOF

system mini <<'EOF'
brew "wget"
brew "ghidra"
EOF
assert_ok bier mini dump

# ghidra wird auf dem anderen Mac gelöscht.
seed_file macbook Brewfiles/main <<'EOF'
brew "wget"
EOF

bier mini state
out=$OUT
assert_contains "$out" "STALE"$'\t''brew "ghidra"' "gelöscht heißt STALE"

# Ein Paket, das nie im Repo stand, ist ein Neuzugang.
system mini <<'EOF'
brew "wget"
brew "ghidra"
brew "htop"
EOF
bier mini state
out=$OUT
assert_contains "$out" "NEW"$'\t''brew "htop"' "nie erfasst heißt NEW"

# Ein Paket, das auf dem anderen Mac läuft, ist ebenfalls neu hier —
# nicht gelöscht.
seed_file macbook Brewfiles/macbook <<'EOF'
cask "font-meslo"
EOF
system mini <<'EOF'
brew "wget"
brew "htop"
cask "font-meslo"
EOF
bier mini state
out=$OUT
assert_contains "$out" "NEW"$'\t''cask "font-meslo"' "vom anderen Mac abgeschaut ist NEW"
assert_not_contains "$out" "STALE"$'\t''cask "font-meslo"'
