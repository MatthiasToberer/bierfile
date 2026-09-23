#!/usr/bin/env bash
# a wrong passphrase stops sync before it encrypts anything
#
# sync seals before it opens. With a wrong passphrase remembered, a Mac
# used to encrypt its own new files with it and commit them, and only
# then complain that the safe would not open. The safe held two
# passphrases from then on, and the other Macs could not open those files.

system mini <<'SYS'
brew "wget"
SYS
system macbook <<'SYS'
brew "wget"
SYS

BIER_VAULT_PASS=richtig
export BIER_VAULT_PASS
printf 'export EDITOR=vim\n' >"$WORK/home-mini/.zshrc"
assert_ok bier mini vault add "$WORK/home-mini/.zshrc"
assert_ok bier mini sync
assert_ok bier macbook sync

# The second Mac remembers the wrong one and takes in a file of its own.
BIER_VAULT_PASS=falsch
printf 'alias ll="ls -l"\n' >"$WORK/home-macbook/.aliases"
assert_ok bier macbook vault add "$WORK/home-macbook/.aliases"
assert_fails bier macbook sync
assert_contains "$OUT" "will not open with the remembered passphrase"
assert_contains "$OUT" "Nothing was encrypted"
assert_contains "$OUT" "bier vault --init"
test ! -e "$WORK/macbook/Safe/dot_aliases.gpg" || fail "nothing may be sealed with the wrong passphrase"

# With the right one it goes through, and the first Mac can open it.
BIER_VAULT_PASS=richtig
assert_ok bier macbook sync
assert_ok bier mini sync
assert_eq 'alias ll="ls -l"' "$(cat "$WORK/home-mini/.aliases")" "the first Mac has to open the new file"
