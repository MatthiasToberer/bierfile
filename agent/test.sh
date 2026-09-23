#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d /private/tmp/bier-agent-swift.XXXXXX)
pid=
cleanup() {
	[ -z "$pid" ] || kill "$pid" 2>/dev/null || true
	[ -z "$pid" ] || wait "$pid" 2>/dev/null || true
	rm -rf "$work"
}
trap cleanup EXIT

agent="$work/bier-agent"
"$here/build.sh" "$agent" >/dev/null
swiftc -O -framework Foundation -o "$work/snapshot-test" "$here/DataSnapshot.swift" "$here/SnapshotTest.swift"
"$work/snapshot-test"
ssh-keygen -q -t ed25519 -N '' -f "$work/controller"
printf 'controller-test %s\n' "$(cat "$work/controller.pub")" >"$work/allowed_signers"
printf 'mini %s\n' "$(cat "$work/controller.pub")" >"$work/peer_signers"
mkdir -p "$work/data/Brewfiles" "$work/data/Safe"
printf 'brew "wget"\n' >"$work/data/Brewfiles/main"
printf 'encrypted\n' >"$work/data/Safe/test.gpg"
printf '%s\n' '{"version":1,"id":"probe-1","target":"mini","type":"agent.probe","expires_at":"2099-01-01T00:00:00Z","issuer":"controller-test","payload":{}}' >"$work/recipe.json"
ssh-keygen -q -Y sign -f "$work/controller" -n bier-recipe "$work/recipe.json"

"$agent" serve --agent mini --allowed-signers "$work/allowed_signers" --peer-signers "$work/peer_signers" --data-dir "$work/data" --state-dir "$work/state" --port 53992 --bonjour false >"$work/agent.log" 2>&1 &
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
peer_nonce=agent-snapshot-begin-0123456789
snapshot_id=snapshot-begin-0123456789
printf '{"id":"%s"}' "$snapshot_id" >"$work/snapshot-begin.json"
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
printf '{"id":"%s","path":"Brewfiles/received","data":"YnJldyAidHJlZSIK"}' "$snapshot_id" >"$work/snapshot-put.json"
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
recipe=$(base64 <"$work/recipe.json" | tr -d '\n')
signature=$(base64 <"$work/recipe.json.sig" | tr -d '\n')
body=$(printf '{"recipe":"%s","signature":"%s"}' "$recipe" "$signature")
status=$(curl -sS --max-time 2 -o "$work/response" -w '%{http_code}' -H 'Content-Type: application/json' --data "$body" http://127.0.0.1:53992/v1/probe)
[ "$status" = 200 ]
grep -q '"status":"accepted"' "$work/response"
status=$(curl -sS --max-time 2 -o "$work/response" -w '%{http_code}' -H 'Content-Type: application/json' --data "$body" http://127.0.0.1:53992/v1/probe)
[ "$status" = 409 ]
printf '%s\n' 'Swift Bier agent tests passed.'
