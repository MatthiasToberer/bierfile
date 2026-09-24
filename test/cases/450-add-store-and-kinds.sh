#!/usr/bin/env bash
# App Store apps, npm and cargo entries, and settings that hold secrets
#
# bier knew five kinds of Brewfile entry; an npm or cargo entry dropped out
# of the lists on the next dump, and install refused the file for holding
# something that was no entry. add knew only casks and formulae. And the
# settings it offers must never include keys or passwords unasked.

system mini <<'SYS'
brew "wget"
SYS
export BIER_VAULT_PASS=probe
printf '361309726 Pages\n1475387142 Tailscale\n' >"$WORK/mas-store"
BIER_APPS_DIR=$WORK/apps
export BIER_APPS_DIR
bundle() {
	mkdir -p "$WORK/apps/$1.app/Contents"
	plutil -create xml1 "$WORK/apps/$1.app/Contents/Info.plist"
	plutil -insert CFBundleIdentifier -string "$2" "$WORK/apps/$1.app/Contents/Info.plist"
}
bundle Pages com.apple.Pages
bundle Tailscale io.tailscale.ipn.macos
box=$WORK/home-mini/Library/Containers/com.apple.Pages/Data/Library
mkdir -p "$box/Preferences" "$box/Application Support/Pages"
printf 'prefs\n' >"$box/Preferences/com.apple.Pages.plist"
printf 'templates\n' >"$box/Application Support/Pages/templates.json"
mkdir -p "$WORK/home-mini/Library/Containers/io.tailscale.ipn.macos/Data/Library/Preferences"

# An App Store app by its store name: installed with mas, listed with its id.
answer m a
assert_ok bier mini add Pages
assert_file_has "$WORK/sys-mini" 'mas "Pages", id: 361309726'
assert_file_has "$(bf mini main)" 'mas "Pages", id: 361309726'
assert_contains "$OUT" "Pages keeps its settings here:"
assert_contains "$OUT" "com.apple.Pages/Data/Library/Preferences/com.apple.Pages.plist"
[ -f "$WORK/home-mini/.barrel/vault/apps/Pages/.bier-map" ] || fail "its settings go under apps/Pages"

# A VPN client's settings hold its keys: not offered.
answer m
assert_ok bier mini add Tailscale
assert_file_has "$(bf mini main)" 'mas "Tailscale", id: 1475387142'
assert_contains "$OUT" "Tailscale holds keys, passwords or accounts; bier does not offer"
[ ! -e "$WORK/home-mini/.barrel/vault/apps/Tailscale" ] || fail "nothing of it may go into the vault"

# A token inside a shared folder stays out as well.
printf 'secret\n' >"$box/Application Support/Pages/api-token"
assert_ok bier mini sync
[ -f "$WORK/home-mini/.barrel/vault/apps/Pages/Application Support/templates.json" ] || fail "the settings travel"
[ ! -e "$WORK/home-mini/.barrel/vault/apps/Pages/Application Support/api-token" ] || fail "a token must not travel"

# npm and cargo entries survive a dump, install, and uninstall.
printf 'npm "prettier"\ncargo "ripgrep"\n' >>"$(bf mini main)"
system mini <<'SYS'
brew "wget"
mas "Pages", id: 361309726
mas "Tailscale", id: 1475387142
SYS
assert_ok bier mini install
assert_file_has "$WORK/sys-mini" 'npm "prettier"'
assert_ok bier mini dump
assert_file_has "$(bf mini main)" 'npm "prettier"'
bier mini status
assert_not_contains "$OUT" "not entries"
assert_ok bier mini uninstall --everywhere prettier ripgrep
assert_file_has "$WORK/npm.args" "uninstall --global prettier"
assert_file_has "$WORK/cargo.args" "uninstall ripgrep"
assert_file_lacks "$(bf mini main)" 'npm "prettier"'
