#!/usr/bin/env bash
# groups and place: every Mac is in one group; software goes to All Macs
# or to groups, never to a single Mac
#
# A Mac has All Macs plus its group. Moving it to another group makes it
# take on that group's software. bier place writes exactly the lists
# named; --now marks the change, and a Mac that receives it installs and
# removes at once, unless its group asks first.

system mini <<'SYS'
brew "wget"
brew "jq"
SYS
system macbook <<'SYS'
brew "wget"
SYS
export BIER_VAULT_PASS=probe
printf 'firefox Firefox.app\n' >"$WORK/brew-casks"
printf 'htop\nhtopx\n' >"$WORK/brew-formulas"
assert_ok bier mini dump
assert_ok bier mini main
data=$(dirname "$(dirname "$(bf mini main)")")

# The first time: every Mac with a list gets a group of its own.
printf 'brew "htop"\n' >>"$(bf mini mini)"
assert_ok bier mini group
assert_contains "$OUT" "every Mac is in one now"
assert_contains "$OUT" "mini = mini   (this Mac)"
assert_file_has "$data/Brewfiles/@mini" 'brew "htop"'
assert_file_has "$data/.gitattributes" 'groups merge=union'

# Groups are Macs only, and a Mac is in one: joining one leaves the other.
assert_ok bier mini group laptops mini macbook
assert_ok bier mini group
assert_contains "$OUT" "laptops = mini macbook   (this Mac)"
assert_not_contains "$OUT" "mini = mini"

# Software to a group; a single Mac is refused.
assert_ok bier mini place jq --on laptops
assert_ok bier mini report
assert_contains "$OUT" 'ENTRY	@laptops	brew "jq"'
assert_not_contains "$OUT" "MAC	@laptops" "a group is not a Mac"
assert_contains "$OUT" "GROUP	laptops	mini macbook"
assert_ok bier mini status
assert_not_contains "$OUT" "jq" "jq counts for mini through its group"
assert_fails bier mini place wget --on macbook
assert_contains "$OUT" "not a group"
assert_ok bier mini place wget --all
assert_ok bier mini report
assert_contains "$OUT" 'ENTRY	main	brew "wget"'

# Something no Mac has yet, for every Mac, installed right away.
assert_ok bier mini place firefox --all --now
assert_contains "$OUT" "Installing firefox here"
assert_contains "$(git -C "$data" log -1 --format=%s)" "(install now)"
assert_fails bier mini place jq --on nobody
assert_fails bier mini place jq

# Rules belong to the group: apply ask, then the arrival only reports.
assert_ok bier mini group rule laptops apply ask
assert_ok bier mini state
assert_contains "$OUT" "MYGROUP	laptops"
git -C "$data" commit -q --allow-empty -m "macbook: htop on every Mac (install now)"
assert_ok bier mini apply --received
assert_contains "$OUT" "this Mac asks first"
assert_ok bier mini group rule laptops apply automatic
git -C "$data" commit -q --allow-empty -m "macbook: nmap on every Mac (install now)"
assert_ok bier mini apply --received
assert_contains "$OUT" "installed"

# Moving a Mac: it takes on the new group at once.
assert_ok bier mini group studio macbook
assert_ok bier mini group move mini studio
assert_ok bier mini state
assert_contains "$OUT" "MYGROUP	studio"
assert_ok bier mini search htop
assert_contains "$OUT" "FOUND	brew	htop	"

# take moved entries between main and the Macs' lists; now place does.
assert_fails bier mini take
assert_contains "$OUT" "take is gone"
assert_contains "$OUT" "bier place <pkg> --on <group>"
