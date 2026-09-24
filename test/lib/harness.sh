#!/usr/bin/env bash
#
# Assertions and the test world.
#
# Every case gets a fresh world: git servers, two Macs and one system
# state per Mac that the brew stand-in reads. None of it touches the real
# system or the real repository.

# --- Assertions --------------------------------------------------------

FAILED=0

fail() {
	printf '    FAILED: %s\n' "$1" >&2
	if [ $# -gt 1 ]; then
		printf '      expected: %s\n' "$2" >&2
		printf '      got:      %s\n' "${3-}" >&2
	fi
	FAILED=1
	return 1
}

assert_eq() {
	[ "$1" = "$2" ] || fail "${3:-values differ}" "$1" "$2"
}

assert_contains() {
	case "$1" in
	*"$2"*) return 0 ;;
	esac
	fail "${3:-text missing}" "contains '$2'" "$1"
}

assert_not_contains() {
	case "$1" in
	*"$2"*) fail "${3:-text should be absent}" "without '$2'" "$1" ;;
	esac
	return 0
}

assert_file_has() {
	grep -qF -- "$2" "$1" || fail "${3:-line missing in $1}" "$2" "$(cat "$1")"
}

assert_file_lacks() {
	if grep -qF -- "$2" "$1"; then
		fail "${3:-line should be gone from $1}" "without $2" "$(cat "$1")"
	fi
}

# Runs a command and expects success. On failure the output is shown.
assert_ok() {
	local rc=0
	"$@" || rc=$?
	[ "$rc" = 0 ] || fail "command failed (exit $rc): $*" "exit 0" "${OUT-}"
}

assert_fails() {
	local rc=0
	"$@" || rc=$?
	[ "$rc" != 0 ] || fail "command should have failed: $*" "exit != 0" "${OUT-}"
}

# Output in which the shell itself complains is always a failure — even
# when the exit code is 0. That is exactly how one slipped past me:
# "tmp: unbound variable" was printed, yet bier still exited with 0.
assert_sane() {
	local pat
	for pat in 'unbound variable' 'command not found' 'syntax error' \
		'No such file or directory' 'Bad substitution' 'integer expression'; do
		case "$1" in
		*"$pat"*) fail "the shell complains: $pat" "clean output" "$1" ;;
		esac
	done
}

# --- Test world --------------------------------------------------------

# Creates two servers and two Macs. $WORK is set by the runner.
#
# Code and data live apart, as they do in reality:
#
#   $WORK/code.git      code server (in reality: GitHub)
#   $WORK/data.git      data server (in reality: private)
#   $WORK/code-<host>   working copy of the program
#   $WORK/<host>        working copy of the Brewfiles
#   $WORK/sys-<host>    what is "installed" on that Mac
world() {
	local host seed

	# --- Data ---
	seed=$WORK/seed-data
	mkdir -p "$seed/Brewfiles"
	# The union rule belongs with the Brewfiles, so: the data repository.
	cp "$REPO/.gitattributes" "$seed/.gitattributes"
	: >"$seed/Brewfiles/main"
	git init -q --initial-branch=main "$seed"
	git -C "$seed" config user.email test@example.com
	git -C "$seed" config user.name Test
	git -C "$seed" add -A
	git -C "$seed" commit -qm "start"
	git init -q --bare --initial-branch=main "$WORK/data.git"
	git -C "$seed" remote add origin "$WORK/data.git"
	git -C "$seed" push -q -u origin main

	# See the note in bier(): this has to be a short path.
	GPGHOME=$(mktemp -d /tmp/biergpg.XXXXXX)
	chmod 700 "$GPGHOME"

	# --- Code ---
	seed=$WORK/seed-code
	mkdir -p "$seed/Sources/bier-core"
	cp "$REPO/Sources/bier-core/bier" "$seed/Sources/bier-core/bier"
	git init -q --initial-branch=main "$seed"
	git -C "$seed" config user.email test@example.com
	git -C "$seed" config user.name Test
	git -C "$seed" add -A
	git -C "$seed" commit -qm "program"
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
		mkdir -p "$WORK/home-$host"
		: >"$WORK/sys-$host"
		: >"$WORK/.in"
		mkdir -p "$WORK/config-$host/bier"
		printf 'root = %s\ndata = %s\nhost = %s\n' \
			"$WORK/code-$host" "$WORK/$host" "$host" \
			>"$WORK/config-$host/bier/config"
	done
}

# Brings both Macs to the same state through the server.
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

# Sets the system state of a Mac. Lines come in on stdin.
system() {
	cat >"$WORK/sys-$1"
}

# Writes a Brewfile and commits it to the server.
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

# Sets the answers for the next prompts.
answer() {
	if [ $# -eq 0 ]; then
		: >"$WORK/.in"
	else
		printf '%s\n' "$@" >"$WORK/.in"
	fi
}

# Runs bier on one of the Macs.
#
# The output ends up in $OUT, the return value is the one from bier.
# Deliberately no subshell and no pipe: failure marks set inside a
# subshell would be lost and the case would pass green.
bier() {
	local host=$1 rc=0
	shift
	# data deliberately comes from the config, not from the environment:
	# otherwise the "no data repository yet" case could not be staged at
	# all.
	# A home of its own, or "vault add" would reach into the real one.
	# GNUPGHOME has to be short: gpg builds its agent socket from it,
	# and $WORK is deep enough that the path stops fitting.
	BIER_ROOT=$WORK/code-$host \
		BIER_HOST=$host \
		HOME=$WORK/home-$host \
		GNUPGHOME=$GPGHOME \
		BIER_VAULT=$WORK/home-$host/.bierfilevault \
		BIER_TEST_SYSTEM=$WORK/sys-$host \
		BIER_TRASH_DIR=$WORK/trash-$host \
		BIER_TEST_RUNNING=${BIER_TEST_RUNNING:-} \
		XDG_CONFIG_HOME=$WORK/config-$host \
		"$WORK/code-$host/Sources/bier-core/bier" "$@" <"$WORK/.in" >"$WORK/.out" 2>&1 || rc=$?
	OUT=$(cat "$WORK/.out")
	assert_sane "$OUT"
	return $rc
}

# Path to one Mac's Brewfile.
bf() {
	printf '%s' "$WORK/$1/Brewfiles/$2"
}
