[Docs](../../README.md) › [Commands](README.md)

# bier init

```
bier init [--no-push]
```

Makes this Mac's software what **All Macs** have — `Brewfiles/main` —
and tidies every other list onto it: the groups' lists and what the
Macs recorded keep only what All Macs do not have already. **Once in the
life of a setup**, on the template Mac.

If `main` already has entries, bier lists what would drop out — entries
in `main` that are not installed here, even if another Mac still has
them — and asks before continuing:

```
Will no longer be for All Macs, because it is not installed
on mini — even if another Mac still has it:
  - cask "font-meslo-lg-nerd-font"

To keep it for some Macs, give it to their group first:
  bier place <package> --on <group>
```

Commits the result; `--no-push` leaves it uncommitted for a later
`bier sync`.

> [!CAUTION]
> Never run `bier init` on a Mac that joined later. It would replace the
> shared inventory with that Mac's.

`bier main` is the same command by its old name.
