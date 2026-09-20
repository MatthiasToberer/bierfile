#!/usr/bin/env bash
# Brewfiles landen nie im Code-Repo
#
# Der Grund für die Trennung: die Brewfiles verraten, welche Software
# auf den Macs liegt. Das Code-Repo ist öffentlich. Ein Eintrag, der
# dort hineinrutscht, wäre nicht mehr zurückzuholen — die Historie
# behält ihn.

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
EOF

system mini <<'EOF'
brew "wget"
cask "etwas-privates"
EOF

bier mini sync "mini: Bestand"

# Die Änderung steht im Daten-Repo.
assert_file_has "$(bf mini mini)" 'cask "etwas-privates"'
data_commits=$(git -C "$WORK/mini" log --oneline | wc -l | tr -d ' ')
[ "$data_commits" -ge 2 ] || fail "das Daten-Repo hätte einen Commit bekommen müssen"

# Und nirgends sonst.
assert_eq "" "$(ls "$WORK/code-mini" | grep -x Brewfiles || true)" \
	"im Code-Verzeichnis darf kein Brewfiles-Ordner liegen"
assert_eq "" "$(git -C "$WORK/code-mini" status --porcelain)" \
	"das Code-Repo muss unberührt bleiben"
assert_eq "1" "$(git -C "$WORK/code-mini" log --oneline | wc -l | tr -d ' ')" \
	"das Code-Repo darf keinen zusätzlichen Commit bekommen haben"

# Auch nicht in der Historie des Code-Servers.
assert_eq "" "$(git -C "$WORK/code.git" log --all --name-only --format= |
	grep -x 'Brewfiles.*' || true)" \
	"kein Brewfile darf je im Code-Repo gewesen sein"

# Gegenprobe: das Daten-Repo kennt den Code nicht.
assert_eq "" "$(ls "$WORK/mini" | grep -x bin || true)" \
	"im Daten-Verzeichnis hat das Programm nichts zu suchen"
