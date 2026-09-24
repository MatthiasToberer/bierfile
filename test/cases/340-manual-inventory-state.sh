#!/usr/bin/env bash
# unrecorded software does not empty the glass
#
# The menu bar speaks up when something arrived or something is wrong.
# Something installed here and not on a list is neither: in manual mode
# it is a choice, in automatic mode the next sync records it. It stays
# reported for status, and --record records it in manual mode.

system mini <<'EOF'
EOF
assert_ok bier mini dump
assert_ok bier mini sync
assert_ok bier mini config inventory manual

system mini <<'EOF'
brew "firefox"
EOF

bier mini state
assert_contains "$OUT" "STATE"$'\t'"ok" "unlisted software is a choice in manual mode"
assert_contains "$OUT" "NEW"$'\t''brew "firefox"' "but it is still reported"

# A plain sync leaves it alone.
assert_ok bier mini sync
bier mini state
assert_contains "$OUT" "NEW"$'\t''brew "firefox"'

# Asking for it records it.
assert_ok bier mini sync --record
assert_file_has "$(bf mini mini)" 'brew "firefox"'
bier mini state
assert_contains "$OUT" "STATE"$'\t'"ok"
assert_not_contains "$OUT" "NEW"$'\t'

# In automatic mode the next sync records it: nothing for the glass.
assert_ok bier mini config inventory automatic
system mini <<'EOF'
brew "firefox"
brew "htop"
EOF
bier mini state
assert_contains "$OUT" "STATE"$'\t'"ok"
assert_contains "$OUT" "NEW"$'\t''brew "htop"'
