#!/usr/bin/env bash
# sync merges simultaneous changes without asking

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
EOF

# Both Macs append to the same file.
printf 'brew "from-macbook"\n' >>"$(bf macbook main)"
git -C "$WORK/macbook" add -A
git -C "$WORK/macbook" commit -qm "macbook"
git -C "$WORK/macbook" push -q

printf 'brew "from-mini"\n' >>"$(bf mini main)"

system mini <<'EOF'
brew "wget"
EOF

answer
bier mini sync
out=$OUT
assert_not_contains "$out" "CONFLICT"
assert_not_contains "$out" "failed"

assert_file_has "$(bf mini main)" 'brew "from-macbook"' "the other change has to arrive"
assert_file_has "$(bf mini main)" 'brew "from-mini"' "our own must not be lost"
assert_file_lacks "$(bf mini main)" "<<<<<<<" "no conflict markers"
