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

# And with a completely empty main, the original crash.
: >"$(bf mini main)"
assert_ok bier mini dump
assert_ok bier mini state
