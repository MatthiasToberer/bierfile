#!/usr/bin/env bash
# prune entfernt, was anderswo gelöscht wurde — Taps zuletzt
#
# brew verweigert das Untappen, solange ein Cask aus dem Tap da ist.
# Wird der Tap zuerst versucht, bleibt er stehen.

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
tap "sikarugir-app/sikarugir"
cask "sikarugir-app/sikarugir/sikarugir"
EOF
system mini <<'EOF'
brew "wget"
tap "sikarugir-app/sikarugir"
cask "sikarugir-app/sikarugir/sikarugir"
EOF
assert_ok bier mini dump

# Auf dem anderen Mac gelöscht.
seed_file macbook Brewfiles/main <<'EOF'
brew "wget"
EOF

answer j
bier mini prune
out=$OUT
assert_contains "$out" "Woanders gelöscht, hier noch installiert"

assert_file_lacks "$WORK/sys-mini" "sikarugir" "Cask muss weg sein"
assert_file_lacks "$WORK/sys-mini" "sikarugir-app/sikarugir" "Tap muss auch weg sein"
assert_not_contains "$out" "Nicht entfernt worden"
