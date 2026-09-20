#!/usr/bin/env bash
# update führt gleichzeitige Änderungen zusammen, ohne zu fragen

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
EOF

# Beide Macs hängen an dieselbe Datei etwas an.
printf 'brew "aus-macbook"\n' >>"$(bf macbook main)"
git -C "$WORK/macbook" add -A
git -C "$WORK/macbook" commit -qm "macbook"
git -C "$WORK/macbook" push -q

printf 'brew "aus-mini"\n' >>"$(bf mini main)"

system mini <<'EOF'
brew "wget"
EOF

answer
bier mini update
out=$OUT
assert_not_contains "$out" "CONFLICT"
assert_not_contains "$out" "fehlgeschlagen"

assert_file_has "$(bf mini main)" 'brew "aus-macbook"' "die fremde Änderung muss ankommen"
assert_file_has "$(bf mini main)" 'brew "aus-mini"' "die eigene darf nicht verlorengehen"
assert_file_lacks "$(bf mini main)" "<<<<<<<" "keine Konfliktmarker"
