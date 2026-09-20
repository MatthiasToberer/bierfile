#!/usr/bin/env bash
# uninstall entfernt Cask und Tap, auch über den kurzen Namen
#
# Homebrew kennt Casks kurz, das Brewfile schreibt sie voll
# qualifiziert. Und der kurze Name passt auf Tap wie Cask — daran ist
# kind_of einmal gescheitert und hat den Tap statt des Casks geraten.

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

bier mini uninstall sikarugir sikarugir-app/sikarugir
out=$OUT
assert_contains "$out" "sikarugir (cask)" "der kurze Name muss den Cask treffen, nicht den Tap"
assert_contains "$out" "sikarugir-app/sikarugir (tap)"

assert_file_lacks "$(bf mini main)" "sikarugir"
assert_file_lacks "$(bf mini main)" "sikarugir-app/sikarugir"
assert_file_has "$(bf mini main)" 'brew "wget"'

# Und im System ist beides weg.
assert_file_lacks "$WORK/sys-mini" "sikarugir"
