#!/usr/bin/env bash
# vault: a file travels encrypted and lands as a plain file on the other Mac
#
# The plain file never goes near the repository. What travels is the
# encrypted copy under Safe/. Files stay real files where they belong:
# the vault only keeps a copy, so removing bier leaves them in place.

system mini <<'SYS'
brew "wget"
SYS
system macbook <<'SYS'
brew "wget"
SYS

export BIER_VAULT_PASS=probe
is_link() { [ -L "$1" ] && echo yes || echo no; }

# Take a file in: it stays where it is, the vault gets a copy.
printf 'export EDITOR=vim\n' >"$WORK/home-mini/.zshrc"
assert_ok bier mini vault add "$WORK/home-mini/.zshrc"
assert_eq "no" "$(is_link "$WORK/home-mini/.zshrc")" "the original has to stay a real file"
assert_file_has "$WORK/home-mini/.bierfilevault/dot_zshrc" "EDITOR=vim" \
	"and the vault has to hold a copy"

# Sync encrypts it. What lands in the repository must not be readable.
assert_ok bier mini sync
assert_file_lacks "$WORK/mini/Safe/dot_zshrc.gpg" "EDITOR" \
	"the repository must not hold it in the clear"
assert_contains "$(file -b "$WORK/mini/Safe/dot_zshrc.gpg")" "encrypted" \
	"and it has to be encrypted"

# The other Mac gets it as a plain file, without being told anything.
assert_ok bier macbook sync
assert_eq "no" "$(is_link "$WORK/home-macbook/.zshrc")" "the other Mac has to get a plain file"
assert_eq "export EDITOR=vim" "$(cat "$WORK/home-macbook/.zshrc")" "with the content"

# A change on the other Mac travels back.
printf 'export EDITOR=nano\n' >"$WORK/home-macbook/.zshrc"
assert_ok bier macbook sync
assert_ok bier mini sync
assert_eq "export EDITOR=nano" "$(cat "$WORK/home-mini/.zshrc")" \
	"the change has to arrive on the first Mac"
assert_contains "$OUT" "updated: $WORK/home-mini/.zshrc"

# The version it replaced is kept in the backups.
backup=$(find "$WORK/home-mini/.local/state/bier/backups" -name .zshrc | head -1)
[ -n "$backup" ] || fail "the replaced version has to be in the backups"
assert_eq "export EDITOR=vim" "$(cat "$backup")"

# The wrong passphrase opens nothing.
printf 'export EDITOR=ed\n' >"$WORK/home-macbook/.zshrc"
assert_ok bier macbook sync
git -C "$WORK/mini" pull -q --rebase
BIER_VAULT_PASS=falsch bier mini vault open || true
assert_contains "$OUT" "will not open" "a wrong passphrase has to be refused"

# A file deleted by accident comes back from the vault's copy.
assert_ok bier mini sync
rm -f "$WORK/home-mini/.zshrc"
bier mini status
assert_contains "$OUT" "$WORK/home-mini/.zshrc deleted here"
assert_ok bier mini vault --restore
assert_eq "export EDITOR=ed" "$(cat "$WORK/home-mini/.zshrc")" "restore has to bring it back"

# Taking it out stops the syncing and leaves the file everywhere.
assert_ok bier mini vault forget "$WORK/home-mini/.zshrc"
assert_ok bier mini sync
assert_ok bier macbook sync
assert_contains "$OUT" "no longer synced: $WORK/home-macbook/.zshrc"
assert_eq "export EDITOR=ed" "$(cat "$WORK/home-mini/.zshrc")" "forget has to leave the file here"
assert_eq "export EDITOR=ed" "$(cat "$WORK/home-macbook/.zshrc")" "and on the other Mac"
printf 'only here\n' >"$WORK/home-mini/.zshrc"
assert_ok bier mini sync
assert_ok bier macbook sync
assert_eq "export EDITOR=ed" "$(cat "$WORK/home-macbook/.zshrc")" "a forgotten file does not travel any more"

# And the note that explains how to get the files back without bier.
assert_file_has "$WORK/mini/Safe/README-recovery.txt" "gpg -d" \
	"the recovery note has to sit next to the data"
