[Docs](../README.md) › Tutorials

# Three Macs: one with special equipment

Three Macs: `mini`, `macbook`, and `studio`, the machine for video
editing. DaVinci Resolve lives on `studio` and has no business on the
other two.

## Install it where it belongs

On `studio`, install it as usual and share it:

```sh
brew install --cask davinci-resolve
bier sync
```

Because you never move it into `main`, it lands in `Brewfiles/studio`
and stays there. On any Mac:

```sh
bier list
```

```
Brewfiles/main: 138 entries, applies to every device

Device               on top
  macbook                  2
  mini                     0
  studio                   3   (this Mac)

On top of main, and where:
  cask "davinci-resolve"                       studio
  cask "font-meslo-lg-nerd-font"               macbook
  mas "WireGuard"                              macbook
```

The other two Macs do **not** nag about Resolve — it is not in the shared
inventory. That is exactly what the device lists are for.

## Later: something turns out to belong everywhere

macbook's font should be on every Mac after all. On any Mac:

```sh
bier take
```

Pick the font and answer `m`. It moves from `Brewfiles/macbook` into
`Brewfiles/main`. After the next `bier sync`, `mini` and `studio` report
it as *recorded but not installed* until they have it.

## The other direction

Something in `main` should only be on one Mac — say a large toolchain
that only `studio` needs:

```sh
bier take --from-main
```

Pick the entry, then the Mac to hand it to. It leaves `main` and moves
to that Mac's list.

The other Macs still have it installed, and their next `bier sync` would
record it again as something *they* have on top. If they should lose it,
remove it there with plain `brew uninstall` before syncing — not with
`bier uninstall`, which would take it off every list, `studio`'s
included.

---

**Next:** [Getting rid of something everywhere](removing-everywhere.md)
