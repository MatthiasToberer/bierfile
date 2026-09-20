#!/usr/bin/env bash
# Output stays clean, even when piped into head
#
# "bier list | head" reported a broken pipe because the output loop ran
# as the right-hand side of a pipeline. The harness otherwise redirects
# into a file, hence a real pipe here for once.

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
EOF
seed_file macbook Brewfiles/macbook <<'EOF'
cask "font-a"
cask "font-b"
cask "font-c"
EOF

err=$(
	BIER_ROOT=$WORK/code-mini BIER_DATA=$WORK/mini BIER_HOST=mini \
		BIER_TEST_SYSTEM=$WORK/sys-mini \
		XDG_CONFIG_HOME=$WORK/config-mini \
		"$WORK/code-mini/bin/bier" list 2>&1 >/dev/null | head -1
)
assert_eq "" "$err" "list must not complain when its output is cut short"

both=$(
	BIER_ROOT=$WORK/code-mini BIER_DATA=$WORK/mini BIER_HOST=mini \
		BIER_TEST_SYSTEM=$WORK/sys-mini \
		XDG_CONFIG_HOME=$WORK/config-mini \
		"$WORK/code-mini/bin/bier" list 2>&1 | head -2
)
assert_sane "$both"
