[Docs](../README.md) › Using bier

# Removing software

Removing is an action of its own in bier, because a snapshot of what is
installed cannot carry a removal across — see
[How removals travel](../concepts/removals.md).

## `bier uninstall`: which lists lose it

```sh
bier uninstall ghidra
```

```
brew "ghidra" is listed in: main, @video
What should happen?
  [a] everywhere     uninstall here, take it off every list;
                     the other Macs offer bier prune
  [m] off All Macs   uninstall here, take it off All Macs;
                     you pick the groups that keep it
  [c] cancel
Choice:
```

- **everywhere** — off All Macs, every group and every Mac's own list.
  The other Macs learn of it with the next `bier sync` and offer
  `bier prune`.
- **off All Macs** — only the groups you pick keep it. If this Mac's
  group is one of them, it stays installed here. Macs that had it only
  through All Macs report it as *no longer in main* and let you remove
  it (`bier prune`) or keep it for their group (`bier place`).
- **off a group** (offered for this Mac's group) — uninstalled here and
  off that group's list; everything else stays.
- **only here** (offered when this Mac only recorded it, not assigned) —
  uninstalled here and off this Mac's own list.

Scripts, and anything without a terminal, say it up front — without an
answer bier changes nothing:

```sh
bier uninstall --everywhere ghidra
bier uninstall --from-main --keep video ghidra
bier uninstall --group desk ghidra
bier uninstall --here htop
```

If the uninstall fails, the entry stays on the lists as long as the
program is installed.

Do not use plain `brew uninstall` for this. The entry would stay on the
list, and the next `bier install` would bring the program back.

## Following along: `bier prune`

On the other Macs the program is still installed. `bier status` marks
it with `~`, BierMenu offers *Remove*:

```sh
bier prune
```

```
Removed elsewhere or taken out of main, still installed here:
  brew "ghidra"
Uninstall? [y/N]
```

bier removes taps last, because Homebrew refuses to untap while something
from the tap is still installed. Anything that could not be removed is
listed again at the end.

## Keeping it here after all

If you want to keep a program that was removed elsewhere, record it
deliberately as this Mac's own:

```sh
bier dump --adopt
```

## Mac App Store apps

bier cannot uninstall `mas` entries — that would need `sudo`. For those,
`bier uninstall` and `bier prune` take the entry off the lists and ask
you to delete the app from `/Applications` yourself.

Homebrew formulae, casks, taps and VS Code extensions (`vscode` entries)
are uninstalled directly.
