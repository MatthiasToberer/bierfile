[Docs](../../README.md) › [Commands](README.md)

# bier upgrade

```
bier upgrade [--force]
```

Installs a newer release of bier itself. Never touches your lists.

1. Fetches the release tags and compares the newest with the installed
   version.
2. If you pinned a key with [`bier trust`](trust.md), verifies the tag's
   signature and refuses an unsigned or foreign one.
3. Checks the release out and runs `install.sh`, which rebuilds BierMenu
   and the agent.

`--force` rebuilds the installed version without moving to another one.

A program repository without release tags follows its branch instead.

**See also:** [Signed releases](../../security/signed-releases.md)
