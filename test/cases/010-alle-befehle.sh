#!/usr/bin/env bash
# Jeder Befehl endet sauber, auch bei leeren Dateien
#
# Deckt zwei Fehler ab, die genau hier zugeschlagen haben: "trap RETURN"
# feuerte ein zweites Mal mit verschwundener Variable, und "entries"
# lieferte bei einer Datei ohne Einträge Exit 1, was mit pipefail jede
# Zuweisung mitriss. Beide Male starb bier wortlos.

system mini <<'EOF'
brew "wget"
EOF
system macbook <<'EOF'
brew "wget"
EOF

assert_ok bier mini dump
assert_ok bier macbook dump
share

# Auch die Befehle, die den Server anfassen: beim Umbau auf zwei Repos
# ist cmd_push mit der Funktion daneben verschwunden, die Zeile in der
# Befehlstabelle blieb stehen. Niemand hat es gemerkt.
for c in help status state list diff config dump push sync; do
	assert_ok bier mini "$c"
done

# Und mit vollständig leerem main, dem ursprünglichen Absturzfall.
: >"$(bf mini main)"
assert_ok bier mini dump
assert_ok bier mini state
