[Docs](../README.md) › Tutorials

# Getting rid of something everywhere

A program has to go from every Mac. Three Macs — `mini`, `macbook`,
`studio` — and HandBrake is in `main`.

## On any Mac

```sh
bier uninstall handbrake
```

```
handbrake (cask)
==> Uninstalling Cask handbrake
Brewfiles/mini written: 0 on top of 137 in main
Commit: mini: removed handbrake
Saved in the local Bier history.
```

That uninstalled it here and dropped it from **every** list. Pass it on:

```sh
bier sync
```

## On the other Macs

HandBrake is still installed there — bier never uninstalls anything
without asking. The next time you look at the menu:

```
1 removed elsewhere, still here
    handbrake  (app)
Remove … (in Terminal)
```

Click **Remove**, confirm, gone. The terminal equivalent:

```sh
bier prune
```

```
Removed elsewhere, still installed here:
  cask "handbrake"
Uninstall? [y/N] y
```

## Why this works

A snapshot of what is installed cannot carry a removal across: on the
other Macs HandBrake is simply installed and on no list — exactly like
something new. bier tells the two apart by asking the git history whether
the entry *used to be* on a list. Details:
[How removals travel](../concepts/removals.md).

Do not use plain `brew uninstall` for this: the entry would stay on the
list, and the next `bier install` would bring the program back.

---

**Next:** [Your dotfiles on a new Mac](dotfiles-on-a-new-mac.md)
