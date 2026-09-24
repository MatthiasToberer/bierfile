#!/usr/bin/env bash
# a tracked folder keeps an app's settings alike on every Mac
#
# App settings and profiles live in folders, and apps add and remove
# files there. A tracked folder takes new files along, sends deleted
# ones to the Trash on the other Macs, leaves noise and large files out,
# and waits while the app is running -- it would write over bier's
# change when it quits.

system mini <<'SYS'
brew "wget"
SYS
system macbook <<'SYS'
brew "wget"
SYS
export BIER_VAULT_PASS=probe
BIER_VAULT_MAX_FILE=1K
export BIER_VAULT_MAX_FILE

app="Library/Application Support/TestApp"
mkdir -p "$WORK/home-mini/$app/Presets" "$WORK/home-mini/$app/Caches"
printf '{"preset":"fast"}\n' >"$WORK/home-mini/$app/Presets/fast.json"
printf 'window=1\n' >"$WORK/home-mini/$app/settings.ini"
printf 'noise\n' >"$WORK/home-mini/$app/Caches/blob"
printf 'noise\n' >"$WORK/home-mini/$app/.DS_Store"
head -c 4096 /dev/zero >"$WORK/home-mini/$app/huge.bin"

assert_ok bier mini vault add "$WORK/home-mini/$app"
assert_contains "$OUT" "2 entries now, and whatever is put in it later"
assert_contains "$OUT" "not taken, larger than vault_max_file"
assert_ok bier mini sync
bier mini status
assert_contains "$OUT" "huge.bin not taken: larger than vault_max_file"

# The other Mac gets the folder, without the noise and the large file.
assert_ok bier macbook sync
assert_eq '{"preset":"fast"}' "$(cat "$WORK/home-macbook/$app/Presets/fast.json")"
assert_eq 'window=1' "$(cat "$WORK/home-macbook/$app/settings.ini")"
for left_out in Caches/blob .DS_Store huge.bin; do
	[ ! -e "$WORK/home-macbook/$app/$left_out" ] || fail "$left_out must stay out"
done

# A file put in the folder later comes along.
printf '{"preset":"slow"}\n' >"$WORK/home-mini/$app/Presets/slow.json"
bier mini status
assert_contains "$OUT" "$WORK/home-mini/$app/Presets/slow.json new here"
assert_ok bier mini sync
assert_ok bier macbook sync
assert_eq '{"preset":"slow"}' "$(cat "$WORK/home-macbook/$app/Presets/slow.json")"

# A file deleted from it goes to the Trash on the other Mac.
rm "$WORK/home-mini/$app/Presets/fast.json"
bier mini status
assert_contains "$OUT" "fast.json deleted here"
assert_ok bier mini sync
git -C "$WORK/macbook" pull -q --rebase
bier macbook state
assert_contains "$OUT" "VAULT_IN"$'\t'"$WORK/home-macbook/$app/Presets/fast.json"$'\t'"deleted"
assert_ok bier macbook sync
assert_contains "$OUT" "moved to the Trash: $WORK/home-macbook/$app/Presets/fast.json"
[ ! -e "$WORK/home-macbook/$app/Presets/fast.json" ] || fail "the deleted file must be gone"
assert_eq '{"preset":"fast"}' "$(cat "$WORK/trash-macbook/fast.json")" "and be in the Trash"

# While the app runs, nothing is written into its folder.
printf 'window=2\n' >"$WORK/home-mini/$app/settings.ini"
assert_ok bier mini sync
git -C "$WORK/macbook" pull -q --rebase
BIER_TEST_RUNNING=TestApp
export BIER_TEST_RUNNING
bier macbook status
assert_contains "$OUT" "settings.ini waiting: TestApp is running"
assert_ok bier macbook sync
assert_contains "$OUT" "waiting: TestApp is running"
assert_eq 'window=1' "$(cat "$WORK/home-macbook/$app/settings.ini")" "a running app's file is left alone"
unset BIER_TEST_RUNNING
assert_ok bier macbook sync
assert_eq 'window=2' "$(cat "$WORK/home-macbook/$app/settings.ini")" "and updated once it has quit"

# The version replaced is in the backups ...
backup=$(find "$WORK/home-macbook/.barrel/state/backups" -name settings.ini | head -1)
[ -n "$backup" ] || fail "the replaced version has to be in the backups"
assert_eq 'window=1' "$(cat "$backup")"
# ... unless the config says no.
printf 'vault_backup = no\n' >>"$WORK/home-macbook/.barrel/config"
rm -rf "$WORK/home-macbook/.barrel/state/backups"
printf 'window=3\n' >"$WORK/home-mini/$app/settings.ini"
assert_ok bier mini sync
assert_ok bier macbook sync
assert_eq 'window=3' "$(cat "$WORK/home-macbook/$app/settings.ini")"
[ ! -e "$WORK/home-macbook/.barrel/state/backups" ] || fail "vault_backup = no makes no backups"

# Forgetting the folder stops the syncing; the files stay everywhere.
assert_ok bier mini vault forget "$WORK/home-mini/$app"
assert_ok bier mini sync
assert_ok bier macbook sync
assert_contains "$OUT" "no longer synced"
assert_eq 'window=3' "$(cat "$WORK/home-macbook/$app/settings.ini")"
printf 'window=4\n' >"$WORK/home-mini/$app/settings.ini"
assert_ok bier mini sync
assert_ok bier macbook sync
assert_eq 'window=3' "$(cat "$WORK/home-macbook/$app/settings.ini")" "a forgotten folder does not travel"
assert_eq 'window=4' "$(cat "$WORK/home-mini/$app/settings.ini")"
