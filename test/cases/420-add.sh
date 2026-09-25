#!/usr/bin/env bash
# add installs, puts it on a list, and offers the app's settings
#
# Adding an app used to mean editing Brewfiles/main by hand, and its
# settings had to be found and added to the vault separately. add does
# both, keeps the settings under apps/<App>/ in the vault, and the other
# Mac starts a sandboxed app once, hidden, so that macOS makes its
# container before the settings go in.

system mini <<'SYS'
brew "wget"
SYS
system macbook <<'SYS'
brew "wget"
SYS
export BIER_VAULT_PASS=probe
printf 'handbrake-app HandBrake.app\n' >"$WORK/brew-casks"
printf 'jq\n' >"$WORK/brew-formulas"

app_bundle() {
	mkdir -p "$1/HandBrake.app/Contents"
	plutil -create xml1 "$1/HandBrake.app/Contents/Info.plist"
	plutil -insert CFBundleIdentifier -string fr.handbrake.HandBrake "$1/HandBrake.app/Contents/Info.plist"
}
app_bundle "$WORK/apps-mini"
app_bundle "$WORK/apps-macbook"

box=Library/Containers/fr.handbrake.HandBrake/Data/Library
mkdir -p "$WORK/home-mini/$box/Application Support/HandBrake" "$WORK/home-mini/$box/Preferences"
printf '{"PresetList":["Fast"]}\n' >"$WORK/home-mini/$box/Application Support/HandBrake/UserPresets.json"
printf 'window\n' >"$WORK/home-mini/$box/Preferences/fr.handbrake.HandBrake.plist"

# Nobody to ask: nothing is put on a list.
BIER_APPS_DIR=$WORK/apps-mini
export BIER_APPS_DIR
: >"$WORK/.in"
assert_fails bier mini add handbrake-app
assert_contains "$OUT" "Say where: bier add --all | --group <g> | --here handbrake-app"

# Into main, and only the presets are shared.
answer m 1
assert_ok bier mini add handbrake-app
assert_file_has "$WORK/sys-mini" 'cask "handbrake-app"'
assert_file_has "$(bf mini main)" 'cask "handbrake-app"'
assert_contains "$OUT" "HandBrake keeps its settings here:"
assert_contains "$OUT" "$box/Application Support/HandBrake"
assert_contains "$OUT" "$box/Preferences/fr.handbrake.HandBrake.plist"
assert_contains "$OUT" "also window positions and recent files"
vault=$WORK/home-mini/.barrel/vault
[ -f "$vault/apps/HandBrake/Application Support/.bier-folder" ] || fail "the presets have to sit under apps/HandBrake"
[ ! -e "$vault/apps/HandBrake/Preferences.plist" ] || fail "only what was picked goes into the vault"
assert_file_has "$vault/apps/HandBrake/.bier-map" "Application Support"
assert_ok bier mini sync
assert_file_has "$vault/apps/HandBrake/Application Support/UserPresets.json" "Fast"
bier mini status
assert_not_contains "$OUT" "Sync (bier sync):" "after the sync nothing is pending"

# The other Mac: not installed yet, so its settings wait.
BIER_APPS_DIR=$WORK/apps-macbook
assert_ok bier macbook sync
assert_contains "$OUT" "waiting: fr.handbrake.HandBrake is not installed here"
[ ! -e "$WORK/home-macbook/Library/Containers/fr.handbrake.HandBrake" ] || fail "bier must not make the container itself"

# Installed: started once, hidden, and quit; then the presets go in.
printf 'fr.handbrake.HandBrake\n' >"$WORK/installed-apps"
assert_ok bier macbook install
assert_ok bier macbook sync
assert_contains "$OUT" "started fr.handbrake.HandBrake once, hidden"
assert_file_has "$WORK/open.args" "-g -j -b fr.handbrake.HandBrake"
assert_file_has "$WORK/osascript.args" 'quit'
assert_eq '{"PresetList":["Fast"]}' "$(cat "$WORK/home-macbook/$box/Application Support/HandBrake/UserPresets.json")"

# A new preset made there travels back.
printf '{"PresetList":["Fast","Slow"]}\n' >"$WORK/home-macbook/$box/Application Support/HandBrake/UserPresets.json"
assert_ok bier macbook sync
assert_ok bier mini sync
assert_file_has "$WORK/home-mini/$box/Application Support/HandBrake/UserPresets.json" "Slow"

# Only here: on this Mac's list, and its settings for this Mac only.
mkdir -p "$WORK/home-mini/.config/jq"
printf 'def x: 1;\n' >"$WORK/home-mini/.config/jq/defs.jq"
assert_ok bier mini add --here --settings jq
assert_file_has "$WORK/sys-mini" 'brew "jq"'
assert_file_has "$(bf mini mini)" 'brew "jq"'
assert_file_lacks "$(bf mini main)" 'brew "jq"'
[ -f "$vault/@mini/apps/jq/config/.bier-folder" ] || fail "the settings of a Mac's own tool are for that Mac only"

# An app already in main is not added twice, and what is shared already
# is not offered again.
answer ""
assert_ok bier mini add handbrake-app
assert_contains "$OUT" "handbrake-app is in main already."
assert_not_contains "$OUT" "Application Support/HandBrake   "
assert_contains "$OUT" "Preferences/fr.handbrake.HandBrake.plist"
assert_eq 1 "$(grep -c 'handbrake-app' "$(bf mini main)")"
