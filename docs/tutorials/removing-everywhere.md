[Docs](../README.md) › Tutorials

# Getting rid of something everywhere

A program has to go from every Mac. Three Macs — `mini`, `macbook`,
`studio` — and HandBrake is for All Macs.

## On any Mac

```sh
bier uninstall --everywhere handbrake
```

```
handbrake (cask)
==> Uninstalling Cask handbrake
Recorded on mini: 0 not assigned, beside 137 for All Macs
Commit: mini: removed handbrake
Saved in the local Bier history.
```

That uninstalled it here and dropped it from **every** list. Pass it on:

```sh
bier sync
```

## On the other Macs

HandBrake is still installed there: an uninstall changes the lists, and
each Mac removes it when asked. The next time you look at the menu:

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
Removed elsewhere or taken out of main, still installed here:
  cask "handbrake"
Uninstall? [y/N] y
```

## All at once

To have every Mac remove it as soon as the change arrives, say so:

```sh
bier place handbrake --none --now
```

Macs in a group whose rule is `apply ask` still only report it.

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
