[Docs](../../README.md) › [Commands](README.md)

# bier status

```
bier status
```

Checks this Mac against its lists — `main` plus `Brewfiles/<host>` — and
prints what differs:

```
Installed on mini but not recorded (bier dump):
  + brew "htop"
Removed on another device, still here (bier prune):
  ~ brew "ghidra"
Recorded but not installed on mini (bier install):
  - cask "iterm2"

Git:
  ## main
```

It also warns, before anything else, about

- **vault links** that point nowhere, are missing, or were replaced by a
  plain file — fixed by `bier vault --restore`;
- **Brewfile lines that are not package entries** — code that `brew`
  would run. `bier install` refuses until they are gone; see the
  [threat model](../../security/threat-model.md#a-paired-mac-is-trusted).

Changes nothing.

**See also:** [`list`](list.md), [`diff`](diff.md), [Everyday use](../../using/everyday.md)
