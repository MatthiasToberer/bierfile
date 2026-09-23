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
brew "ghidra" is listed in: main, studio
What should happen?
  [a] everywhere     uninstall here, take it off every list;
                     the other Macs offer bier prune
  [m] out of main    uninstall here, take it out of main;
                     you pick the Macs that keep it
  [c] cancel
Choice:
```

- **everywhere** — off `main` and every Mac's list. The other Macs learn
  of it with the next `bier sync` and offer `bier prune`.
- **out of main** — off `main`; only the Macs you pick keep it, on their
  own lists. If you pick this Mac, it stays installed here. Macs that had
  it only through `main` report it as *no longer in main* and let you
  remove it (`bier prune`) or keep it (`bier take`).
- **only here** (offered when it is not in `main`) — uninstalled here and
  off this Mac's list; every other list stays.

Scripts, and anything without a terminal, say it up front — without an
answer bier changes nothing:

```sh
bier uninstall --everywhere ghidra
bier uninstall --from-main --keep studio ghidra
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
