#!/usr/bin/env bash
# the first inventory can be pushed to an empty private repository

git init -q --bare --initial-branch=main "$WORK/empty-data.git"
git -C "$WORK/mini" remote set-url origin "$WORK/empty-data.git"

printf 'brew "first-private-inventory"\n' >>"$(bf mini mini)"
assert_ok bier mini push 'mini: first private inventory'
assert_contains "$OUT" 'First inventory pushed to origin.'

git --git-dir="$WORK/empty-data.git" show-ref --verify --quiet refs/heads/main ||
	fail "the first private branch was not pushed"
assert_eq 'origin/main' \
	"$(git -C "$WORK/mini" rev-parse --abbrev-ref --symbolic-full-name '@{u}')" \
	"the first push must set an upstream for later syncs"
