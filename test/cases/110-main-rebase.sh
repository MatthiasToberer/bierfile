#!/usr/bin/env bash
# main bezieht Gerätedateien neu und warnt vor Verlust

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
assert_contains "$out" "Bestand von mini, 2 Einträge"

# Was in main steht, fliegt aus den Gerätedateien.
assert_file_lacks "$(bf mini macbook)" 'brew "wget"' "wget steht jetzt in main"
assert_file_has "$(bf mini macbook)" 'cask "font-meslo"' "der Rest bleibt"

# Ein zweiter Lauf warnt, was aus main herausfiele.
seed_file mini Brewfiles/main <<'EOF'
brew "wget"
brew "git"
cask "nur-auf-dem-anderen"
EOF
answer n
bier mini main --no-push || true
out=$OUT
assert_contains "$out" "Fällt dabei ersatzlos aus main heraus"
assert_contains "$out" "nur-auf-dem-anderen"
assert_file_has "$(bf mini main)" "nur-auf-dem-anderen" "Abbruch darf nichts ändern"
