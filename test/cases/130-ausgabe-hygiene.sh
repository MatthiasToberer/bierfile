#!/usr/bin/env bash
# Ausgabe bleibt sauber, auch wenn sie in head läuft
#
# "bier list | head" meldete einen Broken Pipe, weil die Ausgabeschleife
# als rechte Seite einer Pipeline lief. Die Harness leitet sonst in eine
# Datei, deshalb hier ausnahmsweise ein echter Rohraufruf.

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
assert_eq "" "$err" "list darf beim Abschneiden nicht klagen"

both=$(
	BIER_ROOT=$WORK/code-mini BIER_DATA=$WORK/mini BIER_HOST=mini \
		BIER_TEST_SYSTEM=$WORK/sys-mini \
		XDG_CONFIG_HOME=$WORK/config-mini \
		"$WORK/code-mini/bin/bier" list 2>&1 | head -2
)
assert_sane "$both"
