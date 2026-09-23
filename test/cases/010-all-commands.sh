#!/usr/bin/env bash
# Every command exits cleanly, even with empty files
#
# Covers two bugs that struck right here: "trap RETURN" fired a second
# time with the variable gone, and "entries" returned exit 1 for a file
# without entries, which with pipefail dragged every assignment down.
# Both times bier died without a word.

system mini <<'EOF'
brew "wget"
EOF
system macbook <<'EOF'
brew "wget"
EOF

assert_ok bier mini dump
assert_ok bier macbook dump
share

# The commands that touch the server too: during the split into two
# repositories cmd_push vanished along with the function next to it,
# while its line in the dispatch table stayed. Nobody noticed.
for c in help status state list diff config dump push sync; do
	assert_ok bier mini "$c"
done

assert_ok bier mini config inventory manual
assert_contains "$OUT" 'inventory = manual'
before=$(cat "$(bf mini mini)")
system mini <<'EOF'
brew "wget"
brew "firefox"
EOF
assert_ok bier mini sync
assert_contains "$OUT" 'Inventory is manual; keeping the Brewfiles as written.'
assert_eq "$before" "$(cat "$(bf mini mini)")" "manual sync must not record the full Homebrew inventory"
assert_ok bier mini config inventory automatic

# And with a completely empty main, the original crash.
: >"$(bf mini main)"
assert_ok bier mini dump
assert_ok bier mini state
