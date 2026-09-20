#!/usr/bin/env bash
# install holt main und die eigene Gerätedatei aufs System
#
# Der Weg war lange ungetestet, weil er auf einem echten Mac Software
# installiert. Gegen den Doppelgänger ist das harmlos.

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
brew "git"
EOF
seed_file mini Brewfiles/mini <<'EOF'
cask "font-meslo"
EOF

# Auf dem Mac ist noch nichts davon da.
system mini <<'EOF'
EOF

bier mini install
out=$OUT

assert_file_has "$WORK/sys-mini" 'brew "wget"' "main muss installiert werden"
assert_file_has "$WORK/sys-mini" 'cask "font-meslo"' "die Gerätedatei auch"

# Danach deckt sich das System mit dem Erfassten.
bier mini status
assert_contains "$OUT" "deckt sich mit dem System"

bier mini state
assert_contains "$OUT" "STATE"$'\t'"ok"
