#!/usr/bin/env bash
# state says when a server could not be reached
#
# The fetch used to end in "|| true": a server that was away passed
# unnoticed, and the glass in the menu bar looked full while nothing had
# been heard for days. It also has to give up quickly -- the menu bar
# waits for this call, and while it waits the glass keeps foaming.

system mini <<'SYS'
brew "wget"
SYS
assert_ok bier mini dump

# While everything is reachable, nothing is reported.
assert_ok bier mini state --fetch
assert_not_contains "$OUT" "OFFLINE" "a reachable server says nothing"

# Point the inventory at a server that is not there.
git -C "$WORK/mini" remote set-url origin "$WORK/weg.git"
assert_ok bier mini state --fetch
assert_contains "$OUT" "OFFLINE" "an unreachable server has to be reported"
assert_contains "$OUT" "data" "and named"

# It still answers: an unreachable server must not take the state with
# it, or the menu bar has nothing to show at all.
assert_contains "$OUT" "HOST" "the rest of the state still has to come"

# Both of them.
git -C "$WORK/code-mini" remote set-url origin "$WORK/auchweg.git"
assert_ok bier mini state --fetch
assert_contains "$OUT" "data code" "both have to be named"
