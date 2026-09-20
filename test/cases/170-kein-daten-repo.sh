#!/usr/bin/env bash
# Ohne eigenes Daten-Repo weist bier den Weg, statt ins Programm zu schreiben
#
# Wer das öffentliche Repo klont, hat noch kein Repo für seinen eigenen
# Bestand. Früher fiel bier dann auf das Programm-Verzeichnis zurück und
# hätte den Bestand dorthin geschrieben — also genau das veröffentlicht,
# was privat bleiben soll.

# Eine Einrichtung wie nach "git clone": Programm da, Daten nicht.
rm -f "$WORK/config-mini/bier/config"
printf 'root = %s\nhost = mini\n' "$WORK/code-mini" \
	>"$WORK/config-mini/bier/config"

system mini <<'EOF'
brew "wget"
EOF

for befehl in status dump list sync; do
	bier mini "$befehl" || true
	assert_contains "$OUT" "Noch kein eigenes Repo" \
		"$befehl muss auf das fehlende Daten-Repo hinweisen"
	assert_contains "$OUT" "install.sh" "und sagen, wie man es einrichtet"
done

# Und nichts davon darf im Programm-Verzeichnis gelandet sein.
assert_eq "" "$(ls "$WORK/code-mini" | grep -x Brewfiles || true)" \
	"es darf kein Brewfiles-Ordner im Programm-Repo entstehen"
assert_eq "" "$(git -C "$WORK/code-mini" status --porcelain)" \
	"das Programm-Repo muss unberührt bleiben"

# bier config benennt den Zustand ebenfalls.
bier mini config
assert_contains "$OUT" "noch nicht eingerichtet"
