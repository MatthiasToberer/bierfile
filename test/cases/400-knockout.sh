#!/usr/bin/env bash
# knockout takes bier off a Mac and signs off at the others
#
# The tidy way out: one last sync, out of Brewfiles/ and the groups,
# every paired Mac told to forget this one, then bier taken off -- while
# the files from the vault stay where they are.

system mini <<'SYS'
brew "wget"
SYS
system macbook <<'SYS'
brew "wget"
SYS
export BIER_VAULT_PASS=probe

printf 'export EDITOR=vim\n' >"$WORK/home-mini/.zshrc-probe"
assert_ok bier mini vault add "$WORK/home-mini/.zshrc-probe"
assert_ok bier mini sync
assert_ok bier macbook sync
assert_ok bier mini vault group laptops mini macbook
assert_ok bier mini sync

# Two paired Macs: one answers, one is away.
cat >"$WORK/peer-client" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$BIER_TEST_PEER_LOG"
case "$1 $2" in
"leave gone.local" | "sync gone.local") exit 1 ;;
esac
printf '%s\n' 'ok'
EOF
chmod +x "$WORK/peer-client"
mkdir -p "$WORK/home-mini/.barrel/agent" "$WORK/home-mini/.barrel/bin" "$WORK/home-mini/.barrel/BierMenu.app"
ssh-keygen -q -t ed25519 -N '' -f "$WORK/home-mini/.barrel/agent/identity"
BIER_PEER_CLIENT=$WORK/peer-client
BIER_TEST_PEER_LOG=$WORK/peer-client.log
export BIER_PEER_CLIENT BIER_TEST_PEER_LOG
assert_ok bier mini peer add macbook.local
assert_ok bier mini peer add gone.local
mkdir -p "$WORK/home-mini/Library/LaunchAgents"
: >"$WORK/home-mini/Library/LaunchAgents/com.bier.agent.plist"
printf 'alias ll="ls -l"\n# added by bier\nexport PATH="%s/.barrel/bin:$PATH"\nexport EDITOR=vim\n' "$WORK/home-mini" \
	>"$WORK/home-mini/.zshrc"
printf 'probe' >"$WORK/keychain"

# A dry run only tells.
assert_ok bier mini knockout --dry-run
assert_contains "$OUT" "sign off at every paired Mac: gone.local, macbook.local"
assert_contains "$OUT" "Nothing has been changed."
[ -d "$WORK/home-mini/.barrel/bin" ] || fail "a dry run must not remove anything"

# No terminal, no knockout.
: >"$WORK/.in"
assert_fails bier mini knockout
assert_contains "$OUT" "no terminal to ask at"

# The wrong word stops it.
BIER_TEST_TTY=1
export BIER_TEST_TTY
answer nope
assert_ok bier mini knockout
assert_contains "$OUT" "Cancelled. Nothing was changed."

# For real; the barrel stays.
answer knockout y n
assert_ok bier mini knockout
assert_contains "$OUT" "== 1. The last sync"
assert_contains "$OUT" "The last sync failed. Go on anyway?"
# Out of the lists and the groups, and the removal went to the peer that
# answers before it was told to forget this Mac.
[ ! -e "$(bf mini mini)" ] || fail "Brewfiles/mini has to be gone"
assert_eq "no" "$(grep -c mini "$WORK/home-mini/.barrel/vault/.groups" >/dev/null && echo yes || echo no)" \
	"mini has to be out of the groups"
assert_eq "sync macbook.local" "$(grep -E '^(sync|leave) macbook.local' "$WORK/peer-client.log" | tail -2 | head -1 | cut -d' ' -f1-2)" \
	"the removal travels before the sign-off"
assert_file_has "$WORK/peer-client.log" "leave macbook.local --port 53991 --local mini"
# The one away is named, with what to do there.
assert_contains "$OUT" "Not reached to sign off: gone.local"
assert_contains "$OUT" "bier peer remove mini"
out=$(cat "$WORK/home-mini/.barrel/peers" 2>/dev/null || true)
assert_eq "gone.local" "$out" "only the peer that signed off is forgotten here"
# Taken off this Mac.
assert_file_has "$WORK/launchctl.args" "bootout"
[ ! -e "$WORK/home-mini/Library/LaunchAgents/com.bier.agent.plist" ] || fail "the LaunchAgent has to go"
assert_file_has "$WORK/pkill.args" "MacOS/BierMenu"
[ ! -e "$WORK/keychain" ] || fail "the passphrase has to leave the keychain"
assert_file_lacks "$WORK/home-mini/.zshrc" "added by bier"
assert_file_lacks "$WORK/home-mini/.zshrc" ".barrel/bin"
assert_file_has "$WORK/home-mini/.zshrc" 'alias ll="ls -l"'
assert_file_has "$WORK/home-mini/.zshrc" 'export EDITOR=vim'
for gone in bin BierMenu.app agent; do
	[ ! -e "$WORK/home-mini/.barrel/$gone" ] || fail "$gone has to be gone"
done
[ -f "$WORK/home-mini/.barrel/config" ] || fail "the config stays when the barrel is kept"
# The files from the vault stay, as plain files.
assert_eq "export EDITOR=vim" "$(cat "$WORK/home-mini/.zshrc-probe")"
assert_eq "no" "$([ -L "$WORK/home-mini/.zshrc-probe" ] && echo yes || echo no)"

# And once more, this time with the barrel.
printf 'probe' >"$WORK/keychain"
answer knockout y y
assert_ok bier mini knockout
assert_contains "$OUT" "bier is gone. Cheers."
[ ! -e "$WORK/home-mini/.barrel" ] || fail "the barrel has to be gone"
assert_eq "export EDITOR=vim" "$(cat "$WORK/home-mini/.zshrc-probe")" "and the files stay"
unset BIER_TEST_TTY BIER_PEER_CLIENT BIER_TEST_PEER_LOG
