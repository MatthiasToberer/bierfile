[Docs](../../README.md) › [Commands](README.md)

# bier status

```
bier status
```

Shows what the next `bier sync` would carry, then checks this Mac against
its lists — All Macs, its group, and what it recorded itself — and
prints what differs:

```
Sync (bier sync):
  -> to macbook       2 commit(s) from here not sent yet
  ^  Brewfiles        Brewfiles/main changed, not committed
  ^  vault            /Users/you/.zshrc changed here
  v  vault            /Users/you/.gitconfig newer in the safe
  !  vault            /Users/you/.zshrc.from-safe left from a conflict: merge it, then delete it

Installed on mini but not recorded (bier sync):
  + brew "htop"
Removed on another device, still here (bier prune):
  ~ brew "ghidra"
No longer in main, still here (bier prune, or bier place to keep it):
  ~ brew "nmap"
Recorded but not installed on mini (bier install):
  - cask "iterm2"

Git:
  ## main
```

The sync section uses only what this Mac knows — nothing is asked over
the network. *Not sent yet* counts commits made here since the last
sync with that peer. *Newer in the safe* is what a peer delivered and
the next sync (or BierMenu, on its own) puts in place.

It also warns, before anything else, about

- **vault links** that point nowhere, are missing, or were replaced by a
  plain file — fixed by `bier vault --restore`;
- **Brewfile lines that are not package entries** — code that `brew`
  would run. `bier install` refuses until they are gone; see the
  [threat model](../../security/threat-model.md#a-paired-mac-is-trusted).

Changes nothing.

**See also:** [`list`](list.md), [`diff`](diff.md), [Everyday use](../../using/everyday.md)
