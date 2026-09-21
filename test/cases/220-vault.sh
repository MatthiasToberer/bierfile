#!/usr/bin/env bash
# vault: a file travels encrypted and lands as a link on the other Mac
#
# The plain file never goes near the repository. What travels is the
# encrypted copy under Safe/, and at the destination there is a link, so
# the file goes on living where the program that reads it expects it.

system mini <<'SYS'
brew "wget"
SYS
system macbook <<'SYS'
brew "wget"
SYS

export BIER_VAULT_PASS=probe
is_link() { [ -L "$1" ] && echo yes || echo no; }

# Take a file in: it moves, and a link stays behind.
printf 'export EDITOR=vim\n' >"$WORK/home-mini/.zshrc"
assert_ok bier mini vault add "$WORK/home-mini/.zshrc"
assert_eq "yes" "$(is_link "$WORK/home-mini/.zshrc")" "the original has to become a link"
assert_file_has "$WORK/home-mini/.bierfilevault/dot_zshrc" "EDITOR=vim" \
	"and the file itself has to be in the vault"
assert_eq "export EDITOR=vim" "$(cat "$WORK/home-mini/.zshrc")" \
	"reading through the link has to work"

# Sync encrypts it. What lands in the repository must not be readable.
assert_ok bier mini sync
assert_file_lacks "$WORK/mini/Safe/dot_zshrc.gpg" "EDITOR" \
	"the repository must not hold it in the clear"
assert_contains "$(file -b "$WORK/mini/Safe/dot_zshrc.gpg")" "encrypted" \
	"and it has to be encrypted"

# The other Mac gets it, as a link, without being told anything.
assert_ok bier macbook sync
assert_eq "yes" "$(is_link "$WORK/home-macbook/.zshrc")" "the other Mac has to get a link"
assert_eq "export EDITOR=vim" "$(cat "$WORK/home-macbook/.zshrc")" "with the content"

# A change made through the link travels back.
printf 'export EDITOR=nano\n' >"$WORK/home-macbook/.zshrc"
assert_ok bier macbook sync
assert_ok bier mini sync
assert_eq "export EDITOR=nano" "$(cat "$WORK/home-mini/.zshrc")" \
	"the change has to arrive on the first Mac"

# The wrong passphrase opens nothing.
BIER_VAULT_PASS=falsch bier mini vault open || true
assert_contains "$OUT" "will not open" "a wrong passphrase has to be refused"

# A dangling link is reported rather than left to be discovered.
rm -f "$WORK/home-mini/.bierfilevault/dot_zshrc"
bier mini status
assert_contains "$OUT" "points nowhere" "a dead link has to be reported"
assert_ok bier mini vault --restore
assert_eq "export EDITOR=nano" "$(cat "$WORK/home-mini/.zshrc")" "restore has to bring it back"

# Taking it back out leaves a real file behind.
assert_ok bier mini vault forget "$WORK/home-mini/.zshrc"
assert_eq "no" "$(is_link "$WORK/home-mini/.zshrc")" "forget has to leave a plain file"
assert_eq "export EDITOR=nano" "$(cat "$WORK/home-mini/.zshrc")" "with its content intact"

# And the note that explains how to get the files back without bier.
assert_file_has "$WORK/mini/Safe/README-recovery.txt" "gpg -d" \
	"the recovery note has to sit next to the data"
