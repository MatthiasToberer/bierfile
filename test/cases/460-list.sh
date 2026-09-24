#!/usr/bin/env bash
# list shows everything bier keeps: packages, their settings, and files
#
# The lists said what is installed, the vault what is shared, and nothing
# said both. bier list (or ls) now puts each app's settings next to it and
# the shared files after. And a path is shared once: two entries for one
# file would take and put it against each other.

system mini <<'SYS'
brew "wget"
SYS
export BIER_VAULT_PASS=probe
printf 'handbrake-app HandBrake.app\n' >"$WORK/brew-casks"
printf 'jq\n' >"$WORK/brew-formulas"
mkdir -p "$WORK/apps/HandBrake.app/Contents"
plutil -create xml1 "$WORK/apps/HandBrake.app/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string fr.handbrake.HandBrake "$WORK/apps/HandBrake.app/Contents/Info.plist"
BIER_APPS_DIR=$WORK/apps
export BIER_APPS_DIR
h=$WORK/home-mini
mkdir -p "$h/Library/Application Support/HandBrake" "$h/.config/jq" "$h/.config/nvim" "$h/Tools/Foo"
printf 'p\n' >"$h/Library/Application Support/HandBrake/UserPresets.json"
printf 'q\n' >"$h/.config/jq/defs.jq"
printf 'n\n' >"$h/.config/nvim/init.lua"
printf 'z\n' >"$h/.zshrc"
printf 'f\n' >"$h/Tools/Foo/foo.conf"

answer m 1
assert_ok bier mini add handbrake-app
assert_ok bier mini add --here --settings jq
assert_ok bier mini vault add "$h/.zshrc" "$h/.config/nvim"
assert_ok bier mini vault add --app Foo "$h/Tools/Foo"
assert_ok bier mini sync

assert_ok bier mini ls
list=$OUT
assert_contains "$list" "Every Mac (main)"
assert_contains "$list" "handbrake-app"
assert_contains "$list" "settings: Application Support"
assert_contains "$list" "Only on mini (this Mac)"
assert_contains "$list" "settings: config (only mini)"
assert_contains "$list" "Files"
assert_contains "$list" "~/.zshrc"
assert_contains "$list" "~/.config/nvim/"
assert_not_contains "$list" "init.lua" "a shared folder is listed once"
assert_contains "$list" "Settings of apps on no list"
assert_contains "$list" "Foo"
assert_eq 1 "$(printf '%s\n' "$list" | grep -c 'Application Support')" "each app's settings once"

# Shared once, whichever way it is asked for.
assert_fails bier mini vault add "$h/.zshrc"
assert_contains "$OUT" "shared already"
assert_fails bier mini vault add "$h/.config/nvim/init.lua"
assert_contains "$OUT" "shared already"
assert_fails bier mini vault add --app Other "$h/Library/Application Support/HandBrake"
assert_contains "$OUT" "shared already, as apps/HandBrake/Application Support"
assert_fails bier mini vault add "$h/.config"
assert_contains "$OUT" "shared already"
