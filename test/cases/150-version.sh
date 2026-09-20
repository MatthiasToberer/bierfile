#!/usr/bin/env bash
# version nennt sich, und state meldet sie für die Menüleiste

bier mini version
assert_contains "$OUT" "bier "
assert_contains "$OUT" "Code    $WORK/code-mini"
assert_contains "$OUT" "Daten   $WORK/mini"
assert_contains "$OUT" "Gerät   mini"

# Die App vergleicht ihre eigene Nummer mit dieser Zeile, um zu merken,
# dass sie veraltet ist.
system mini <<'EOF'
brew "wget"
EOF
bier mini state
version=$(printf '%s\n' "$OUT" | sed -n 's/^VERSION'$'\t''//p')
assert_eq "$(sed -nE 's/^BIER_VERSION=(.*)$/\1/p' "$REPO/bin/bier")" "$version" \
	"state muss dieselbe Version melden, die im Skript steht"

# app/build.sh holt dieselbe Nummer aus dem Skript ins App-Bündel.
# Das hier prüft die Quelle, nicht das Bau-Artefakt — ein alter Build
# im Arbeitsverzeichnis soll den Test nicht rot färben.
assert_contains "$(sed -n '/^VERSION=/p' "$REPO/app/build.sh")" "BIER_VERSION" \
	"build.sh muss die Nummer aus bin/bier lesen"
