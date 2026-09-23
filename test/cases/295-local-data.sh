#!/usr/bin/env bash
# Bier works locally before the first peer is paired

git -C "$WORK/mini" remote remove origin
system mini <<'EOF'
brew "firefox"
EOF

assert_ok bier mini sync
assert_contains "$OUT" 'Saved in the local Bier history.'
assert_eq 'mini: inventory updated' "$(git -C "$WORK/mini" log -1 --format=%s)" \
	"a server-free sync must commit locally"

assert_ok bier mini main
assert_contains "$OUT" 'Saved in the local Bier history.'
assert_file_has "$(bf mini main)" 'brew "firefox"'
