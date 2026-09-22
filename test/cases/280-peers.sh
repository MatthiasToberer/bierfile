#!/usr/bin/env bash
# peers are a local, safe-to-repeat contact list

assert_ok bier mini peer
assert_contains "$OUT" 'bier peer — manage Macs Bier may contact'
for subcommand in discover add list check install upgrade remove; do
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
unset BIER_PEER_DISCOVER_SECONDS

keys=$WORK/agent-signing
mkdir -p "$keys" "$WORK/agent-release"
ssh-keygen -q -t ed25519 -N '' -f "$keys/release"
printf 'bierkasten-releases %s\n' "$(cat "$keys/release.pub")" >"$keys/allowed_signers"
assert_ok bier mini trust "file://$keys/allowed_signers"

assert_ok bier mini peer install studio.local
assert_contains "$OUT" 'Building the signed Bier agent release v0.2.0 on studio.local'
assert_contains "$OUT" 'reachable on TCP port 53991'
assert_file_has "$WORK/scp.args" 'allowed_signers.new'
assert_file_has "$WORK/scp.args" 'com.bierkasten.agent.plist.new'
assert_file_has "$WORK/ssh.args" 'git clone'
assert_file_has "$WORK/ssh.args" 'source.new/agent/build.sh'
assert_file_has "$WORK/curl.args" 'http://studio.local:53991/v1/health'

assert_ok bier mini peer upgrade studio.local
assert_contains "$OUT" 'Updating the Bier agent on studio.local'
assert_contains "$OUT" 'reachable on TCP port 53991'
