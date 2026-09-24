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
Every Mac (main)
  …

Only on studio (this Mac)
  davinci-resolve                  app

Only on macbook
  font-meslo-lg-nerd-font          app
  WireGuard                        App Store
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
that only `studio` needs. On a Mac that should lose it:

```sh
bier uninstall --from-main --keep studio toolchain
```

or plain `bier uninstall toolchain`, answer `m` and pick `studio`. It is
uninstalled here, leaves `main` and moves to `studio`'s list; `studio`
keeps it installed.

Every other Mac that has it installed reports it after the next
`bier sync` as *no longer in main, still here*. There you decide:
`bier prune` removes it, `bier take` keeps it on that Mac's own list.
BierMenu offers both.

To only move the entry without uninstalling anything, there is
`bier take --from-main`: pick the entry, then the Mac to hand it to.

---

**Next:** [Getting rid of something everywhere](removing-everywhere.md)
