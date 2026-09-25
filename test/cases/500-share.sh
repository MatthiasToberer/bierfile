#!/usr/bin/env bash
# share: an installed app's settings, with every Mac or with a group
#
# Bierkasten offers it on right-click, where nobody can answer a
# question: bier share takes all the app's settings it finds and asks
# nothing, for every Mac or --for a group.

system mini <<'SYS'
brew "jq"
brew "bat"
SYS
export BIER_VAULT_PASS=probe
h=$WORK/home-mini
mkdir -p "$h/.config/jq" "$h/.config/bat"
printf 'q\n' >"$h/.config/jq/defs.jq"
printf 'b\n' >"$h/.config/bat/config"
assert_ok bier mini dump
assert_ok bier mini main

assert_ok bier mini share jq
assert_ok bier mini report
assert_contains "$OUT" 'APPSET	brew "jq"	jq	config	'

assert_ok bier mini vault group laptops mini
assert_ok bier mini share --for laptops bat
assert_ok bier mini report
assert_contains "$OUT" "GROUP	laptops	mini"
assert_contains "$OUT" 'APPSET	brew "bat"	bat	config	laptops'

assert_fails bier mini share wget
assert_contains "$OUT" "neither installed here nor on a list"
