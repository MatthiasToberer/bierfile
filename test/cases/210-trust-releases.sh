#!/usr/bin/env bash
# trust: verify releases against a key fetched from somewhere else
#
# The point of fetching the key from another host is that whoever takes
# over the code server does not thereby hold the key. That only works if
# bier remembers what it fetched and then refuses anything else — both
# a release signed by somebody else and one signed by nobody.

system mini <<'SYS'
brew "wget"
SYS

keys=$WORK/signing
mkdir -p "$keys"
ssh-keygen -q -t ed25519 -N "" -C "good" -f "$keys/good"
ssh-keygen -q -t ed25519 -N "" -C "evil" -f "$keys/evil"

# Nothing remembered yet.
assert_ok bier mini trust
assert_contains "$OUT" "not verified" "without a key nothing is verified"

# A page that is not a key file has to be refused — a login page
# answers 200 just as happily as a key does.
printf '<html>not a key</html>\n' >"$WORK/notakey"
assert_fails bier mini trust "file://$WORK/notakey"
assert_contains "$OUT" "does not hold signing keys" "a page is not a key file"

# Remember the good key.
printf 'bier-releases %s\n' "$(cat "$keys/good.pub")" >"$WORK/allowed_signers"
assert_ok bier mini trust "file://$WORK/allowed_signers"
assert_contains "$OUT" "Remembered" "the key has to be remembered"
assert_ok bier mini trust
assert_contains "$OUT" "ED25519" "and reported back with its fingerprint"

# A release nobody signed is refused.
git -C "$WORK/code.git" tag -a v9.9.8 -m "unsigned"
assert_fails bier mini upgrade
assert_contains "$OUT" "no signature" "an unsigned release must not install"

# A release signed by somebody else is refused.
git -C "$WORK/code.git" -c gpg.format=ssh \
	-c user.signingkey="$keys/evil.pub" \
	-c user.email=evil@example.com -c user.name=evil \
	tag -s v9.9.9 -m "signed by the wrong key"
assert_fails bier mini upgrade
assert_contains "$OUT" "not signed with the key" "a foreign signature must not install"

# And it can be given up again.
assert_ok bier mini trust --forget
assert_ok bier mini trust
assert_contains "$OUT" "No key remembered" "forgetting has to take effect"
