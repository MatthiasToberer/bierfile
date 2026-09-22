#!/usr/bin/env bash
# peers are a local, safe-to-repeat contact list

assert_ok bier mini peer
assert_contains "$OUT" 'bier peer — manage Macs Bier may contact'
for subcommand in discover add list check trust install upgrade uninstall remove; do
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
printf 'bierkasten-releases %s\n' "$(cat "$keys/release.pub")" >"$keys/allowed_signers"
BIER_AGENT_TRUST_URL="file://$keys/allowed_signers"
export BIER_AGENT_TRUST_URL

mkdir -p "$WORK/home-mini/.ssh"
printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest bier-test\n' \
	>"$WORK/home-mini/.ssh/id_ed25519.pub"
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

assert_ok bier mini peer install studio.local
assert_contains "$OUT" '3/4  Installing verified Bier agent v0.2.0'
assert_contains "$OUT" '4/4  Checking whether the agent is reachable'
assert_contains "$OUT" 'Done. mini is ready on studio.local.'
assert_file_has "$WORK/scp.args" 'allowed_signers.new'
assert_file_has "$WORK/scp.args" 'com.bierkasten.agent.plist.new'
assert_file_has "$WORK/ssh.args" 'fetch --quiet --depth 1 origin'
assert_file_has "$WORK/ssh.args" 'source.new/agent/build.sh'
assert_file_has "$WORK/curl.args" 'http://studio.local:53991/v1/health'
assert_ok bier mini peer list
assert_contains "$OUT" 'first.local'
assert_contains "$OUT" 'studio.local'
unset BIER_AGENT_TRUST_URL

assert_ok bier mini peer upgrade studio.local
assert_contains "$OUT" 'Updating the Bier agent on studio.local'
assert_contains "$OUT" 'Done. mini is ready on studio.local.'

mkdir -p "$WORK/home-mini/.ssh"
printf 'studio.local %s\n' "$(cat "$keys/release.pub")" >"$WORK/home-mini/.ssh/known_hosts"
assert_ok ssh-keygen -F studio.local -f "$WORK/home-mini/.ssh/known_hosts"
answer n
assert_ok bier mini peer uninstall studio.local
assert_contains "$OUT" 'This permanently removes Bierkasten from studio.local:'
assert_contains "$OUT" 'Cancelled.'
assert_ok bier mini peer list
assert_contains "$OUT" 'studio.local'

answer y
assert_ok bier mini peer uninstall studio.local
assert_contains "$OUT" '1/3  Checking SSH access to studio.local'
assert_contains "$OUT" '2/3  Removing the Bier agent and SSH access'
assert_contains "$OUT" '3/3  Removing local Bierkasten connection details'
assert_contains "$OUT" 'Done. Bier agent removed from studio.local.'
assert_file_has "$WORK/ssh.args" 'launchctl bootout'
assert_file_has "$WORK/ssh.args" '.local/share/bierkasten'
assert_file_has "$WORK/ssh.args" 'ssh-key-installed'
assert_file_has "$WORK/ssh.args" 'authorized_keys.bierkasten'
assert_file_has "$WORK/scp.args" 'uninstall-key.new'
assert_fails ssh-keygen -F studio.local -f "$WORK/home-mini/.ssh/known_hosts"
assert_ok bier mini peer list
assert_not_contains "$OUT" 'studio.local'
assert_fails bier mini peer uninstall --bad
assert_contains "$OUT" 'usage: bier peer uninstall <host>'
