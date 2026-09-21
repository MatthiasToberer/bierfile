#!/bin/sh
#
# Sets up bier and BierMenu on this Mac. The program repository has to be
# cloned already; this script takes care of the repository for the
# Brewfiles — it asks for the address and clones it:
#
#   git clone git@github.com:MatthiasToberer/bierfile.git ~/bierfile
#   ~/bierfile/install.sh
#
#   ./install.sh --data git@your-server:bierdata.git   without asking
#   ./install.sh --uninstall   removes the symlink and the app again
#
# Running it more than once is harmless: it replaces what is there.

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

# --yes answers every question with yes. "bier upgrade" relies on that:
# there a single command has to be enough.
YES=no
UNINSTALL=no
DATA_ARG=""
prev=""
for arg in "$@"; do
	case $prev in
	--data) DATA_ARG=$arg ;;
	esac
	case $arg in
	--yes | -y) YES=yes ;;
	--uninstall) UNINSTALL=yes ;;
	--data=*) DATA_ARG=${arg#--data=} ;;
	esac
	prev=$arg
done

# Only asks if somebody is actually sitting at the terminal.
ask() {
	[ "$YES" = no ] || return 0
	[ -t 0 ] || return 1
	printf '   %s [y/N] ' "$1"
	read -r answer || return 1
	case $answer in
	j | J | y | Y) return 0 ;;
	*) return 1 ;;
	esac
}

# /Applications belongs to root:admin and is writable for admins. Anyone
# without admin rights gets the app in their own directory.
app_target() {
	if [ -w /Applications ]; then
		echo /Applications/BierMenu.app
	else
		mkdir -p "$HOME/Applications"
		echo "$HOME/Applications/BierMenu.app"
	fi
}

# Stops a running BierMenu and waits until it is really gone. A fixed
# "sleep 1" is not enough: if the old process is still hanging around,
# "open" finds it alive and merely activates it instead of starting the
# new build — and the old code keeps running after the install.
# Returns 0 if something was running.
stop_app() {
	pgrep -f 'MacOS/BierMenu' >/dev/null 2>&1 || return 1

	pkill -f 'MacOS/BierMenu' 2>/dev/null || true
	local i=0
	while pgrep -f 'MacOS/BierMenu' >/dev/null 2>&1; do
		i=$((i + 1))
		if [ "$i" -gt 20 ]; then
			# Kill it hard after five seconds.
			pkill -9 -f 'MacOS/BierMenu' 2>/dev/null || true
			sleep 1
			break
		fi
		sleep 0.25
	done
	return 0
}

# --- Removal -----------------------------------------------------------

if [ "${1:-}" = "--uninstall" ]; then
	say "Stopping and removing BierMenu"
	stop_app || true
	for candidate in /Applications/BierMenu.app "$HOME/Applications/BierMenu.app"; do
		if [ -d "$candidate" ]; then
			rm -rf "$candidate"
			ok "removed: $candidate"
		fi
	done

	say "Removing the symlink"
	if [ -L "$LINK" ]; then
		rm -f "$LINK"
		ok "removed: $LINK"
	else
		ok "no symlink at $LINK"
	fi

	say "Config"
	if [ -f "$CONFIG" ] && ask "delete $CONFIG as well?"; then
		rm -f "$CONFIG"
		ok "deleted"
	else
		ok "left in place: $CONFIG"
	fi

	printf '\nThe repository at %s is left untouched.\n\n' "$HERE"
	exit 0
fi

# --- Prerequisites -----------------------------------------------------

if [ "$UNINSTALL" = yes ]; then
	say "Taking bier off this Mac"

	# The files first. Every link points into the vault, and removing
	# bier without this would leave a home full of dead links and no
	# .zshrc at all.
	if [ -x "$HERE/bin/bier" ]; then
		"$HERE/bin/bier" vault --unlink 2>/dev/null ||
			warn "could not put the vault files back — check by hand"
		if [ -t 0 ]; then
			"$HERE/bin/bier" retire --self ||
				warn "this Mac is still listed; take it out elsewhere with 'bier retire'"
		else
			warn "not on a terminal — take this Mac out elsewhere with 'bier retire'"
		fi
	fi

	TARGET=$(app_target)
	stop_app && ok "stopped BierMenu"
	if [ -d "$TARGET" ]; then
		rm -rf "$TARGET"
		ok "removed: $TARGET"
	fi
	if [ -L "$LINK" ]; then
		rm -f "$LINK"
		ok "removed: $LINK"
	fi
	security delete-generic-password -s bier-vault -a vault >/dev/null 2>&1 &&
		ok "the vault passphrase is out of the keychain" || true

	cat <<EOF

   bier is off this Mac. Nothing of yours was deleted:

     the Brewfiles and the safe are still in the data repository
     the vault files are still where they were, now as plain files
     $HOME/.config/bier/config is still there

   Remove those by hand if you want them gone.

EOF
	exit 0
fi

say "Prerequisites"
[ "$(uname)" = "Darwin" ] || die "runs on macOS only"
[ -d "$HERE/.git" ] || die "$HERE is not a git repository — clone it first"
command -v git >/dev/null 2>&1 || die "git is missing"
command -v brew >/dev/null 2>&1 || die "Homebrew is missing — see https://brew.sh"
if ! command -v gpg >/dev/null 2>&1; then
	ok "gpg is missing — installing gnupg, the vault is encrypted with it"
	brew install gnupg >/dev/null 2>&1 ||
		warn "could not install gnupg; 'bier vault' will say so again"
fi
command -v swiftc >/dev/null 2>&1 ||
	die "swiftc is missing — run 'xcode-select --install' and try again"
ok "macOS, git, Homebrew and swiftc are present"

# --- bier onto the PATH ------------------------------------------------

say "Making bier available"
mkdir -p "$BIN_DIR"
ln -sfn "$HERE/bin/bier" "$LINK"
ok "$LINK -> $HERE/bin/bier"
case ":$PATH:" in
*":$BIN_DIR:"*)
	ok "$BIN_DIR is on the PATH"
	;;
*)
	warn "$BIN_DIR is not on the PATH. Add this line to ~/.zshrc:"
	printf '\n       export PATH="%s:$PATH"\n' "$BIN_DIR"
	;;
esac

# A program of the same name earlier on the PATH shadows the symlink
# silently — then "bier" starts something else.
found=$(command -v bier 2>/dev/null || true)
if [ -n "$found" ] && [ "$found" != "$LINK" ]; then
	warn "'bier' starts $found, not $LINK"
	warn "That path comes earlier on the PATH and shadows the symlink."
	if [ -L "$found" ]; then
		warn "It points at $(readlink "$found")"
	fi
	warn "Either remove that entry or call $HERE/bin/bier directly."
fi

# --- Git hook ----------------------------------------------------------

say "Tests before pushing"
git -C "$HERE" config core.hooksPath .githooks
ok "pre-push requires green tests before code goes to the server"

# --- Configuration -----------------------------------------------------

config_get() {
	[ -f "$CONFIG" ] || return 0
	sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*(.*)\$/\1/p" "$CONFIG" |
		tail -1 | sed -E 's/[[:space:]]+\$//'
}

config_set() {
	mkdir -p "$(dirname "$CONFIG")"
	[ -f "$CONFIG" ] || printf '# Configuration for bier.\n' >"$CONFIG"
	if grep -qE "^[[:space:]]*$1[[:space:]]*=" "$CONFIG"; then
		sed -i '' "s|^[[:space:]]*$1[[:space:]]*=.*|$1 = $2|" "$CONFIG"
	else
		printf '%s = %s\n' "$1" "$2" >>"$CONFIG"
	fi
}

say "Configuration"
config_set root "$HERE"
config_set host "$(hostname -s)"
ok "$CONFIG points at $HERE"

# --- Your own repository for the Brewfiles -----------------------------
#
# The inventory reveals which software is on the Macs. It therefore does
# not belong in the public program repository but in one of your own, a
# private one — which you also have write access to.

say "Repository for your Brewfiles"

DATA=$(config_get data)

if [ -z "$DATA" ] && [ -d "$HERE/Brewfiles" ]; then
	warn "There are Brewfiles in $HERE — an older setup."
	warn "Code and data belong apart these days. Until you move them,"
	warn "work continues out of this directory."
	DATA=$HERE
fi

if [ -n "$DATA_ARG" ]; then
	case $DATA_ARG in
	*://* | *@*:* )
		# An address: clone it unless that has already happened.
		target=$HOME/bierdata
		if [ -d "$target/.git" ]; then
			ok "$target is already there"
		else
			git clone -q "$DATA_ARG" "$target"
			ok "cloned to $target"
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
		die "The repository for your Brewfiles is missing.
     Create an empty, private git repository and run:
       $0 --data git@your-server:bierdata.git"
	fi
	printf '
   Your Brewfiles need a private repository of their own — they reveal
   which software is on your Macs, and you cannot write to the program
   repository anyway.

   If you do not have one yet, create it: an empty repository on GitHub
   (set it to private), on a server, or on a NAS.

   Address (e.g. git@github.com:yourname/bierdata.git), empty = cancel
   > '
	read -r answer || answer=""
	[ -n "$answer" ] || die "without a data repository bier can do nothing"
	DATA=$HOME/bierdata
	if [ -d "$DATA/.git" ]; then
		ok "$DATA is already there"
	else
		git clone -q "$answer" "$DATA" ||
			die "cloning $answer failed"
		ok "cloned to $DATA"
	fi
fi

config_set data "$DATA"
ok "Brewfiles live in $DATA"

# Freshly created repositories are empty. The union rule belongs in
# there, so that simultaneous changes on two Macs resolve themselves.
if [ ! -f "$DATA/.gitattributes" ]; then
	cp "$HERE/.gitattributes" "$DATA/.gitattributes"
	mkdir -p "$DATA/Brewfiles"
	[ -f "$DATA/Brewfiles/main" ] || : >"$DATA/Brewfiles/main"
	git -C "$DATA" add .gitattributes Brewfiles
	git -C "$DATA" commit -qm "bier: scaffolding" || true
	ok "scaffolding created in the data repository"
fi

# --- The vault ---------------------------------------------------------

say "Vault"
if [ -z "$(find "$DATA/Safe" -name '*.gpg' -type f -print -quit 2>/dev/null)" ]; then
	ok "nothing in it yet — 'bier vault add ~/.zshrc' puts something there"
elif "$HERE/bin/bier" vault 2>/dev/null | grep -q 'remembered on this Mac'; then
	ok "the passphrase is already known here"
elif [ "$YES" = yes ] || [ ! -t 0 ]; then
	# --yes cannot invent a passphrase, and guessing is not an option.
	warn "the vault holds files — run 'bier vault --init' to unlock them"
else
	"$HERE/bin/bier" vault --init ||
		warn "not unlocked; run 'bier vault --init' when you have the passphrase"
fi

# --- Build and install the app -----------------------------------------

say "Building BierMenu"
"$HERE/app/build.sh" >/dev/null
ok "built"

TARGET=$(app_target)
was_running=no
if stop_app; then
	was_running=yes
	ok "stopped the running build"
fi
rm -rf "$TARGET"
cp -R "$HERE/app/build/BierMenu.app" "$TARGET"
ok "installed: $TARGET"
open "$TARGET"

# Check that the new build really is running — otherwise you would
# silently still be looking at the old code after installing.
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
		ok "restarted — the mug is back in the menu bar"
	else
		ok "started — the mug is in the menu bar now"
	fi
else
	warn "BierMenu did not come up. By hand: open $TARGET"
fi

# --- Record the inventory ----------------------------------------------

say "Recording this Mac's inventory"
"$HERE/bin/bier" dump

if ask "commit and push to the git server?"; then
	"$HERE/bin/bier" sync "$(hostname -s): inventory recorded"
else
	ok "not pushed — later with 'bier sync'"
fi

# --- Done --------------------------------------------------------------

cat <<EOF

== Done

   A click on the mug shows what differs. So that it comes back after
   every login, tick "Start at login" in the menu once — only the app
   itself can set that, not this script.

   bier status   shows whether anything here is unrecorded
   bier list     shows what the other devices have on top
   bier take     pulls single entries here or into main

EOF
