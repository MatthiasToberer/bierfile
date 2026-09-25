#!/usr/bin/env bash
# place: where a package belongs -- every Mac, groups of Macs, single Macs
#
# A group is Macs only; software given to a group is in Brewfiles/@group
# and every member has it. bier place writes exactly the lists named and
# takes the package off the others. --now marks the change, and a Mac
# that receives it installs and removes at once, unless it asks first.

system mini <<'SYS'
brew "wget"
brew "jq"
SYS
export BIER_VAULT_PASS=probe
printf 'firefox Firefox.app\n' >"$WORK/brew-casks"
printf 'htop\nhtopx\n' >"$WORK/brew-formulas"
assert_ok bier mini dump
assert_ok bier mini main
assert_ok bier mini vault group laptops mini macbook

# To a group: off main, onto the group's list; mini has it through it.
assert_ok bier mini place jq --on @laptops
assert_file_has "$(bf mini main)" 'brew "wget"'
assert_ok bier mini report
assert_contains "$OUT" 'ENTRY	@laptops	brew "jq"'
assert_not_contains "$OUT" "MAC	@laptops" "a group is not a Mac"
assert_ok bier mini status
assert_not_contains "$OUT" "jq" "jq counts for mini through its group"

# To single Macs, then back to every Mac: always exactly what is named.
assert_ok bier mini place wget --on mini,macbook
assert_ok bier mini report
assert_contains "$OUT" 'ENTRY	mini	brew "wget"'
assert_contains "$OUT" 'ENTRY	macbook	brew "wget"'
assert_not_contains "$OUT" 'ENTRY	main	brew "wget"'
assert_ok bier mini place wget --all
assert_ok bier mini report
assert_contains "$OUT" 'ENTRY	main	brew "wget"'
assert_not_contains "$OUT" 'ENTRY	mini	brew "wget"'

# Something no Mac has yet, for every Mac, installed right away.
assert_ok bier mini place firefox --all --now
assert_contains "$OUT" "Installing firefox here"
assert_contains "$(git -C "$(dirname "$(dirname "$(bf mini main)")")" log -1 --format=%s)" "(install now)"

# Mistakes are refused.
assert_fails bier mini place jq --on @nobody
assert_fails bier mini place jq
assert_ok bier mini search htop
assert_contains "$OUT" "FOUND	brew	htop	no"

# A change marked install now is applied when it arrives -- unless asked.
assert_ok bier mini apply --received
git -C "$(dirname "$(dirname "$(bf mini main)")")" commit -q --allow-empty -m "macbook: htop on every Mac (install now)"
assert_ok bier mini config apply ask
assert_ok bier mini apply --received
assert_contains "$OUT" "this Mac asks first"
git -C "$(dirname "$(dirname "$(bf mini main)")")" commit -q --allow-empty -m "macbook: nmap on every Mac (install now)"
assert_ok bier mini config apply automatic
assert_ok bier mini apply --received
assert_contains "$OUT" "installed"
