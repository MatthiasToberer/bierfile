#!/usr/bin/env bash
# Brewfiles never end up in the code repository
#
# The reason for the split: the Brewfiles reveal which software is on the
# Macs. The code repository is public. An entry that slips in there could
# never be taken back — the history keeps it.

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
EOF

system mini <<'EOF'
brew "wget"
cask "something-private"
EOF

bier mini sync "mini: inventory"

# The change is in the data repository.
assert_file_has "$(bf mini mini)" 'cask "something-private"'
data_commits=$(git -C "$WORK/mini" log --oneline | wc -l | tr -d ' ')
[ "$data_commits" -ge 2 ] || fail "the data repository should have gained a commit"

# And nowhere else.
assert_eq "" "$(ls "$WORK/code-mini" | grep -x Brewfiles || true)" \
	"no Brewfiles folder may sit in the code directory"
assert_eq "" "$(git -C "$WORK/code-mini" status --porcelain)" \
	"the code repository has to stay untouched"
assert_eq "1" "$(git -C "$WORK/code-mini" log --oneline | wc -l | tr -d ' ')" \
	"the code repository must not have gained a commit"

# Not in the code server's history either.
assert_eq "" "$(git -C "$WORK/code.git" log --all --name-only --format= |
	grep -x 'Brewfiles.*' || true)" \
	"no Brewfile may ever have been in the code repository"

# The other way round: the data repository knows nothing of the code.
assert_eq "" "$(ls "$WORK/mini" | grep -x bin || true)" \
	"the program has no business in the data directory"
