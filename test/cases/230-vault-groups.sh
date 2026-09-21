#!/usr/bin/env bash
# groups: a file for some Macs and not for others
#
# "Shared or one Mac" has no answer for the ordinary case -- these two
# but not that one. A scope directory says who a file is for, so there
# is no second list to keep in step, and a device name is simply a
# group of one.

system mini <<'SYS'
brew "wget"
SYS
system macbook <<'SYS'
brew "wget"
SYS

export BIER_VAULT_PASS=probe

# No groups at all: everything is for everybody.
assert_ok bier mini vault group
assert_contains "$OUT" "every Mac" "without groups nothing is restricted"

# A group holding only the first Mac.
assert_ok bier mini vault group laptops mini
assert_ok bier mini vault group
assert_contains "$OUT" "this Mac" "the Mac has to see that it belongs"

printf 'nur fuer laptops\n' >"$WORK/home-mini/.only"
assert_ok bier mini vault add --for laptops "$WORK/home-mini/.only"
assert_ok bier mini sync

# The other Mac syncs and must not get it.
assert_ok bier macbook sync
assert_eq "no" \
	"$([ -e "$WORK/home-macbook/.only" ] && echo yes || echo no)" \
	"a Mac outside the group must not get the file"
assert_eq "yes" \
	"$([ -f "$WORK/macbook/Safe/@laptops/dot_only.gpg" ] && echo yes || echo no)" \
	"but the encrypted copy does travel — it is simply not opened"

# It knows the groups, because they travel too.
assert_ok bier macbook vault group
assert_contains "$OUT" "laptops" "the groups have to reach the other Mac"

# Let it in, and it arrives.
assert_ok bier macbook vault group laptops mini macbook
assert_ok bier macbook sync
assert_eq "nur fuer laptops" "$(cat "$WORK/home-macbook/.only")" \
	"once in the group the file has to arrive"

# And the group can go again.
assert_ok bier macbook vault group --drop laptops
assert_ok bier macbook vault group
assert_not_contains "$OUT" "laptops" "a dropped group has to be gone"
