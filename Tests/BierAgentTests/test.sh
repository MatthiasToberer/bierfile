#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
work=$(mktemp -d /private/tmp/bier-agent-swift.XXXXXX)
pid=
cleanup() {
	[ -z "$pid" ] || kill "$pid" 2>/dev/null || true
	[ -z "$pid" ] || wait "$pid" 2>/dev/null || true
	rm -rf "$work"
}
trap cleanup EXIT

agent="$work/bier-agent"
"$root/Sources/bier-agent/build.sh" "$agent" >/dev/null
swift build --package-path "$root" --product bier-peer >/dev/null
peer_cli=$(swift build --package-path "$root" --show-bin-path)/bier-peer
swiftc -O -framework Foundation -framework CryptoKit -o "$work/snapshot-test" "$root/Sources/bier-core/swift/DataManifest.swift" "$root/Sources/bier-core/swift/DataSnapshot.swift" "$here/SnapshotTest.swift"
"$work/snapshot-test"
swiftc -O -framework Foundation -framework CryptoKit -o "$work/git-repository-test" "$root/Sources/bier-core/swift/DataManifest.swift" "$root/Sources/bier-core/swift/DataSnapshot.swift" "$root/Sources/bier-core/swift/GitRepository.swift" "$root/Sources/bier-core/swift/GitBundleStore.swift" "$here/GitRepositoryTest.swift"
"$work/git-repository-test"
ssh-keygen -q -t ed25519 -N '' -f "$work/pair-local"
ssh-keygen -q -t ed25519 -N '' -f "$work/pair-remote"
swiftc -O -framework Foundation -framework CryptoKit -o "$work/pairing-test" "$root/Sources/bier-core/swift/PeerPairing.swift" "$here/PairingTest.swift"
"$work/pairing-test" "$work/pair-local.pub" "$work/pair-remote.pub"
ssh-keygen -q -t ed25519 -N '' -f "$work/controller"
printf 'controller-test %s\n' "$(cat "$work/controller.pub")" >"$work/allowed_signers"
printf 'mini %s\n' "$(cat "$work/controller.pub")" >"$work/peer_signers"
mkdir -p "$work/data/Brewfiles" "$work/data/Safe"
printf 'brew "wget"\n' >"$work/data/Brewfiles/main"
printf 'encrypted\n' >"$work/data/Safe/test.gpg"
git -C "$work/data" init -q --initial-branch=main
git -C "$work/data" config user.email test@example.com
git -C "$work/data" config user.name Test
git -C "$work/data" add Brewfiles Safe
git -C "$work/data" commit -qm 'initial data'
printf '%s\n' '{"version":1,"id":"probe-1","target":"mini","type":"agent.probe","expires_at":"2099-01-01T00:00:00Z","issuer":"controller-test","payload":{}}' >"$work/recipe.json"
ssh-keygen -q -Y sign -f "$work/controller" -n bier-recipe "$work/recipe.json"

"$agent" serve --agent mini --allowed-signers "$work/allowed_signers" --peer-signers "$work/peer_signers" --peer-key "$work/controller.pub" --peers-file "$work/peers" --data-dir "$work/data" --state-dir "$work/state" --port 53992 --bonjour false >"$work/agent.log" 2>&1 &
pid=$!
for attempt in 1 2 3 4 5; do
	if curl -fsS --max-time 1 http://127.0.0.1:53992/v1/health 2>/dev/null | grep -q '"status":"ok"'; then break; fi
	sleep 1
done
curl -fsS --max-time 1 http://127.0.0.1:53992/v1/health | grep -q '"status":"ok"'
peer_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
peer_nonce=agent-test-0123456789
empty_hash=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
printf 'GET\n/v1/peer/hello\nmini\n%s\n%s\n%s\n' "$peer_time" "$peer_nonce" "$empty_hash" >"$work/peer-request"
ssh-keygen -q -Y sign -f "$work/controller" -n bier-peer "$work/peer-request"
peer_signature=$(base64 <"$work/peer-request.sig" | tr -d '\n')
status=$(curl -sS --max-time 2 -o "$work/response" -w '%{http_code}' \
	-H "X-Bier-Peer: mini" -H "X-Bier-Time: $peer_time" -H "X-Bier-Nonce: $peer_nonce" \
	-H "X-Bier-Signature: $peer_signature" http://127.0.0.1:53992/v1/peer/hello)
[ "$status" = 200 ]
grep -q '"status":"peer-ok"' "$work/response"
status=$(curl -sS --max-time 2 -o "$work/response" -w '%{http_code}' \
	-H "X-Bier-Peer: mini" -H "X-Bier-Time: $peer_time" -H "X-Bier-Nonce: $peer_nonce" \
	-H "X-Bier-Signature: $peer_signature" http://127.0.0.1:53992/v1/peer/hello)
[ "$status" = 409 ]
peer_nonce=agent-manifest-0123456789
printf 'GET\n/v1/peer/manifest\nmini\n%s\n%s\n%s\n' "$peer_time" "$peer_nonce" "$empty_hash" >"$work/peer-request"
rm -f "$work/peer-request.sig"
ssh-keygen -q -Y sign -f "$work/controller" -n bier-peer "$work/peer-request"
peer_signature=$(base64 <"$work/peer-request.sig" | tr -d '\n')
status=$(curl -sS --max-time 2 -o "$work/response" -w '%{http_code}' \
	-H "X-Bier-Peer: mini" -H "X-Bier-Time: $peer_time" -H "X-Bier-Nonce: $peer_nonce" \
	-H "X-Bier-Signature: $peer_signature" http://127.0.0.1:53992/v1/peer/manifest)
[ "$status" = 200 ]
grep -q 'Brewfiles/main' "$work/response" || { cat "$work/response" >&2; exit 1; }
grep -q 'Safe/test.gpg' "$work/response" || { cat "$work/response" >&2; exit 1; }
manifest_hash=$(shasum -a 256 "$work/data/Brewfiles/main" | awk '{print $1}')
grep -q "$manifest_hash" "$work/response" || { cat "$work/response" >&2; exit 1; }
peer_nonce=agent-data-read-0123456789
printf '{"path":"Brewfiles/main","offset":0,"length":32768}' >"$work/data-read.json"
snapshot_hash=$(shasum -a 256 "$work/data-read.json" | awk '{print $1}')
printf 'POST\n/v1/peer/data/read\nmini\n%s\n%s\n%s\n' "$peer_time" "$peer_nonce" "$snapshot_hash" >"$work/peer-request"
rm -f "$work/peer-request.sig"
ssh-keygen -q -Y sign -f "$work/controller" -n bier-peer "$work/peer-request"
peer_signature=$(base64 <"$work/peer-request.sig" | tr -d '\n')
status=$(curl -sS --max-time 2 -o "$work/received-data" -w '%{http_code}' \
	-H 'Content-Type: application/json' -H "X-Bier-Peer: mini" -H "X-Bier-Time: $peer_time" -H "X-Bier-Nonce: $peer_nonce" \
	-H "X-Bier-Signature: $peer_signature" --data-binary @"$work/data-read.json" http://127.0.0.1:53992/v1/peer/data/read)
[ "$status" = 200 ]
cmp "$work/data/Brewfiles/main" "$work/received-data"
peer_nonce=agent-repository-export-0123456789
printf 'POST\n/v1/peer/repository/export\nmini\n%s\n%s\n%s\n' "$peer_time" "$peer_nonce" "$empty_hash" >"$work/peer-request"
rm -f "$work/peer-request.sig"
ssh-keygen -q -Y sign -f "$work/controller" -n bier-peer "$work/peer-request"
peer_signature=$(base64 <"$work/peer-request.sig" | tr -d '\n')
status=$(curl -sS --max-time 2 -o "$work/repository-export.json" -w '%{http_code}' -X POST \
	-H "X-Bier-Peer: mini" -H "X-Bier-Time: $peer_time" -H "X-Bier-Nonce: $peer_nonce" \
	-H "X-Bier-Signature: $peer_signature" http://127.0.0.1:53992/v1/peer/repository/export)
[ "$status" = 200 ]
bundle_id=$(/usr/bin/plutil -extract id raw -o - "$work/repository-export.json")
bundle_bytes=$(/usr/bin/plutil -extract bytes raw -o - "$work/repository-export.json")
[ "$bundle_bytes" -gt 0 ]
peer_nonce=agent-repository-read-0123456789
printf '{"id":"%s","offset":0,"length":64}' "$bundle_id" >"$work/repository-read.json"
bundle_hash=$(shasum -a 256 "$work/repository-read.json" | awk '{print $1}')
printf 'POST\n/v1/peer/repository/export/read\nmini\n%s\n%s\n%s\n' "$peer_time" "$peer_nonce" "$bundle_hash" >"$work/peer-request"
rm -f "$work/peer-request.sig"
ssh-keygen -q -Y sign -f "$work/controller" -n bier-peer "$work/peer-request"
peer_signature=$(base64 <"$work/peer-request.sig" | tr -d '\n')
status=$(curl -sS --max-time 2 -o "$work/repository-chunk" -w '%{http_code}' \
	-H 'Content-Type: application/json' -H "X-Bier-Peer: mini" -H "X-Bier-Time: $peer_time" -H "X-Bier-Nonce: $peer_nonce" \
	-H "X-Bier-Signature: $peer_signature" --data-binary @"$work/repository-read.json" http://127.0.0.1:53992/v1/peer/repository/export/read)
[ "$status" = 200 ]
grep -aq '^# v2 git bundle' "$work/repository-chunk"
peer_nonce=agent-snapshot-begin-0123456789
snapshot_id=snapshot-begin-0123456789
printf 'brew "tree"\n' >"$work/received"
received_bytes=$(wc -c <"$work/received" | tr -d ' ')
received_hash=$(shasum -a 256 "$work/received" | awk '{print $1}')
printf '{"id":"%s","manifest":{"version":1,"entries":[{"path":"Brewfiles/received","bytes":%s,"sha256":"%s"}]}}' "$snapshot_id" "$received_bytes" "$received_hash" >"$work/snapshot-begin.json"
snapshot_hash=$(shasum -a 256 "$work/snapshot-begin.json" | awk '{print $1}')
printf 'POST\n/v1/peer/snapshot/begin\nmini\n%s\n%s\n%s\n' "$peer_time" "$peer_nonce" "$snapshot_hash" >"$work/peer-request"
rm -f "$work/peer-request.sig"
ssh-keygen -q -Y sign -f "$work/controller" -n bier-peer "$work/peer-request"
peer_signature=$(base64 <"$work/peer-request.sig" | tr -d '\n')
status=$(curl -sS --max-time 2 -o "$work/response" -w '%{http_code}' \
	-H 'Content-Type: application/json' -H "X-Bier-Peer: mini" -H "X-Bier-Time: $peer_time" -H "X-Bier-Nonce: $peer_nonce" \
	-H "X-Bier-Signature: $peer_signature" --data-binary @"$work/snapshot-begin.json" http://127.0.0.1:53992/v1/peer/snapshot/begin)
[ "$status" = 200 ]
grep -q '"status":"snapshot-ready"' "$work/response"
test -d "$work/.bier-staging/$snapshot_id"
peer_nonce=agent-snapshot-put-0123456789
received_data=$(base64 <"$work/received" | tr -d '\n')
printf '{"id":"%s","path":"Brewfiles/received","offset":0,"data":"%s"}' "$snapshot_id" "$received_data" >"$work/snapshot-put.json"
snapshot_hash=$(shasum -a 256 "$work/snapshot-put.json" | awk '{print $1}')
printf 'POST\n/v1/peer/snapshot/put\nmini\n%s\n%s\n%s\n' "$peer_time" "$peer_nonce" "$snapshot_hash" >"$work/peer-request"
rm -f "$work/peer-request.sig"
ssh-keygen -q -Y sign -f "$work/controller" -n bier-peer "$work/peer-request"
peer_signature=$(base64 <"$work/peer-request.sig" | tr -d '\n')
status=$(curl -sS --max-time 2 -o "$work/response" -w '%{http_code}' \
	-H 'Content-Type: application/json' -H "X-Bier-Peer: mini" -H "X-Bier-Time: $peer_time" -H "X-Bier-Nonce: $peer_nonce" \
	-H "X-Bier-Signature: $peer_signature" --data-binary @"$work/snapshot-put.json" http://127.0.0.1:53992/v1/peer/snapshot/put)
[ "$status" = 200 ]
grep -q '"status":"snapshot-staged"' "$work/response"
test "$(cat "$work/.bier-staging/$snapshot_id/Brewfiles/received")" = 'brew "tree"'
peer_nonce=agent-snapshot-commit-0123456789
printf '{"id":"%s"}' "$snapshot_id" >"$work/snapshot-commit.json"
snapshot_hash=$(shasum -a 256 "$work/snapshot-commit.json" | awk '{print $1}')
printf 'POST\n/v1/peer/snapshot/commit\nmini\n%s\n%s\n%s\n' "$peer_time" "$peer_nonce" "$snapshot_hash" >"$work/peer-request"
rm -f "$work/peer-request.sig"
ssh-keygen -q -Y sign -f "$work/controller" -n bier-peer "$work/peer-request"
peer_signature=$(base64 <"$work/peer-request.sig" | tr -d '\n')
status=$(curl -sS --max-time 2 -o "$work/response" -w '%{http_code}' \
	-H 'Content-Type: application/json' -H "X-Bier-Peer: mini" -H "X-Bier-Time: $peer_time" -H "X-Bier-Nonce: $peer_nonce" \
	-H "X-Bier-Signature: $peer_signature" --data-binary @"$work/snapshot-commit.json" http://127.0.0.1:53992/v1/peer/snapshot/commit)
[ "$status" = 200 ]
grep -q '"status":"snapshot-committed"' "$work/response"
test "$(cat "$work/data/Brewfiles/received")" = 'brew "tree"'
test ! -e "$work/data/Brewfiles/main"
test ! -e "$work/.bier-staging/$snapshot_id"
recipe=$(base64 <"$work/recipe.json" | tr -d '\n')
signature=$(base64 <"$work/recipe.json.sig" | tr -d '\n')
body=$(printf '{"recipe":"%s","signature":"%s"}' "$recipe" "$signature")
status=$(curl -sS --max-time 2 -o "$work/response" -w '%{http_code}' -H 'Content-Type: application/json' --data "$body" http://127.0.0.1:53992/v1/probe)
[ "$status" = 200 ]
grep -q '"status":"accepted"' "$work/response"
status=$(curl -sS --max-time 2 -o "$work/response" -w '%{http_code}' -H 'Content-Type: application/json' --data "$body" http://127.0.0.1:53992/v1/probe)
[ "$status" = 409 ]

kill "$pid"
wait "$pid" 2>/dev/null || true
pid=
mkdir -p "$work/source/Brewfiles" "$work/home/.ssh"
printf 'brew "jq"\n' >"$work/source/Brewfiles/main"
git init -q "$work/source"
git -C "$work/source" config user.email test@example.com
git -C "$work/source" config user.name Test
git -C "$work/source" add Brewfiles
git -C "$work/source" commit -qm 'initial data'
cp "$work/controller" "$work/home/.ssh/id_ed25519"
cp "$work/controller.pub" "$work/home/.ssh/id_ed25519.pub"
chmod 600 "$work/home/.ssh/id_ed25519"
"$agent" serve --agent target --allowed-signers "$work/allowed_signers" --peer-signers "$work/peer_signers" --peer-key "$work/controller.pub" --peers-file "$work/remote-peers" --data-dir "$work/target" --state-dir "$work/state-client" --port 53992 --bonjour false >"$work/agent-client.log" 2>&1 &
pid=$!
for attempt in 1 2 3 4 5; do
	if curl -fsS --max-time 1 http://127.0.0.1:53992/v1/health 2>/dev/null | grep -q '"status":"ok"'; then break; fi
	sleep 1
done
pair_code=0123456789abcdef0123456789abcdef
pair_expiry=$(date -v+10M +%s)
printf '{"version":1,"code":"%s","expires":%s,"attempts":0}\n' "$pair_code" "$pair_expiry" >"$work/state-client/pairing-offer.json"
BIER_ROOT="$root" BIER_DATA="$work/source" BIER_HOST=mini BIER_PEER_PORT=53992 BIER_PEER_CLIENT="$peer_cli" BIER_PEER_IDENTITY="$work/home/.ssh/id_ed25519" BIER_PAIR_CODE="$pair_code" HOME="$work/home" \
	"$root/Sources/bier-core/bier" peer pair 127.0.0.1 >"$work/pair.log"
grep -q 'Paired mini with target on 127.0.0.1.' "$work/pair.log"
grep -q 'Done. 127.0.0.1 now has the Bier data from mini.' "$work/pair.log"
grep -q '^mini ssh-ed25519 ' "$work/peer_signers"
grep -qx 'mini.local' "$work/remote-peers"
grep -q '^target ssh-ed25519 ' "$work/home/.local/share/bier/agent/peer_signers"
grep -qx '127.0.0.1' "$work/home/.config/bier/peers"
for advertised in mini.example.ts.net 100.64.0.1; do
	printf '{"version":1,"code":"%s","expires":%s,"attempts":0}\n' "$pair_code" "$pair_expiry" >"$work/state-client/pairing-offer.json"
	BIER_ROOT="$root" BIER_DATA="$work/source" BIER_HOST=mini BIER_PEER_PORT=53992 BIER_PEER_CLIENT="$peer_cli" BIER_PEER_IDENTITY="$work/home/.ssh/id_ed25519" BIER_PAIR_CODE="$pair_code" HOME="$work/home" \
		"$root/Sources/bier-core/bier" peer pair 127.0.0.1 --address "$advertised" >"$work/pair-address.log"
	grep -qx "$advertised" "$work/remote-peers"
done
test ! -e "$work/state-client/pairing-offer.json"
test "$(cat "$work/target/Brewfiles/main")" = 'brew "jq"'
test -d "$work/target/.git"
test "$(git -C "$work/target" log -1 --format=%s)" = 'initial data'
"$peer_cli" hello 127.0.0.1 --local mini --identity "$work/home/.ssh/id_ed25519" --port 53992 >"$work/hello-swift.log"
grep -q 'Bier Agent on 127.0.0.1 accepted mini as a peer.' "$work/hello-swift.log"
printf 'brew "tree"\n' >"$work/source/Brewfiles/main"
"$peer_cli" seed-if-empty 127.0.0.1 --local mini --identity "$work/home/.ssh/id_ed25519" --data "$work/source" --port 53992 >"$work/client-existing.log"
grep -q 'Existing peer data was kept unchanged.' "$work/client-existing.log"
test "$(cat "$work/target/Brewfiles/main")" = 'brew "jq"'
printf 'brew "jq"\n' >"$work/source/Brewfiles/main"
"$peer_cli" compare 127.0.0.1 --local mini --identity "$work/home/.ssh/id_ed25519" --data "$work/source" --port 53992 >"$work/compare-swift.log"
grep -q 'Bier data is identical on mini and 127.0.0.1.' "$work/compare-swift.log"
printf 'brew "wget"\n' >>"$work/target/Brewfiles/main"
git -C "$work/target" add Brewfiles
git -C "$work/target" commit -qm 'target changed'
"$peer_cli" sync 127.0.0.1 --local mini --identity "$work/home/.ssh/id_ed25519" --data "$work/source" --port 53992 >"$work/sync-swift.log"
grep -q 'Bier data is in sync on mini and 127.0.0.1.' "$work/sync-swift.log"
test "$(git -C "$work/source" rev-parse HEAD)" = "$(git -C "$work/target" rev-parse HEAD)"
test "$(cat "$work/source/Brewfiles/main")" = "$(cat "$work/target/Brewfiles/main")"
printf 'brew "tree"\n' >>"$work/source/Brewfiles/main"
git -C "$work/source" add Brewfiles
git -C "$work/source" commit -qm 'source changed'
BIER_ROOT="$root" BIER_DATA="$work/source" BIER_HOST=mini BIER_PEER_PORT=53992 BIER_PEER_CLIENT="$peer_cli" BIER_PEER_IDENTITY="$work/home/.ssh/id_ed25519" HOME="$work/home" \
	"$root/Sources/bier-core/bier" peer sync 127.0.0.1 >"$work/sync.log"
grep -q 'Bier data is in sync on mini and 127.0.0.1.' "$work/sync.log"
test "$(git -C "$work/source" rev-parse HEAD)" = "$(git -C "$work/target" rev-parse HEAD)"
BIER_ROOT="$root" BIER_DATA="$work/source" BIER_HOST=mini BIER_PEER_PORT=53992 BIER_PEER_CLIENT="$peer_cli" BIER_PEER_IDENTITY="$work/home/.ssh/id_ed25519" HOME="$work/home" \
	"$root/Sources/bier-core/bier" peer compare 127.0.0.1 >"$work/compare.log"
grep -q 'Bier data is identical on mini and 127.0.0.1.' "$work/compare.log"

# Two Macs installed apart: each has its own scaffolding commit and its
# own recorded inventory. Pairing alone has to leave them in sync.
kill "$pid"
wait "$pid" 2>/dev/null || true
pid=
install_data() {
	mkdir -p "$1/Brewfiles"
	cp "$root/.gitattributes" "$1/.gitattributes"
	: >"$1/Brewfiles/main"
	git init -q --initial-branch=main "$1"
	git -C "$1" config user.email test@example.com
	git -C "$1" config user.name Test
	git -C "$1" add -A
	git -C "$1" commit -q --date "$2" -m 'bier: scaffolding'
	printf '%s\n' "$4" >"$1/Brewfiles/$3"
	git -C "$1" add -A
	git -C "$1" commit -qm "$3: inventory recorded"
}
install_data "$work/installed-mini" 2026-01-01T00:00:00Z mini 'brew "jq"'
install_data "$work/installed-target" 2026-02-01T00:00:00Z target 'brew "tree"'
"$agent" serve --agent target --allowed-signers "$work/allowed_signers" --peer-signers "$work/peer_signers" --peer-key "$work/controller.pub" --peers-file "$work/remote-peers" --data-dir "$work/installed-target" --state-dir "$work/state-installed" --port 53992 --bonjour false >"$work/agent-installed.log" 2>&1 &
pid=$!
for attempt in 1 2 3 4 5; do
	if curl -fsS --max-time 1 http://127.0.0.1:53992/v1/health 2>/dev/null | grep -q '"status":"ok"'; then break; fi
	sleep 1
done
printf '{"version":1,"code":"%s","expires":%s,"attempts":0}\n' "$pair_code" "$pair_expiry" >"$work/state-installed/pairing-offer.json"
BIER_ROOT="$root" BIER_DATA="$work/installed-mini" BIER_HOST=mini BIER_PEER_PORT=53992 BIER_PEER_CLIENT="$peer_cli" BIER_PEER_IDENTITY="$work/home/.ssh/id_ed25519" BIER_PAIR_CODE="$pair_code" HOME="$work/home" \
	"$root/Sources/bier-core/bier" peer pair 127.0.0.1 >"$work/pair-installed.log" 2>&1 || { cat "$work/pair-installed.log" >&2; exit 1; }
grep -q 'Existing peer data was kept unchanged.' "$work/pair-installed.log"
grep -q 'Bier data is in sync on mini and 127.0.0.1.' "$work/pair-installed.log"
test "$(git -C "$work/installed-mini" rev-parse HEAD)" = "$(git -C "$work/installed-target" rev-parse HEAD)"
test "$(cat "$work/installed-target/Brewfiles/mini")" = 'brew "jq"'
test "$(cat "$work/installed-mini/Brewfiles/target")" = 'brew "tree"'

# A refusal says why instead of "PeerClientError error 0".
printf 'brew "local"\n' >"$work/installed-target/Brewfiles/target"
printf 'brew "wget"\n' >>"$work/installed-mini/Brewfiles/mini"
git -C "$work/installed-mini" commit -qam 'mini changed'
if "$peer_cli" sync 127.0.0.1 --local mini --identity "$work/home/.ssh/id_ed25519" --data "$work/installed-mini" --port 53992 >"$work/refused.log" 2>&1; then
	echo 'a peer with uncommitted changes accepted history' >&2
	exit 1
fi
grep -q 'HTTP 403: repository import was rejected: the Bier data repository has uncommitted changes' "$work/refused.log" || { cat "$work/refused.log" >&2; exit 1; }
printf '%s\n' 'Swift Bier agent tests passed.'
