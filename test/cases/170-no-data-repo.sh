#!/usr/bin/env bash
# Without a data repository bier points the way instead of writing into the program
#
# Whoever clones the public repository has no repository for their own
# inventory yet. bier used to fall back to the program directory and
# would have written the inventory there — publishing exactly what is
# meant to stay private.

# A setup as it is right after "git clone": program there, data not.
rm -f "$WORK/home-mini/.barrel/config"
printf 'root = %s\nhost = mini\n' "$WORK/code-mini" \
	>"$WORK/home-mini/.barrel/config"

system mini <<'EOF'
brew "wget"
EOF

for command in status dump list sync; do
	bier mini "$command" || true
	assert_contains "$OUT" "No repository of your own" \
		"$command has to point at the missing data repository"
	assert_contains "$OUT" "install.sh" "and say how to set it up"
done

# And none of it may have landed in the program directory.
assert_eq "" "$(ls "$WORK/code-mini" | grep -x Brewfiles || true)" \
	"no Brewfiles folder may appear in the program repository"
assert_eq "" "$(git -C "$WORK/code-mini" status --porcelain)" \
	"the program repository has to stay untouched"

# bier config names the state as well.
bier mini config
assert_contains "$OUT" "not set up yet"
