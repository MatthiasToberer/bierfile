#!/usr/bin/env bash
# version names itself, and state reports it for the menu bar

bier mini version
assert_contains "$OUT" "bier "
assert_contains "$OUT" "Code    $WORK/code-mini"
assert_contains "$OUT" "Data    $WORK/mini"
assert_contains "$OUT" "Device  mini"

# The app compares its own number against this line to notice that it is
# out of date.
system mini <<'EOF'
brew "wget"
EOF
bier mini state
version=$(printf '%s\n' "$OUT" | sed -n 's/^VERSION'$'\t''//p')
assert_eq "$(sed -nE 's/^BIER_VERSION=(.*)$/\1/p' "$REPO/Sources/bier-core/bier")" "$version" \
	"state has to report the same version the script carries"

# Sources/bier-trayapp/build.sh reads the same number out of the script into the app
# bundle. This checks the source, not the build artefact — a stale build
# in the working directory should not turn the test red.
assert_contains "$(sed -n '/^VERSION=/p' "$REPO/Sources/bier-trayapp/build.sh")" "BIER_VERSION" \
	"the tray app build has to read the number from Sources/bier-core/bier"
