[Docs](../README.md) › Using bier

# Adopting entries

`bier list` shows what other Macs have on top of `main`. `bier take`
lets you pick from that list and decide where each pick goes.

```sh
bier take
```

```
What other devices have on top of main:

   1  cask "font-meslo-lg-nerd-font"               macbook
   2  mas "WireGuard"                              macbook

Numbers (e.g. 1 3-5), empty = cancel: 1
Where to?  [m] into main, for all devices   [h] only mini   [c] cancel: m

Plan:
  cask "font-meslo-lg-nerd-font"
    + Brewfiles/main
    - Brewfiles/macbook

Apply and push? [y/N] y
…
Install now? [y/N]
```

## Where to

- **`m` — into main.** Applies to every Mac from now on, and therefore
  leaves the lists of the Macs that had it. Listing it twice would be
  wrong.
- **`h` — only this Mac.** Goes into this Mac's own list. The others
  keep their entries; each has it device-specifically.

bier shows the plan and asks before it changes anything, then commits.
The other Macs see the change after the next `bier sync`. Finally it
offers to install the picks right away; if you decline, `bier status`
reports them as missing and `bier install` fetches them.

## The other direction

```sh
bier take --from-main
```

Takes an entry out of the shared inventory and hands it to a single Mac:
"runs everywhere" becomes "runs here only". You pick the entry, then the
Mac.

The other Macs keep the program installed, and their next `bier sync`
records it again as something *they* have on top. If they should lose it,
remove it there with plain `brew uninstall` before syncing.
[`bier uninstall`](removing.md) would take it off every list, including
the one you just handed it to.

Selections accept ranges: `1 3-5`.
