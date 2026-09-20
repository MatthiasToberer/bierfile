#!/usr/bin/env bash
# upgrade follows releases: a newer tag counts, an older one does not
#
# Without a tag the code server is just a branch to follow, as before.
# With one, the version decides — and 0.9.1 must not come out newer than
# 0.13.0, which is exactly what comparing the two strings would claim.

system mini <<'SYS'
brew "wget"
SYS

# Nothing tagged: no release is announced, and upgrade falls back to the
# branch, which is level.
assert_ok bier mini state --fetch
assert_not_contains "$OUT" "NEWCODE" "an untagged server announces nothing"
assert_ok bier mini upgrade
assert_contains "$OUT" "up to date" "a level branch is up to date"

# A release older than this build is not an upgrade.
git -C "$WORK/code.git" tag -a v0.1.0 -m v0.1.0
assert_ok bier mini state --fetch
assert_not_contains "$OUT" "NEWCODE" "an older release is not an upgrade"
assert_ok bier mini upgrade
assert_contains "$OUT" "up to date" "and upgrade says so rather than moving"

# The string trap: 0.9.1 must not beat 0.13.0.
git -C "$WORK/code.git" tag -a v0.9.1 -m v0.9.1
assert_ok bier mini state --fetch
assert_not_contains "$OUT" "NEWCODE" "0.9.1 is older than 0.13.0, not newer"

# A genuinely newer release is announced, with its number.
git -C "$WORK/code.git" tag -a v0.99.0 -m v0.99.0
assert_ok bier mini state --fetch
assert_contains "$OUT" "NEWCODE" "the newer release has to be announced"
assert_contains "$OUT" "0.99.0" "and named by its version"
