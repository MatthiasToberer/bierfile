#!/usr/bin/env bash
# brewmaster looks the Mac over and says how to fix what it finds
#
# Like brew doctor: nothing is changed, every finding comes with the
# command that puts it right, and it exits 1 when it found something.
# The findings are the ones hit in practice: an agent that is not
# running, a peer out of reach, changes not committed, a path shared
# twice, a conflict copy left lying, noise shared as settings.

system mini <<'SYS'
brew "wget"
SYS
export BIER_VAULT_PASS=probe
h=$WORK/home-mini
mkdir -p "$h/Library/LaunchAgents" "$h/.barrel/agent" "$h/.barrel/bin"
: >"$h/Library/LaunchAgents/com.bier.agent.plist"
ssh-keygen -q -t ed25519 -N '' -f "$h/.barrel/agent/identity"
PATH=$h/.barrel/bin:$PATH
export PATH
assert_ok bier mini dump
assert_ok bier mini sync

# All in order.
assert_ok bier mini brewmaster
assert_contains "$OUT" "Your bier is ready to pour."

# Now some trouble.
cat >"$WORK/peer-client" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$WORK/peer-client"
BIER_PEER_CLIENT=$WORK/peer-client
export BIER_PEER_CLIENT
assert_ok bier mini peer add away.local
printf 'brew "extra"\n' >>"$(bf mini main)"
app="Library/Application Support/TestApp"
mkdir -p "$h/$app"
printf 'q\n' >"$h/$app/Queue.hbqueue"
printf 'a=1\n' >"$h/$app/settings.ini"
printf 'b=2\n' >"$h/$app/settings.ini.from-safe"
assert_ok bier mini vault add --app TestApp "$h/$app"
# A second entry for the same folder, as an older bier allowed.
mkdir -p "$h/.barrel/vault/@mini/apps/TestApp/Application Support"
printf 'Application Support\t%s\n' "$app" >"$h/.barrel/vault/@mini/apps/TestApp/.bier-map"
: >"$h/.barrel/vault/@mini/apps/TestApp/Application Support/.bier-folder"
assert_ok bier mini vault seal

assert_fails bier mini brewmaster
assert_contains "$OUT" "Warning: away.local does not answer."
assert_contains "$OUT" "Brewfiles or the safe have changes not committed."
assert_contains "$OUT" "$h/$app is shared twice"
assert_contains "$OUT" "settings.ini.from-safe is left from a conflict."
assert_contains "$OUT" "files ending in .hbqueue are shared"
assert_contains "$OUT" "vault_exclude = *.hbqueue"
assert_contains "$OUT" "apart from 5 thing(s) above."

# It changed nothing.
assert_file_has "$(bf mini main)" 'brew "extra"'
[ -f "$h/$app/settings.ini.from-safe" ] || fail "brewmaster must not tidy anything up"
