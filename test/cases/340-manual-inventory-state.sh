#!/usr/bin/env bash
# in manual mode unrecorded software does not empty the glass
#
# sync records nothing in manual mode, so the menu's "record and push"
# could never fill the glass again: it stayed empty for good. What is
# not listed is a choice there, until somebody asks with --record.

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
assert_contains "$OUT" "INVENTORY"$'\t'"manual"
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

# In automatic mode it is drift, as before.
assert_ok bier mini config inventory automatic
system mini <<'EOF'
brew "firefox"
brew "htop"
EOF
bier mini state
assert_contains "$OUT" "STATE"$'\t'"drift"
assert_contains "$OUT" "INVENTORY"$'\t'"automatic"
