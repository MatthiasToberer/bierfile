[Docs](../../README.md) › [Commands](README.md)

# bier main

```
bier main [--no-push]
```

Replaces `Brewfiles/main` with the inventory of this Mac and rebases
every device list onto it. **Once in the life of a setup**, on the
template Mac.

If `main` already has entries, bier lists what would drop out — entries
in `main` that are not installed here, even if another Mac still has
them — and asks before continuing:

```
Will drop out of main for good, because it is not installed
on mini — even if another device still has it:
  - cask "font-meslo-lg-nerd-font"

To keep it, hand it to a device first:
  bier take --from-main
```

Commits the result; `--no-push` leaves it uncommitted for a later
`bier sync`.

> [!CAUTION]
> Never run `bier main` on a Mac that joined later. It would replace the
> shared inventory with that Mac's.
