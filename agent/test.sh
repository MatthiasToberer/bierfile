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
ssh-keygen -q -t ed25519 -N '' -f "$work/controller"
printf 'controller-test %s\n' "$(cat "$work/controller.pub")" >"$work/allowed_signers"
printf '%s\n' '{"version":1,"id":"probe-1","target":"mini","type":"agent.probe","expires_at":"2099-01-01T00:00:00Z","issuer":"controller-test","payload":{}}' >"$work/recipe.json"
ssh-keygen -q -Y sign -f "$work/controller" -n bier-recipe "$work/recipe.json"

"$agent" serve --agent mini --allowed-signers "$work/allowed_signers" --state-dir "$work/state" --port 53992 --bonjour false >"$work/agent.log" 2>&1 &
pid=$!
for attempt in 1 2 3 4 5; do
	if curl -fsS --max-time 1 http://127.0.0.1:53992/v1/health 2>/dev/null | grep -q '"status":"ok"'; then break; fi
	sleep 1
done
curl -fsS --max-time 1 http://127.0.0.1:53992/v1/health | grep -q '"status":"ok"'
recipe=$(base64 <"$work/recipe.json" | tr -d '\n')
signature=$(base64 <"$work/recipe.json.sig" | tr -d '\n')
body=$(printf '{"recipe":"%s","signature":"%s"}' "$recipe" "$signature")
status=$(curl -sS --max-time 2 -o "$work/response" -w '%{http_code}' -H 'Content-Type: application/json' --data "$body" http://127.0.0.1:53992/v1/probe)
[ "$status" = 200 ]
grep -q '"status":"accepted"' "$work/response"
status=$(curl -sS --max-time 2 -o "$work/response" -w '%{http_code}' -H 'Content-Type: application/json' --data "$body" http://127.0.0.1:53992/v1/probe)
[ "$status" = 409 ]
printf '%s\n' 'Swift Bier agent tests passed.'
