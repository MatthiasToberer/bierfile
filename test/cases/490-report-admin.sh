#!/usr/bin/env bash
# report gives Bierkasten everything in lines; admin lets it connect
#
# Bierkasten shows what bier knows, so bier says it in one go: the state,
# the lists, the shared settings and files, the peers. And Bierkasten
# pairs with the agent like a peer, but into a list of its own.

system mini <<'SYS'
brew "wget"
brew "jq"
SYS
export BIER_VAULT_PASS=probe
h=$WORK/home-mini
printf 'z\n' >"$h/.zshrc"
assert_ok bier mini dump
assert_ok bier mini main
assert_ok bier mini vault add "$h/.zshrc"
mkdir -p "$h/Tools/Foo" && printf 'f\n' >"$h/Tools/Foo/foo.conf"
assert_ok bier mini vault add --app Foo "$h/Tools/Foo"
BIER_PEER_CLIENT=$WORK/none
export BIER_PEER_CLIENT
assert_ok bier mini peer add other.ts.net

assert_ok bier mini report
assert_contains "$OUT" "STATE	"
assert_contains "$OUT" "MAC	mini"
assert_contains "$OUT" 'ENTRY	main	brew "wget"'
assert_contains "$OUT" "FILE	~/.zshrc	"
assert_contains "$OUT" "PEER	other.ts.net	never"
assert_contains "$OUT" "APPSET		Foo	Foo	"
assert_contains "$OUT" "HISTORY	"

mkdir -p "$h/.barrel/agent/bin"
printf '#!/bin/sh\n' >"$h/.barrel/agent/bin/bier-agent"
chmod +x "$h/.barrel/agent/bin/bier-agent"
assert_ok bier mini admin offer
assert_contains "$OUT" "Enter this code in Bierkasten:"
[ -f "$h/.barrel/agent/state/admin/pairing-offer.json" ] || fail "the offer is where the agent looks for it"
assert_ok bier mini admin list
assert_contains "$OUT" "No Bierkasten is connected."
printf 'kasten ssh-ed25519 AAAA\n' >"$h/.barrel/agent/admin_signers"
assert_ok bier mini admin remove kasten
assert_ok bier mini admin list
assert_contains "$OUT" "No Bierkasten is connected."
assert_fails bier mini admin remove kasten

# Conflicts are resolved without a question, for Bierkasten.
printf 'mine\n' >"$h/.gitconfig"
printf 'theirs\n' >"$h/.gitconfig.from-safe"
assert_ok bier mini vault resolve "$h/.gitconfig.from-safe" theirs
assert_file_has "$h/.gitconfig" theirs
[ ! -e "$h/.gitconfig.from-safe" ] || fail "the copy took the file's place"
assert_file_has "$WORK/trash-mini/.gitconfig" mine
printf 'other\n' >"$h/.gitconfig.from-safe"
assert_ok bier mini vault resolve "$h/.gitconfig.from-safe" mine
assert_file_has "$h/.gitconfig" theirs
assert_fails bier mini vault resolve "$h/.gitconfig" mine
assert_ok bier mini prune --yes

# What Bierkasten shows about each Mac, and the others' state.
assert_ok bier mini state
assert_contains "$OUT" "INFO	macos	"
cat >"$WORK/fleet-client" <<'EOF2'
#!/bin/sh
case $2 in
up.ts.net) if [ "$1" = name ]; then echo up; else printf 'STATE\tok\nHOST\tup\nINFO\tmacos\t26.0\n'; fi ;;
old.ts.net) [ "$1" = name ] && echo old ;;
*) exit 1 ;;
esac
EOF2
chmod +x "$WORK/fleet-client"
BIER_PEER_CLIENT=$WORK/fleet-client
assert_ok bier mini peer add up.ts.net
assert_ok bier mini peer add old.ts.net
assert_ok bier mini fleet
assert_contains "$OUT" "FLEET	up.ts.net	online"
assert_contains "$OUT" "AT	up.ts.net	INFO	macos	26.0"
assert_contains "$OUT" "FLEET	other.ts.net	offline"
assert_contains "$OUT" "FLEET	old.ts.net	reachable"

# Whom this Mac trusts, for the mesh in Bierkasten.
mkdir -p "$h/.barrel/agent"
printf 'macbook ssh-ed25519 AAAA\n' >"$h/.barrel/agent/peer_signers"
assert_ok bier mini state
assert_contains "$OUT" "TRUSTS	macbook"

# A Mac has one name, whatever address it is reached by; changing the
# address keeps its key.
assert_ok bier mini peer list
assert_contains "$OUT" "up               up.ts.net"
printf 'up ssh-ed25519 AAAA\n' >>"$h/.barrel/agent/peer_signers"
assert_ok bier mini peer address up up.example.ts.net
assert_contains "$OUT" "up is reached at up.example.ts.net now"
assert_ok bier mini peer list
assert_contains "$OUT" "up.example.ts.net"
assert_not_contains "$OUT" "up.ts.net"
assert_file_has "$h/.barrel/agent/peer_signers" "up ssh-ed25519 AAAA"
assert_fails bier mini peer address nobody x.ts.net
