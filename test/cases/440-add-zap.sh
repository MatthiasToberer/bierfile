#!/usr/bin/env bash
# add finds an app's settings through Homebrew's zap list
#
# A cask's zap list names everything the app leaves outside
# /Applications. add offers what of it is a setting and leaves out
# caches, logs, web data, window state and recent-file lists.

system mini <<'SYS'
brew "wget"
SYS
export BIER_VAULT_PASS=probe
printf 'rectangle Rectangle.app\n' >"$WORK/brew-casks"
mkdir -p "$WORK/apps/Rectangle.app/Contents"
plutil -create xml1 "$WORK/apps/Rectangle.app/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string com.knollsoft.Rectangle "$WORK/apps/Rectangle.app/Contents/Info.plist"
BIER_APPS_DIR=$WORK/apps
export BIER_APPS_DIR

h=$WORK/home-mini
launcher=Library/Containers/com.knollsoft.RectangleLauncher
for p in "Library/Application Support/Rectangle" "Library/Caches/com.knollsoft.Rectangle" \
	"Library/HTTPStorages/com.knollsoft.Rectangle" "Library/WebKit/com.knollsoft.Rectangle" \
	"Library/Saved Application State/com.knollsoft.Rectangle.savedState" \
	"Library/Application Scripts/com.knollsoft.RectangleLauncher" \
	"$launcher/Data/Library/Application Support/Launch"; do
	mkdir -p "$h/$p"
	printf 'x\n' >"$h/$p/file"
done
mkdir -p "$h/Library/Preferences"
printf 'prefs\n' >"$h/Library/Preferences/com.knollsoft.Rectangle.plist"
printf 'rc\n' >"$h/.rectanglerc"
{
	for p in "Library/Application Support/Rectangle" "Library/Caches/com.knollsoft.Rectangle" \
		"Library/HTTPStorages/com.knollsoft.Rectangle" "Library/WebKit/com.knollsoft.Rectangle" \
		"Library/Saved Application State/com.knollsoft.Rectangle.savedState" \
		"Library/Application Scripts/com.knollsoft.RectangleLauncher" \
		"Library/Preferences/com.knollsoft.Rectangle.plist" "$launcher" ".rectanglerc" \
		"Library/Application Support/com.apple.sharedfilelist/x.sfl*"; do
		printf 'rectangle ~/%s\n' "$p"
	done
} >"$WORK/brew-zap"

answer m ""
assert_ok bier mini add rectangle
assert_contains "$OUT" "Rectangle keeps its settings here:"
assert_contains "$OUT" "Library/Application Support/Rectangle "
assert_contains "$OUT" "Library/Preferences/com.knollsoft.Rectangle.plist"
assert_contains "$OUT" ".rectanglerc" "a place only the zap list knows is found"
assert_contains "$OUT" "$launcher/Data/Library/Application Support/Launch" "a container is looked into"
for noise in Caches HTTPStorages WebKit "Saved Application State" "Application Scripts" sharedfilelist; do
	assert_not_contains "$OUT" "$noise" "$noise is not a setting"
done
assert_eq 1 "$(printf '%s\n' "$OUT" | grep -c 'Application Support/Rectangle ')" "each place once"
