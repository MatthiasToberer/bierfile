#!/usr/bin/env bash
# peers are a local, safe-to-repeat contact list

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
