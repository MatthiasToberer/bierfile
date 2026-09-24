#!/bin/sh
#
# Sets up bier and BierMenu on this Mac, everything inside ~/.barrel.
# bootstrap.sh fetches the program and runs this; by hand:
#
#   git clone https://github.com/MatthiasToberer/bierfile.git ~/.barrel/bier
#   ~/.barrel/bier/install.sh
#
# An installation from before the barrel is moved in on the way.
#
#   ./install.sh --data ~/my-bierdata  use another local folder
#   ./install.sh --data git@your-server:bierfile.git   optional legacy remote
#   ./install.sh --manual-inventory  keep Brewfiles explicitly curated
#   ./install.sh --dry-run     says what it would do, changes nothing
#   ./install.sh --uninstall   takes bier off this Mac (bier knockout)
#
# Running it more than once is harmless: it replaces what is there.

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
BARREL=${BIER_BARREL:-$HOME/.barrel}
BIN_DIR=$BARREL/bin
LINK=$BIN_DIR/bier
CONFIG=$BARREL/config

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
DRY=no
DATA_ARG=""
NO_INVENTORY=no
MANUAL_INVENTORY=no
prev=""
for arg in "$@"; do
	case $prev in
	--data) DATA_ARG=$arg ;;
	esac
	case $arg in
	--yes | -y) YES=yes ;;
	--uninstall) UNINSTALL=yes ;;
	--dry-run | -n) DRY=yes ;;
	--data=*) DATA_ARG=${arg#--data=} ;;
	--no-inventory) NO_INVENTORY=yes ;;
	--manual-inventory) MANUAL_INVENTORY=yes ;;
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

# The app lives in the barrel like everything else: out of sight, and
# gone with it.
app_target() {
	echo "$BARREL/BierMenu.app"
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

stop_agent() {
	local plist=$HOME/Library/LaunchAgents/com.bier.agent.plist
	[ -f "$plist" ] || return 1
	launchctl bootout "gui/$(id -u)" "$plist" >/dev/null 2>&1 || true
	return 0
}

# --- The program into the barrel --------------------------------------
#
# A checkout at ~/bierfile, where the old instructions put it, moves to
# ~/.barrel/bier and the installation carries on from there. One with
# changes of its own is somebody's working copy and stays.
if [ "$UNINSTALL" = no ] && [ "$DRY" = no ] && [ "$HERE" = "$HOME/bierfile" ] &&
	[ ! -e "$BARREL/bier" ] && [ -z "$(git -C "$HERE" status --porcelain 2>/dev/null || echo dirty)" ]; then
	mkdir -p "$BARREL"
	mv "$HERE" "$BARREL/bier"
	printf '\n== Moved the program: %s -> %s\n' "$HERE" "$BARREL/bier"
	exec /bin/sh "$BARREL/bier/install.sh" "$@"
fi

# --- Prerequisites -----------------------------------------------------

# Taking bier off is "bier knockout": it signs off at the other Macs
# first, which a script working only on this Mac could not.
if [ "$UNINSTALL" = yes ]; then
	if [ "$DRY" = yes ]; then
		exec "$HERE/Sources/bier-core/bier" knockout --dry-run
	fi
	exec "$HERE/Sources/bier-core/bier" knockout
fi

say "Prerequisites"
[ "$(uname)" = "Darwin" ] || die "runs on macOS only"
[ -d "$HERE/.git" ] || die "$HERE is not a git repository — clone it first"

# Check all required tools. Stopping at the first missing one turns a fresh
# Mac into a guessing game: fix one, run again, learn about the next.
MISSING=0
FIXES=""
GREEN="" RED="" RESET=""
if [ -t 1 ] && [ "${TERM:-dumb}" != dumb ] && [ -z "${NO_COLOR:-}" ]; then
	GREEN=$(printf '\033[1;32m')
	RED=$(printf '\033[1;31m')
	RESET=$(printf '\033[0m')
fi
check_ok() { printf '   %s[OK]%s      %s\n' "$GREEN" "$RESET" "$1"; }
check_missing() { printf '   %s[MISSING]%s %s\n' "$RED" "$RESET" "$1"; }
stop_if_missing() {
	[ "$MISSING" -gt 0 ] || return 0
	printf '\n%sINSTALLATION STOPPED — missing prerequisites: %s%s\n' "$RED" "$MISSING" "$RESET"
	[ -z "$FIXES" ] || printf '%s\n' "$FIXES"
	printf '\nFix these first, then run: %s\n' "$0"
	exit 1
}
need() {
	if command -v "$2" >/dev/null 2>&1; then
		check_ok "$1"
	else
		check_missing "$1"
		FIXES="${FIXES}
   $1: $3"
		MISSING=$((MISSING + 1))
	fi
}

need git    git    "comes with the Command Line Tools:  xcode-select --install"
need swiftc swiftc "comes with the Command Line Tools:  xcode-select --install"
need brew   brew   "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""

# Stop before prompts or setup can bury a missing tool.
stop_if_missing

# git refuses to commit without a name and an address, and bier commits
# on your behalf -- for the scaffolding, and at every sync. A fresh Mac
# has neither, and the message git gives instead arrives much later, in
# the middle of something else.
GIT_NAME=$(git config --get user.name 2>/dev/null || true)
GIT_MAIL=$(git config --get user.email 2>/dev/null || true)
if [ -n "$GIT_NAME" ] && [ -n "$GIT_MAIL" ]; then
	check_ok "identity   $GIT_NAME <$GIT_MAIL>"
elif [ "$DRY" = yes ] || [ "$YES" = yes ] || [ ! -t 0 ]; then
	check_missing "identity"
	printf '                git config --global user.name "Your Name"\n'
	printf '                git config --global user.email "you@example.com"\n'
	MISSING=$((MISSING + 1))
else
	printf '   %-10s git needs a name and an address to commit with\n' "identity"
	[ -n "$GIT_NAME" ] || {
		printf '                your name:  '
		read -r GIT_NAME || GIT_NAME=""
	}
	[ -n "$GIT_MAIL" ] || {
		printf '                your email: '
		read -r GIT_MAIL || GIT_MAIL=""
	}
	if [ -n "$GIT_NAME" ] && [ -n "$GIT_MAIL" ]; then
		git config --global user.name "$GIT_NAME"
		git config --global user.email "$GIT_MAIL"
		check_ok "identity   $GIT_NAME <$GIT_MAIL> (saved)"
	else
		check_missing "identity"
		printf '                nothing entered — set it yourself:\n'
		printf '                git config --global user.name "Your Name"\n'
		printf '                git config --global user.email "you@example.com"\n'
		MISSING=$((MISSING + 1))
	fi
fi

stop_if_missing

# gpg is not a prerequisite: without a vault nobody needs it, and with
# Homebrew there it installs itself in a second.
if command -v gpg >/dev/null 2>&1; then
	check_ok "gpg"
elif command -v brew >/dev/null 2>&1; then
	printf '   %-10s installing it now — the vault is encrypted with it\n' "gpg"
	brew install gnupg >/dev/null 2>&1 ||
		warn "could not install gnupg; 'bier vault' will say so again"
else
	printf '   %-10s comes along with Homebrew\n' "gpg"
fi

if [ "$DRY" = yes ]; then
	if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/bier/config" ] && [ ! -f "$CONFIG" ]; then
		say "What would move into $BARREL"
		"$HERE/Sources/bier-core/move-into-barrel" --dry-run
	fi
	say "What it would do"
	if [ -L "$LINK" ] && [ "$(readlink "$LINK")" = "$HERE/Sources/bier-core/bier" ]; then
		ok "link       $LINK — already correct"
	else
		ok "link       $LINK -> $HERE/Sources/bier-core/bier"
	fi
	case ":$PATH:" in
	*":$BIN_DIR:"*) ok "PATH       $BIN_DIR is on it" ;;
	*) ok "PATH       would offer to add $BIN_DIR to your shell profile" ;;
	esac
	if [ "$(git -C "$HERE" config core.hooksPath 2>/dev/null)" = ".githooks" ]; then
		ok "hook       pre-push — already set"
	else
		ok "hook       pre-push, so code only goes out with green tests"
	fi
	if [ -f "$CONFIG" ]; then
		ok "config     $CONFIG — exists, kept"
	else
		ok "config     $CONFIG — would be created"
	fi
	d=$(sed -nE 's/^[[:space:]]*data[[:space:]]*=[[:space:]]*(.*)$/\1/p' "$CONFIG" 2>/dev/null | tail -1)
	if [ -n "$d" ] && [ -d "$d/.git" ]; then
		ok "data       $d — a git repository, kept"
	else
		ok "data       would create the local repository $BARREL/data"
	fi
	if "$HERE/Sources/bier-core/bier" vault 2>/dev/null | grep -q 'remembered on this Mac'; then
		ok "vault      create the folder; the passphrase is already known"
	else
		ok "vault      create the folder and ask for a passphrase"
	fi
	v=$(sed -n 's/^BIER_VERSION=//p' "$HERE/Sources/bier-core/bier" | head -1)
	if [ -d "$(app_target)" ]; then
		ok "app        build $v and replace $(app_target)"
	else
		ok "app        build $v and install it"
	fi
	inventory=$(sed -nE 's/^[[:space:]]*inventory[[:space:]]*=[[:space:]]*(.*)$/\1/p' "$CONFIG" 2>/dev/null | tail -1)
	[ "$MANUAL_INVENTORY" = no ] || inventory=manual
	if [ "$inventory" = manual ]; then
		ok "inventory  manual — keep Brewfiles exactly as written"
	else
		ok "inventory  automatic — record this Mac with bier dump"
	fi
	ok "agent      build and run locally on TCP port 53991"
	cat <<EOF

   Nothing has been changed. Leave out --dry-run to do it.

EOF
	exit 0
fi

# --- native peer client -----------------------------------------------

say "Building the Swift peer client"
"$HERE/Sources/bier-peer/build.sh" >/dev/null
ok "built"

# --- bier onto the PATH ------------------------------------------------

say "Making bier available"
mkdir -p "$BIN_DIR"
ln -sfn "$HERE/Sources/bier-core/bier" "$LINK"
ok "$LINK -> $HERE/Sources/bier-core/bier"
case ":$PATH:" in
*":$BIN_DIR:"*)
	ok "$BIN_DIR is on the PATH"
	;;
*)
	# Warning about it was not enough. On a fresh Mac ~/.local/bin is
	# never on the PATH, the warning drowns in the rest of the output,
	# and what the user meets afterwards is "zsh: command not found".
	PROFILE=$HOME/.zshrc
	case ${SHELL##*/} in
	bash) PROFILE=$HOME/.bash_profile ;;
	esac
	if [ "$DRY" = yes ]; then
		ok "would add $BIN_DIR to the PATH in $PROFILE"
	elif ask "$BIN_DIR is not on the PATH. Add it to $PROFILE?"; then
		if [ -f "$PROFILE" ] && grep -qF "$BIN_DIR" "$PROFILE"; then
			ok "$PROFILE mentions it already"
		else
			printf '\n# added by bier\nexport PATH="%s:$PATH"\n' \
				"$BIN_DIR" >>"$PROFILE"
			ok "added to $PROFILE"
		fi
		PATH=$BIN_DIR:$PATH
		export PATH
		warn "this shell does not know it yet — open a new terminal,"
		warn "or type:  exec $(basename "${SHELL:-zsh}")"
	else
		warn "then bier only works by its full path: $LINK"
		printf '\n       export PATH="%s:$PATH"\n' "$BIN_DIR"
	fi
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
	warn "Either remove that entry or call $HERE/Sources/bier-core/bier directly."
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

# Commits what bier keeps in the data repository, and nothing else.
# Returns 1 when there was nothing to commit.
commit_data() {
	local path
	for path in .gitattributes Brewfiles Safe; do
		[ ! -e "$DATA/$path" ] || git -C "$DATA" add -A -- "$path"
	done
	git -C "$DATA" diff --cached --quiet && return 1
	git -C "$DATA" commit -qm "$1"
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

if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/bier/config" ] && [ ! -f "$CONFIG" ]; then
	say "Moving into $BARREL"
	stop_app && ok "stopped BierMenu" || true
	stop_agent && ok "stopped the Bier agent" || true
	"$HERE/Sources/bier-core/move-into-barrel"
fi

say "Configuration"
config_set root "$HERE"
config_set host "$(hostname -s)"
[ "$MANUAL_INVENTORY" = no ] || config_set inventory manual
ok "$CONFIG points at $HERE"

# --- Your local repository for the Brewfiles ---------------------------
#
# The inventory reveals which software is on the Macs. It therefore does
# not belong in the public program repository. Each Mac keeps a local Git
# repository and exchanges its history directly with paired peers.

say "Local repository for your Brewfiles"

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
		target=$BARREL/data
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

if [ -z "$DATA" ]; then
	DATA=$BARREL/data
	git init -q --initial-branch=main "$DATA" || die "could not create $DATA"
	ok "created $DATA"
elif [ ! -d "$DATA/.git" ]; then
	mkdir -p "$DATA"
	git init -q --initial-branch=main "$DATA" || die "could not initialise $DATA"
	ok "initialised $DATA"
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

VAULTDIR=$(sed -nE 's/^[[:space:]]*vault[[:space:]]*=[[:space:]]*(.*)$/\1/p' \
	"$CONFIG" 2>/dev/null | tail -1)
case ${VAULTDIR:-} in
"") VAULTDIR=$BARREL/vault ;;
"~/"*) VAULTDIR=$HOME/${VAULTDIR#\~/} ;;
esac

# The folder is made even when nobody uses it yet. A hint pointing at
# something that does not exist is not a hint, and an empty folder in
# your home is a question you can ask.
mkdir -p "$VAULTDIR"
if [ ! -f "$VAULTDIR/README.txt" ]; then
	cat >"$VAULTDIR/README.txt" <<NOTE
This is the vault of "bier": plain copies of the files you share
between your Macs. Only encrypted copies ever leave this Mac.

Do not put files here by hand, and do not edit them here. Use:

    bier vault add ~/.zshrc
    bier vault add ~/Library/Application\ Support/SomeApp

Your files stay where they are; this folder only keeps a copy. A folder
is tracked as a whole: files put in it later come along, and files
deleted from it go to the Trash on the other Macs.

    bier vault              what is in it
    bier vault forget PATH  stop syncing it; the file stays everywhere
    bier vault drop PATH    remove it everywhere, into the Trash

The encrypted copies live in Safe/ in your data repository, next to a
note explaining how to open them with gpg alone, without bier.
NOTE
fi
ok "$VAULTDIR"

# The passphrase is asked here and nowhere else. Asking later, on the
# day somebody first puts a file in, means the setup was never actually
# finished -- and it is the day they are thinking about something else.
if "$HERE/Sources/bier-core/bier" vault 2>/dev/null | grep -q 'remembered on this Mac'; then
	ok "the passphrase is already known here"
elif [ "$YES" = yes ] || [ ! -t 0 ]; then
	# --yes cannot invent a passphrase, and guessing is not an option.
	warn "no passphrase yet — run 'bier vault --init' to set one"
else
	"$HERE/Sources/bier-core/bier" vault --init ||
		warn "not set; run 'bier vault --init' when you are ready"
fi

# --- Local peer agent -------------------------------------------------

say "Installing the local Bier agent"
AGENT_HOME=$BARREL/agent
AGENT_BIN=$AGENT_HOME/bin/bier-agent
AGENT_PLIST=$HOME/Library/LaunchAgents/com.bier.agent.plist
PEER_SIGNERS=$AGENT_HOME/peer_signers
RELEASE_SIGNERS=$BARREL/allowed_signers
mkdir -p "$AGENT_HOME/bin" "$AGENT_HOME/state" "$HOME/Library/LaunchAgents" "$(dirname "$RELEASE_SIGNERS")"
touch "$PEER_SIGNERS" "$RELEASE_SIGNERS"
chmod 700 "$AGENT_HOME" "$AGENT_HOME/bin" "$AGENT_HOME/state"
chmod 600 "$PEER_SIGNERS" "$RELEASE_SIGNERS"
if [ ! -r "$AGENT_HOME/identity" ] || [ ! -r "$AGENT_HOME/identity.pub" ]; then
	rm -f "$AGENT_HOME/identity" "$AGENT_HOME/identity.pub"
	ssh-keygen -q -t ed25519 -N '' -C "bier@$(hostname -s)" -f "$AGENT_HOME/identity"
	ok "created a private peer identity for this Mac"
fi
chmod 600 "$AGENT_HOME/identity" "$AGENT_HOME/identity.pub"
"$HERE/Sources/bier-agent/build.sh" "$AGENT_BIN.new" >/dev/null
mv "$AGENT_BIN.new" "$AGENT_BIN"
chmod 700 "$AGENT_BIN"

xml_data=$(printf '%s' "$DATA" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
xml_barrel=$(printf '%s' "$BARREL" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
xml_host=$(hostname -s | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
cat >"$AGENT_PLIST.new" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.bier.agent</string>
  <key>ProgramArguments</key><array>
    <!-- Starts the agent while the barrel is there. After "rm -rf ~/.barrel"
         it removes this file and unloads itself instead of failing on
         every restart. The dollars are escaped: this heredoc is expanded
         when the file is written, and they are meant for launch time. -->
    <string>/bin/sh</string>
    <string>-c</string>
    <string>if [ -x "\$1" ]; then exec "\$@"; fi; rm -f "\$HOME/Library/LaunchAgents/com.bier.agent.plist"; exec launchctl bootout "gui/\$(id -u)/com.bier.agent"</string>
    <string>bier-agent</string>
    <string>$xml_barrel/agent/bin/bier-agent</string>
    <string>serve</string>
    <string>--agent</string><string>$xml_host</string>
    <string>--peer-signers</string><string>$xml_barrel/agent/peer_signers</string>
    <string>--peer-key</string><string>$xml_barrel/agent/identity.pub</string>
    <string>--peers-file</string><string>$xml_barrel/peers</string>
    <string>--data-dir</string><string>$xml_data</string>
    <string>--port</string><string>53991</string>
    <string>--state-dir</string><string>$xml_barrel/agent/state</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
EOF
plutil -lint "$AGENT_PLIST.new" >/dev/null || die "could not create the Bier agent configuration"
stop_agent || true
mv "$AGENT_PLIST.new" "$AGENT_PLIST"
launchctl bootstrap "gui/$(id -u)" "$AGENT_PLIST" || die "could not start the local Bier agent"
ok "running for $(hostname -s) on TCP port 53991"

# --- Build and install the app -----------------------------------------

say "Building BierMenu"
"$HERE/Sources/bier-trayapp/build.sh" >/dev/null
ok "built"

TARGET=$(app_target)
was_running=no
if stop_app; then
	was_running=yes
	ok "stopped the running build"
fi
rm -rf "$TARGET"
cp -R "$HERE/Sources/bier-trayapp/build/BierMenu.app" "$TARGET"
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

if [ "$NO_INVENTORY" = yes ]; then
	say "Recording this Mac's inventory"
	ok "unchanged — bier upgrade updates only the program"
else
	say "Recording this Mac's inventory"
	if [ "$(config_get inventory)" = manual ]; then
		ok "manual — Brewfiles were left exactly as written"
	else
		"$HERE/Sources/bier-core/bier" dump

		# Committed in any case. Left lying around, the new list made the
		# data repository "dirty", and paired Macs could not sync with
		# this one until somebody committed by hand. Nothing leaves this
		# Mac by committing; that is what the question below is about.
		commit_data "$(hostname -s): inventory recorded" &&
			ok "saved in the local Bier history"
		if ask "synchronise with your other Macs now?"; then
			"$HERE/Sources/bier-core/bier" sync
		else
			ok "not synchronised — later with 'bier sync'"
		fi
	fi
fi

# --- Check the data repository -----------------------------------------
#
# Paired Macs exchange committed history only, and a Mac with
# uncommitted changes refuses to take theirs. Whatever the answers above
# were, the installation must not end in that state.

say "Checking the data repository"
if [ -z "$(git -C "$DATA" status --porcelain --untracked-files=all)" ]; then
	ok "clean — paired Macs can sync with this one"
else
	warn "$DATA has uncommitted changes:"
	git -C "$DATA" status --short --untracked-files=all | sed 's/^/       /'
	if ask "commit them now?"; then
		commit_data "$(hostname -s): changes recorded during installation" || true
	fi
	if [ -z "$(git -C "$DATA" status --porcelain --untracked-files=all)" ]; then
		ok "clean — paired Macs can sync with this one"
	else
		printf '\n%sPAIRED MACS CANNOT SYNC WITH THIS ONE YET%s\n' "$RED" "$RESET"
		warn "commit the changes above first:  bier sync"
	fi
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
