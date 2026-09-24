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
BIER_PEER_CLIENT=$WORK/none
export BIER_PEER_CLIENT
assert_ok bier mini peer add other.ts.net

assert_ok bier mini report
assert_contains "$OUT" "STATE	"
assert_contains "$OUT" "MAC	mini"
assert_contains "$OUT" 'ENTRY	main	brew "wget"'
assert_contains "$OUT" "FILE	~/.zshrc	"
assert_contains "$OUT" "PEER	other.ts.net	never"

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
