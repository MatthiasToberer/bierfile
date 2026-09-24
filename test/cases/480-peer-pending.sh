#!/usr/bin/env bash
# A Mac paired with one peer is introduced to the others, and waits there
#
# Like accepting a minion's key in Salt: a sync vouches for each peer to
# the rest, the agent keeps the introduced Mac as pending, and only
# bier peer accept makes it trusted. reject drops it.

system mini <<'SYS'
brew "wget"
SYS
h=$WORK/home-mini
mkdir -p "$h/.barrel/agent/state"
ssh-keygen -q -t ed25519 -N '' -f "$h/.barrel/agent/identity"
ssh-keygen -q -t ed25519 -N '' -f "$WORK/k1"
ssh-keygen -q -t ed25519 -N '' -f "$WORK/k2"
k1=$(awk '{ print $1, $2 }' "$WORK/k1.pub")
k2=$(awk '{ print $1, $2 }' "$WORK/k2.pub")
printf 'one %s\ntwo %s\n' "$k1" "$k2" >"$h/.barrel/agent/peer_signers"

# A peer client that names each Mac after its address and logs what it
# is asked to introduce.
cat >"$WORK/peer-client" <<EOF2
#!/bin/sh
cmd=\$1 host=\$2
case \$cmd in
name) echo "\${host%%.*}" ;;
introduce) while [ "\$1" != --body ]; do shift; done; printf '%s %s\n' "\$host" "\$(cat "\$2")" >>"$WORK/introduced" ;;
esac
EOF2
chmod +x "$WORK/peer-client"
BIER_PEER_CLIENT=$WORK/peer-client
export BIER_PEER_CLIENT
assert_ok bier mini peer add one.ts.net
assert_ok bier mini peer add two.ts.net
assert_ok bier mini sync
assert_contains "$OUT" "Introduced two to one"
assert_contains "$OUT" "Introduced one to two"
assert_file_has "$WORK/introduced" "one.ts.net {\"peer\":\"two\",\"address\":\"two.ts.net\",\"publicKey\":\"$k2\"}"
assert_ok bier mini sync
assert_eq 2 "$(wc -l <"$WORK/introduced" | tr -d ' ')" "each introduction is made once"

# What the agent wrote when a peer introduced two new Macs here.
printf 'new %s one %s\nbad %s one %s\n' new.ts.net "$k1" bad.ts.net "$k2" >"$h/.barrel/agent/state/pending"
assert_ok bier mini peer pending
assert_contains "$OUT" "introduced by one"
assert_ok bier mini state
assert_contains "$OUT" "PENDING	new	one"
assert_fails bier mini brewmaster
assert_contains "$OUT" "new was introduced by one and waits to be trusted."

assert_ok bier mini peer reject bad
assert_ok bier mini peer accept new
assert_contains "$OUT" "it trusts mini now as well"
assert_file_has "$h/.barrel/agent/peer_signers" "new $k1"
assert_ok bier mini peer list
assert_contains "$OUT" "new.ts.net"
assert_ok bier mini peer pending
assert_contains "$OUT" "No Macs are waiting."
assert_fails bier mini peer accept nobody
