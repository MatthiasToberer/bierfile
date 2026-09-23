#!/usr/bin/env bash
# Missing installer tools stop setup before identity prompts or changes

mkdir -p "$WORK/prerequisite-bin" "$WORK/installer-home"
ln -s /usr/bin/dirname "$WORK/prerequisite-bin/dirname"
ln -s /usr/bin/uname "$WORK/prerequisite-bin/uname"
cat >"$WORK/prerequisite-bin/git" <<'STUB'
#!/bin/sh
printf 'git was invoked\n' >>"$HOME/git-called"
STUB
chmod +x "$WORK/prerequisite-bin/git"
ln -s /usr/bin/true "$WORK/prerequisite-bin/swiftc"

if OUT=$(HOME="$WORK/installer-home" PATH="$WORK/prerequisite-bin" /bin/sh "$REPO/install.sh" 2>&1); then
	fail 'installation must fail without Homebrew'
fi
assert_contains "$OUT" '[OK]      git'
assert_contains "$OUT" '[OK]      swiftc'
assert_contains "$OUT" '[MISSING] brew'
assert_contains "$OUT" 'INSTALLATION STOPPED'
assert_contains "$OUT" 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh'
assert_contains "$OUT" 'Fix these first, then run:'
test ! -e "$WORK/installer-home/git-called"
test ! -e "$WORK/installer-home/.config"
[[ "$OUT" != *$'\033'* ]]
[[ "$OUT" != *'identity'* ]]
[[ "$OUT" != *'gpg'* ]]

rm "$WORK/prerequisite-bin/swiftc"
if OUT=$(HOME="$WORK/installer-home" PATH="$WORK/prerequisite-bin" /bin/sh "$REPO/install.sh" 2>&1); then
	fail 'installation must fail with multiple missing tools'
fi
assert_contains "$OUT" '[MISSING] swiftc'
assert_contains "$OUT" '[MISSING] brew'
assert_contains "$OUT" 'missing prerequisites: 2'
assert_contains "$OUT" 'xcode-select --install'
