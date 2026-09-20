#!/bin/sh
#
# Richtet bier und BierMenu auf diesem Mac ein. Das Programm-Repo muss
# schon geklont sein; um das Repo für die Brewfiles kümmert sich dieses
# Skript — es fragt nach der Adresse und klont es:
#
#   git clone git@github.com:MatthiasToberer/bierfile.git ~/bierfile
#   ~/bierfile/install.sh
#
#   ./install.sh --data git@dein-server:bierdaten.git   ohne Rückfrage
#   ./install.sh --uninstall   entfernt Verknüpfung und App wieder
#
# Mehrfach ausführen ist harmlos: es ersetzt, was da ist.

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
BIN_DIR=$HOME/.local/bin
LINK=$BIN_DIR/bier
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}/bier/config

say() { printf '\n== %s\n' "$*"; }
ok() { printf '   %s\n' "$*"; }
warn() { printf '   ! %s\n' "$*"; }
die() {
	printf '\ninstall: %s\n' "$*" >&2
	exit 1
}

# --yes beantwortet alle Rückfragen mit ja. "bier update" nutzt das:
# dort soll ein einziger Befehl genügen.
YES=no
DATA_ARG=""
prev=""
for arg in "$@"; do
	case $prev in
	--data) DATA_ARG=$arg ;;
	esac
	case $arg in
	--yes | -y) YES=yes ;;
	--data=*) DATA_ARG=${arg#--data=} ;;
	esac
	prev=$arg
done

# Fragt nur, wenn wirklich jemand am Terminal sitzt.
ask() {
	[ "$YES" = no ] || return 0
	[ -t 0 ] || return 1
	printf '   %s [j/N] ' "$1"
	read -r answer || return 1
	case $answer in
	j | J | y | Y) return 0 ;;
	*) return 1 ;;
	esac
}

# /Applications gehört root:admin und ist für Admins beschreibbar. Wer
# keine Adminrechte hat, bekommt die App ins eigene Verzeichnis.
app_target() {
	if [ -w /Applications ]; then
		echo /Applications/BierMenu.app
	else
		mkdir -p "$HOME/Applications"
		echo "$HOME/Applications/BierMenu.app"
	fi
}

# Beendet ein laufendes BierMenu und wartet, bis es wirklich weg ist.
# Ein festes "sleep 1" reicht nicht: hängt der alte Prozess noch, findet
# "open" ihn am Leben und aktiviert ihn bloß, statt die neue Fassung zu
# starten — dann läuft nach der Installation weiter der alte Code.
# Liefert 0, wenn etwas lief.
stop_app() {
	pgrep -f 'MacOS/BierMenu' >/dev/null 2>&1 || return 1

	pkill -f 'MacOS/BierMenu' 2>/dev/null || true
	local i=0
	while pgrep -f 'MacOS/BierMenu' >/dev/null 2>&1; do
		i=$((i + 1))
		if [ "$i" -gt 20 ]; then
			# Nach fünf Sekunden hart beenden.
			pkill -9 -f 'MacOS/BierMenu' 2>/dev/null || true
			sleep 1
			break
		fi
		sleep 0.25
	done
	return 0
}

# --- Entfernen ---------------------------------------------------------

if [ "${1:-}" = "--uninstall" ]; then
	say "BierMenu beenden und entfernen"
	stop_app || true
	for candidate in /Applications/BierMenu.app "$HOME/Applications/BierMenu.app"; do
		if [ -d "$candidate" ]; then
			rm -rf "$candidate"
			ok "entfernt: $candidate"
		fi
	done

	say "Verknüpfung entfernen"
	if [ -L "$LINK" ]; then
		rm -f "$LINK"
		ok "entfernt: $LINK"
	else
		ok "keine Verknüpfung unter $LINK"
	fi

	say "Config"
	if [ -f "$CONFIG" ] && ask "auch $CONFIG löschen?"; then
		rm -f "$CONFIG"
		ok "gelöscht"
	else
		ok "bleibt liegen: $CONFIG"
	fi

	printf '\nDas Repo unter %s bleibt unangetastet.\n\n' "$HERE"
	exit 0
fi

# --- Vorbedingungen ----------------------------------------------------

say "Vorbedingungen"
[ "$(uname)" = "Darwin" ] || die "läuft nur auf macOS"
[ -d "$HERE/.git" ] || die "$HERE ist kein Git-Repo — erst klonen"
command -v git >/dev/null 2>&1 || die "git fehlt"
command -v brew >/dev/null 2>&1 || die "Homebrew fehlt — siehe https://brew.sh"
command -v swiftc >/dev/null 2>&1 ||
	die "swiftc fehlt — 'xcode-select --install' und nochmal versuchen"
ok "macOS, git, Homebrew und swiftc sind da"

# --- bier in den PATH --------------------------------------------------

say "bier verfügbar machen"
mkdir -p "$BIN_DIR"
ln -sfn "$HERE/bin/bier" "$LINK"
ok "$LINK -> $HERE/bin/bier"
case ":$PATH:" in
*":$BIN_DIR:"*)
	ok "$BIN_DIR liegt im PATH"
	;;
*)
	warn "$BIN_DIR liegt nicht im PATH. Diese Zeile in ~/.zshrc ergänzen:"
	printf '\n       export PATH="%s:$PATH"\n' "$BIN_DIR"
	;;
esac

# Ein gleichnamiges Programm weiter vorn im PATH verdeckt die
# Verknüpfung lautlos — dann startet "bier" etwas anderes.
found=$(command -v bier 2>/dev/null || true)
if [ -n "$found" ] && [ "$found" != "$LINK" ]; then
	warn "'bier' startet $found, nicht $LINK"
	warn "Dieser Pfad liegt im PATH weiter vorn und verdeckt die Verknüpfung."
	if [ -L "$found" ]; then
		warn "Er zeigt auf $(readlink "$found")"
	fi
	warn "Entweder den Eintrag entfernen oder $HERE/bin/bier direkt aufrufen."
fi

# --- Git-Haken ---------------------------------------------------------

say "Tests vor dem Push"
git -C "$HERE" config core.hooksPath .githooks
ok "pre-push verlangt grüne Tests, bevor Code auf den Server geht"

# --- Konfiguration -----------------------------------------------------

config_get() {
	[ -f "$CONFIG" ] || return 0
	sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*(.*)\$/\1/p" "$CONFIG" |
		tail -1 | sed -E 's/[[:space:]]+\$//'
}

config_set() {
	mkdir -p "$(dirname "$CONFIG")"
	[ -f "$CONFIG" ] || printf '# Konfiguration für bier.\n' >"$CONFIG"
	if grep -qE "^[[:space:]]*$1[[:space:]]*=" "$CONFIG"; then
		sed -i '' "s|^[[:space:]]*$1[[:space:]]*=.*|$1 = $2|" "$CONFIG"
	else
		printf '%s = %s\n' "$1" "$2" >>"$CONFIG"
	fi
}

say "Konfiguration"
config_set root "$HERE"
config_set host "$(hostname -s)"
ok "$CONFIG zeigt auf $HERE"

# --- Dein eigenes Repo für die Brewfiles -------------------------------
#
# Der Bestand verrät, welche Software auf den Macs liegt. Er gehört
# deshalb nicht in das öffentliche Programm-Repo, sondern in ein
# eigenes, privates — auf das man auch Schreibrecht hat.

say "Repo für deine Brewfiles"

DATA=$(config_get data)

if [ -z "$DATA" ] && [ -d "$HERE/Brewfiles" ]; then
	warn "In $HERE liegen Brewfiles — eine alte Einrichtung."
	warn "Code und Daten gehören inzwischen getrennt. Bis zum Umzug"
	warn "wird weiter aus diesem Verzeichnis gearbeitet."
	DATA=$HERE
fi

if [ -n "$DATA_ARG" ]; then
	case $DATA_ARG in
	*://* | *@*:* )
		# Eine Adresse: klonen, falls noch nicht geschehen.
		target=$HOME/bierdaten
		if [ -d "$target/.git" ]; then
			ok "$target ist schon da"
		else
			git clone -q "$DATA_ARG" "$target"
			ok "geklont nach $target"
		fi
		DATA=$target
		;;
	*)
		DATA=$DATA_ARG
		;;
	esac
fi

if [ -z "$DATA" ] || [ ! -d "$DATA/.git" ]; then
	if [ "$YES" = yes ] || [ ! -t 0 ]; then
		die "Es fehlt das Repo für deine Brewfiles.
     Lege dir ein leeres, privates Git-Repo an und rufe auf:
       $0 --data git@dein-server:bierdaten.git"
	fi
	printf '
   Deine Brewfiles brauchen ein eigenes, privates Repo — sie verraten,
   welche Software auf deinen Macs liegt, und in das Programm-Repo
   kannst du ohnehin nicht schreiben.

   Wenn du noch keins hast, lege eins an: ein leeres Repository bei
   GitHub (auf "privat" stellen), auf einem Server oder einem NAS.

   Adresse (z.B. git@github.com:name/bierdaten.git), leer = abbrechen
   > '
	read -r answer || answer=""
	[ -n "$answer" ] || die "ohne Daten-Repo kann bier nichts tun"
	DATA=$HOME/bierdaten
	if [ -d "$DATA/.git" ]; then
		ok "$DATA ist schon da"
	else
		git clone -q "$answer" "$DATA" ||
			die "Klonen von $answer ist fehlgeschlagen"
		ok "geklont nach $DATA"
	fi
fi

config_set data "$DATA"
ok "Brewfiles liegen in $DATA"

# Frisch angelegte Repos sind leer. Die union-Regel gehört dorthin,
# damit gleichzeitige Änderungen auf zwei Macs sich selbst auflösen.
if [ ! -f "$DATA/.gitattributes" ]; then
	cp "$HERE/.gitattributes" "$DATA/.gitattributes"
	mkdir -p "$DATA/Brewfiles"
	[ -f "$DATA/Brewfiles/main" ] || : >"$DATA/Brewfiles/main"
	git -C "$DATA" add .gitattributes Brewfiles
	git -C "$DATA" commit -qm "bier: Grundgerüst" || true
	ok "Grundgerüst im Daten-Repo angelegt"
fi

# --- App bauen und installieren ----------------------------------------

say "BierMenu bauen"
"$HERE/app/build.sh" >/dev/null
ok "gebaut"

TARGET=$(app_target)
was_running=no
if stop_app; then
	was_running=yes
	ok "laufende Fassung beendet"
fi
rm -rf "$TARGET"
cp -R "$HERE/app/build/BierMenu.app" "$TARGET"
ok "installiert: $TARGET"
open "$TARGET"

# Nachsehen, ob wirklich die neue Fassung läuft — sonst hätte man nach
# der Installation stillschweigend weiter den alten Code vor sich.
i=0
while [ "$i" -lt 20 ]; do
	if pgrep -f "$TARGET/Contents/MacOS/BierMenu" >/dev/null 2>&1; then
		break
	fi
	i=$((i + 1))
	sleep 0.25
done
if pgrep -f "$TARGET/Contents/MacOS/BierMenu" >/dev/null 2>&1; then
	if [ "$was_running" = yes ]; then
		ok "neu gestartet — der Krug hängt wieder in der Menüleiste"
	else
		ok "gestartet — der Krug hängt jetzt in der Menüleiste"
	fi
else
	warn "BierMenu ist nicht angelaufen. Von Hand: open $TARGET"
fi

# --- Bestand erfassen --------------------------------------------------

say "Bestand dieses Macs erfassen"
"$HERE/bin/bier" dump

if ask "committen und zum Git-Server pushen?"; then
	"$HERE/bin/bier" sync "$(hostname -s): Bestand erfasst"
else
	ok "nicht gepusht — später mit 'bier sync'"
fi

# --- Schluss -----------------------------------------------------------

cat <<EOF

== Fertig

   Ein Klick auf den Krug zeigt, was abweicht. Damit er nach jedem
   Anmelden wieder da ist, im Menü einmal "Beim Anmelden starten"
   anhaken — das kann nur die App selbst setzen, nicht dieses Skript.

   bier status   zeigt, ob hier etwas nicht erfasst ist
   bier list     zeigt, was die anderen Geräte zusätzlich haben
   bier take     holt einzelne Einträge hierher oder nach main

EOF
