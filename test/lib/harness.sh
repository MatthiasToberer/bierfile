#!/usr/bin/env bash
#
# Zusicherungen und die Testwelt.
#
# Jeder Fall bekommt eine frische Welt: einen Git-Server, zwei Macs und
# je einen Systemzustand, den der brew-Doppelgänger liest. Nichts davon
# berührt das echte System oder das echte Repo.

# --- Zusicherungen -----------------------------------------------------

FAILED=0

fail() {
	printf '    FEHLER: %s\n' "$1" >&2
	if [ $# -gt 1 ]; then
		printf '      erwartet: %s\n' "$2" >&2
		printf '      bekommen: %s\n' "${3-}" >&2
	fi
	FAILED=1
	return 1
}

assert_eq() {
	[ "$1" = "$2" ] || fail "${3:-Werte unterschiedlich}" "$1" "$2"
}

assert_contains() {
	case "$1" in
	*"$2"*) return 0 ;;
	esac
	fail "${3:-Text fehlt}" "enthält '$2'" "$1"
}

assert_not_contains() {
	case "$1" in
	*"$2"*) fail "${3:-Text sollte fehlen}" "ohne '$2'" "$1" ;;
	esac
	return 0
}

assert_file_has() {
	grep -qF "$2" "$1" || fail "${3:-Zeile fehlt in $1}" "$2" "$(cat "$1")"
}

assert_file_lacks() {
	if grep -qF "$2" "$1"; then
		fail "${3:-Zeile sollte weg sein aus $1}" "ohne $2" "$(cat "$1")"
	fi
}

# Führt aus und erwartet Erfolg. Bei Misserfolg wird die Ausgabe gezeigt.
assert_ok() {
	local rc=0
	"$@" || rc=$?
	[ "$rc" = 0 ] || fail "Befehl scheiterte (exit $rc): $*" "exit 0" "${OUT-}"
}

assert_fails() {
	local rc=0
	"$@" || rc=$?
	[ "$rc" != 0 ] || fail "Befehl hätte scheitern müssen: $*" "exit != 0" "${OUT-}"
}

# Eine Ausgabe, in der die Shell selbst klagt, ist immer ein Fehler —
# auch wenn der Exit-Code 0 ist. Genau so ist mir ein Fehler durch die
# Lappen gegangen: "tmp: unbound variable" wurde gemeldet, aber bier
# beendete sich trotzdem mit 0.
assert_sane() {
	local pat
	for pat in 'unbound variable' 'command not found' 'syntax error' \
		'No such file or directory' 'Bad substitution' 'integer expression'; do
		case "$1" in
		*"$pat"*) fail "die Shell klagt: $pat" "saubere Ausgabe" "$1" ;;
		esac
	done
}

# --- Testwelt ----------------------------------------------------------

# Legt zwei Server und zwei Macs an. $WORK ist vom Runner gesetzt.
#
# Code und Daten liegen getrennt, wie in echt:
#
#   $WORK/code.git      Code-Server (in echt: GitHub)
#   $WORK/data.git      Daten-Server (in echt: privat)
#   $WORK/code-<host>   Arbeitskopie des Programms
#   $WORK/<host>        Arbeitskopie der Brewfiles
#   $WORK/sys-<host>    was auf dem Mac "installiert" ist
world() {
	local host seed

	# --- Daten ---
	seed=$WORK/seed-data
	mkdir -p "$seed/Brewfiles"
	# Die union-Regel gehört zu den Brewfiles, also ins Daten-Repo.
	cp "$REPO/.gitattributes" "$seed/.gitattributes"
	: >"$seed/Brewfiles/main"
	git init -q --initial-branch=main "$seed"
	git -C "$seed" config user.email test@example.com
	git -C "$seed" config user.name Test
	git -C "$seed" add -A
	git -C "$seed" commit -qm "Anfang"
	git init -q --bare --initial-branch=main "$WORK/data.git"
	git -C "$seed" remote add origin "$WORK/data.git"
	git -C "$seed" push -q -u origin main

	# --- Code ---
	seed=$WORK/seed-code
	mkdir -p "$seed/bin"
	cp "$REPO/bin/bier" "$seed/bin/bier"
	git init -q --initial-branch=main "$seed"
	git -C "$seed" config user.email test@example.com
	git -C "$seed" config user.name Test
	git -C "$seed" add -A
	git -C "$seed" commit -qm "Programm"
	git init -q --bare --initial-branch=main "$WORK/code.git"
	git -C "$seed" remote add origin "$WORK/code.git"
	git -C "$seed" push -q -u origin main

	for host in mini macbook; do
		git clone -q "$WORK/data.git" "$WORK/$host"
		git clone -q "$WORK/code.git" "$WORK/code-$host"
		local d
		for d in "$WORK/$host" "$WORK/code-$host"; do
			git -C "$d" config user.email "$host@example.com"
			git -C "$d" config user.name "$host"
		done
		: >"$WORK/sys-$host"
		: >"$WORK/.in"
		mkdir -p "$WORK/config-$host/bier"
		printf 'root = %s\ndata = %s\nhost = %s\n' \
			"$WORK/code-$host" "$WORK/$host" "$host" \
			>"$WORK/config-$host/bier/config"
	done
}

# Bringt beide Macs über den Server auf denselben Stand.
share() {
	local h
	for h in mini macbook; do
		git -C "$WORK/$h" add -A
		git -C "$WORK/$h" diff --cached --quiet ||
			git -C "$WORK/$h" commit -qm "share $h"
		git -C "$WORK/$h" pull -q --rebase --autostash
		git -C "$WORK/$h" push -q
	done
	for h in mini macbook; do
		git -C "$WORK/$h" pull -q --rebase --autostash
	done
}

# Setzt den Systemzustand eines Macs. Zeilen kommen über stdin.
system() {
	cat >"$WORK/sys-$1"
}

# Schreibt eine Brewfile-Datei und committet sie auf dem Server.
seed_file() {
	local host=$1 path=$2
	cat >"$WORK/$host/$path"
	git -C "$WORK/$host" add -A
	git -C "$WORK/$host" commit -qm "seed $path"
	git -C "$WORK/$host" push -q
	local other
	for other in mini macbook; do
		[ "$other" = "$host" ] || git -C "$WORK/$other" pull -q --rebase
	done
}

# Legt die Antworten für die nächste Rückfrage fest.
answer() {
	if [ $# -eq 0 ]; then
		: >"$WORK/.in"
	else
		printf '%s\n' "$@" >"$WORK/.in"
	fi
}

# Führt bier auf einem der Macs aus.
#
# Die Ausgabe steht danach in $OUT, der Rückgabewert ist der von bier.
# Bewusst keine Subshell und keine Pipe: in einer Subshell gesetzte
# Fehlermarken gingen verloren, der Fall liefe grün durch.
bier() {
	local host=$1 rc=0
	shift
	# data kommt bewusst aus der Config, nicht aus der Umgebung: sonst
	# ließe sich der Fall "noch kein Daten-Repo" gar nicht nachstellen.
	BIER_ROOT=$WORK/code-$host \
		BIER_HOST=$host \
		BIER_TEST_SYSTEM=$WORK/sys-$host \
		XDG_CONFIG_HOME=$WORK/config-$host \
		"$WORK/code-$host/bin/bier" "$@" <"$WORK/.in" >"$WORK/.out" 2>&1 || rc=$?
	OUT=$(cat "$WORK/.out")
	assert_sane "$OUT"
	return $rc
}

# Pfad zu einer Brewfile-Datei eines Macs.
bf() {
	printf '%s' "$WORK/$1/Brewfiles/$2"
}
