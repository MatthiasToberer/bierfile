#!/usr/bin/env bash
# peers are a local, safe-to-repeat contact list

assert_ok bier mini peer
assert_contains "$OUT" 'bier peer — manage Macs Bier may contact'
for subcommand in discover add list check hello offer pair compare sync seed trust install upgrade uninstall remove; do
	assert_contains "$OUT" "bier peer $subcommand"
done

assert_ok bier mini peer list
assert_contains "$OUT" 'No peers known'

assert_ok bier mini peer add macbook.local
assert_contains "$OUT" 'Peer added: macbook.local'
assert_ok bier mini peer add admin@192.168.1.42
assert_ok bier mini peer add macbook.local
assert_contains "$OUT" 'already known'

assert_ok bier mini peer list
assert_contains "$OUT" 'macbook.local'
assert_contains "$OUT" 'admin@192.168.1.42'

assert_ok bier mini peer remove macbook.local
assert_contains "$OUT" 'Peer removed: macbook.local'
assert_fails bier mini peer remove macbook.local
assert_contains "$OUT" 'no peer called macbook.local'
assert_fails bier mini peer add --bad
assert_contains "$OUT" 'usage: bier peer add <host>'

assert_ok bier mini peer check admin@192.168.1.42
assert_contains "$OUT" 'SSH to admin@192.168.1.42 works.'
assert_file_has "$WORK/ssh.args" 'BatchMode=yes'
assert_file_has "$WORK/ssh.args" 'ConnectTimeout=5'
assert_file_has "$WORK/ssh.args" 'StrictHostKeyChecking=yes'
assert_file_has "$WORK/ssh.args" 'admin@192.168.1.42'

BIER_TEST_SSH=fail
export BIER_TEST_SSH
assert_fails bier mini peer check unreachable.local
assert_contains "$OUT" 'cannot reach unreachable.local over SSH'
unset BIER_TEST_SSH

BIER_PEER_DISCOVER_SECONDS=1
export BIER_PEER_DISCOVER_SECONDS
assert_ok bier mini peer discover
assert_contains "$OUT" 'Bier agents found on the local network:'
assert_contains "$OUT" 'macbook.local'
assert_contains "$OUT" 'To remember one: bier peer add <host>'
assert_file_has "$WORK/dns-sd.args" '-B _bier-agent._tcp local.'
assert_ok bier mini peer list
assert_not_contains "$OUT" 'macbook.local'

assert_ok bier mini peer discover -ssh
assert_contains "$OUT" 'Macs with Remote Login found on the local network:'
assert_contains "$OUT" 'macbook.local'
assert_not_contains "$OUT" 'mini.local'
assert_contains "$OUT" 'bier peer install <user>@<host>'
assert_file_has "$WORK/dns-sd.args" '-B _ssh._tcp local.'
assert_fails bier mini peer discover -ssh unexpected
assert_contains "$OUT" 'usage: bier peer discover [-ssh]'
unset BIER_PEER_DISCOVER_SECONDS

keys=$WORK/agent-signing
mkdir -p "$keys" "$WORK/agent-release"
ssh-keygen -q -t ed25519 -N '' -f "$keys/release"
printf 'bier-releases %s\n' "$(cat "$keys/release.pub")" >"$keys/allowed_signers"
BIER_RELEASE_TRUST_URL="file://$keys/allowed_signers"
export BIER_RELEASE_TRUST_URL

mkdir -p "$WORK/home-mini/.ssh"
ssh-keygen -q -t ed25519 -N '' -f "$WORK/home-mini/.ssh/id_ed25519"
mkdir -p "$WORK/home-mini/.barrel/agent/bin"
ssh-keygen -q -t ed25519 -N '' -f "$WORK/home-mini/.barrel/agent/identity"
: >"$WORK/home-mini/.barrel/agent/bin/bier-agent"
chmod +x "$WORK/home-mini/.barrel/agent/bin/bier-agent"
assert_ok bier mini peer offer
assert_contains "$OUT" 'Pairing is open for 10 minutes.'
assert_contains "$OUT" 'One-time code:'
test -f "$WORK/home-mini/.barrel/agent/state/pairing-offer.json"
cat >"$WORK/peer-client" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$BIER_TEST_PEER_LOG"
printf '%s\n' 'Bier data is in sync.'
EOF
chmod +x "$WORK/peer-client"
BIER_PEER_CLIENT=$WORK/peer-client
BIER_TEST_PEER_LOG=$WORK/peer-client.log
export BIER_PEER_CLIENT BIER_TEST_PEER_LOG
# Both addresses must be supplied unchanged, without modifying peer identity.
assert_ok bier mini peer offer --address macbook.example.ts.net
assert_contains "$OUT" 'bier peer pair macbook.example.ts.net'
assert_fails bier mini peer offer --address 'bad/name'
assert_fails bier mini peer offer --address $'mini\nother'
assert_fails bier mini peer offer --address ''
assert_fails bier mini peer pair macbook --address
assert_fails bier mini peer pair macbook --address 'user@mini'
BIER_PAIR_CODE=0123456789abcdef0123456789abcdef
export BIER_PAIR_CODE
assert_ok bier mini peer pair macbook.example.ts.net --address mini.example.ts.net
assert_file_has "$WORK/peer-client.log" 'pair macbook.example.ts.net --address mini.example.ts.net --local mini'
assert_ok bier mini peer remove macbook.example.ts.net
assert_ok bier mini peer pair 100.64.0.2 --address 100.64.0.1
assert_file_has "$WORK/peer-client.log" 'pair 100.64.0.2 --address 100.64.0.1 --local mini'
assert_ok bier mini peer remove 100.64.0.2
assert_ok bier mini peer pair macbook.local
assert_file_has "$WORK/peer-client.log" 'pair macbook.local --local mini'
assert_ok bier mini peer remove macbook.local
unset BIER_PAIR_CODE
system mini <<'EOF'
brew "wget"
EOF
assert_ok bier mini sync
assert_contains "$OUT" 'In sync with Bier peers.'
assert_file_has "$WORK/peer-client.log" 'sync admin@192.168.1.42'
assert_eq "$(grep -c '^sync admin@192.168.1.42 ' "$WORK/peer-client.log")" 2 \
	"bier sync has to collect and then distribute peer history"
unset BIER_PEER_CLIENT BIER_TEST_PEER_LOG
rm -f "$(bf mini mini)"
git -C "$WORK/mini" add -A
git -C "$WORK/mini" commit -qm 'clean up peer sync test'
BIER_TEST_SSH=bootstrap
export BIER_TEST_SSH
assert_ok bier mini peer install first.local
assert_contains "$OUT" '1/4  Connecting to first.local'
assert_contains "$OUT" 'First connection: verify the host fingerprint'
assert_contains "$OUT" '2/4  Setting up secure release verification'
assert_contains "$OUT" 'Done. mini is ready on first.local.'
assert_file_has "$WORK/ssh.args" 'BatchMode=no'
assert_file_has "$WORK/ssh.args" 'StrictHostKeyChecking=ask'
assert_file_has "$WORK/ssh.args" 'authorized_keys'
unset BIER_TEST_SSH

BIER_TEST_SSH_DATA=/Users/bier/configured-data
export BIER_TEST_SSH_DATA
assert_ok bier mini peer install studio.local
assert_contains "$OUT" '3/4  Installing verified Bier agent v0.35.0'
assert_contains "$OUT" '4/4  Checking whether the agent is reachable'
assert_contains "$OUT" 'Checking the Bier data store on studio.local'
assert_contains "$OUT" 'studio.local now has the Bier data from mini.'
assert_contains "$OUT" 'Done. mini is ready on studio.local.'
assert_file_has "$WORK/scp.args" 'allowed_signers.new'
assert_file_has "$WORK/scp.args" 'com.bier.agent.plist.new'
assert_file_has "$WORK/ssh.args" 'fetch --quiet --depth 1 origin'
assert_file_has "$WORK/ssh.args" 'source.new/Sources/bier-agent/build.sh'
assert_file_has "$WORK/ssh.args" 'bier-agent-data-directory'
assert_file_has "$WORK/agent.plist" '<string>--data-dir</string><string>/Users/bier/configured-data</string>'
assert_file_has "$WORK/agent.plist" '<string>--peer-key</string><string>/Users/bier/.barrel/agent/identity.pub</string>'
assert_file_has "$WORK/ssh.args" 'peer_signers'
assert_file_has "$WORK/curl.args" 'http://studio.local:53991/v1/health'
assert_ok bier mini peer list
assert_contains "$OUT" 'first.local'
assert_contains "$OUT" 'studio.local'
unset BIER_TEST_SSH_DATA
unset BIER_RELEASE_TRUST_URL

assert_ok bier mini peer hello studio.local
assert_contains "$OUT" 'Bier Agent on studio.local accepted mini as a peer.'
assert_file_has "$WORK/curl.args" 'http://studio.local:53991/v1/peer/hello'
assert_file_has "$WORK/curl.args" 'X-Bier-Peer: mini'

printf 'brew "wget"\n' >"$(bf mini main)"
assert_ok bier mini peer seed studio.local
assert_contains "$OUT" '1/3  Checking the Bier data store on studio.local'
assert_contains "$OUT" '2/3  Preparing the local Bier data snapshot'
assert_contains "$OUT" '3/3  Sending the verified snapshot to studio.local'
assert_contains "$OUT" 'Done. studio.local now has the Bier data from mini.'
assert_file_has "$WORK/curl.args" '/v1/peer/manifest'
assert_file_has "$WORK/curl.args" '/v1/peer/snapshot/begin'
assert_file_has "$WORK/curl.args" '/v1/peer/snapshot/put'
assert_file_has "$WORK/curl.args" '/v1/peer/snapshot/commit'

BIER_TEST_PEER_HASH=$(shasum -a 256 "$(bf mini main)" | awk '{print $1}')
export BIER_TEST_PEER_HASH
assert_ok bier mini peer compare studio.local
assert_contains "$OUT" 'Data differs:'
assert_contains "$OUT" '.gitattributes'
assert_contains "$OUT" '1 data file(s) differ. Nothing was changed.'
assert_file_has "$WORK/curl.args" '/v1/peer/data/read'
unset BIER_TEST_PEER_HASH

assert_ok bier mini peer upgrade studio.local
assert_contains "$OUT" 'Updating the Bier agent on studio.local'
assert_contains "$OUT" 'Done. mini is ready on studio.local.'

mkdir -p "$WORK/home-mini/.ssh"
printf 'studio.local %s\n' "$(cat "$keys/release.pub")" >"$WORK/home-mini/.ssh/known_hosts"
assert_ok ssh-keygen -F studio.local -f "$WORK/home-mini/.ssh/known_hosts"
answer n
assert_ok bier mini peer uninstall studio.local
assert_contains "$OUT" 'This permanently removes Bier from studio.local:'
assert_contains "$OUT" 'Cancelled.'
assert_ok bier mini peer list
assert_contains "$OUT" 'studio.local'

answer y
assert_ok bier mini peer uninstall studio.local
assert_contains "$OUT" '1/3  Checking SSH access to studio.local'
assert_contains "$OUT" '2/3  Removing the Bier agent and SSH access'
assert_contains "$OUT" '3/3  Removing local Bier connection details'
assert_contains "$OUT" 'Done. Bier agent removed from studio.local.'
assert_file_has "$WORK/ssh.args" 'launchctl bootout'
assert_file_has "$WORK/ssh.args" '.barrel/agent'
assert_file_has "$WORK/ssh.args" 'ssh-key-installed'
assert_file_has "$WORK/ssh.args" 'authorized_keys.bier'
assert_file_has "$WORK/scp.args" 'uninstall-key.new'
assert_fails ssh-keygen -F studio.local -f "$WORK/home-mini/.ssh/known_hosts"
assert_ok bier mini peer list
assert_not_contains "$OUT" 'studio.local'
assert_fails bier mini peer uninstall --bad
assert_contains "$OUT" 'usage: bier peer uninstall <host>'
