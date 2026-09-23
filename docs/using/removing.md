[Docs](../README.md) › Using bier

# Removing software

Removing is an action of its own in bier, because a snapshot of what is
installed cannot carry a removal across — see
[How removals travel](../concepts/removals.md).

## Everywhere: `bier uninstall`

```sh
bier uninstall ghidra
bier uninstall ghidra htop      # several at once
```

Uninstalls here and drops the entry from **every** list — `main` and
every Mac's — and commits that. The other Macs learn of it with the next
`bier sync`. If the uninstall fails, the entry stays on the lists as long
as the program is installed.

Do not use plain `brew uninstall` for this. The entry would stay on the
list, and the next `bier install` would bring the program back.

## Following along: `bier prune`

On the other Macs the program is still installed. `bier status` marks
it with `~`, BierMenu offers *Remove*:

```sh
bier prune
```

```
Removed elsewhere, still installed here:
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
