#!/usr/bin/env bash
# dump wirft Erfasstes nicht weg, nur weil es fehlt
#
# Sonst verliert man alles, was man sich mit take vorgenommen, aber
# noch nicht installiert hat.

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
EOF
system mini <<'EOF'
brew "wget"
EOF
assert_ok bier mini dump

# Von Hand vorgemerkt, aber nicht installiert.
printf 'cask "font-meslo"\n' >>"$(bf mini mini)"

assert_ok bier mini dump
assert_file_has "$(bf mini mini)" 'cask "font-meslo"' "Vormerkung muss den Dump überleben"

bier mini status
out=$OUT
assert_contains "$out" "Erfasst, aber auf mini nicht installiert"
