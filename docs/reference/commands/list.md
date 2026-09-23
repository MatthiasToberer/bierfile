[Docs](../../README.md) › [Commands](README.md)

# bier list

```
bier list
```

Overview of all Macs: how many entries `main` holds, how many each Mac
has on top, and which Mac has which extra.

```
Brewfiles/main: 138 entries, applies to every device

Device               on top
  macbook                  2
  mini                     0   (this Mac)

On top of main, and where:
  cask "font-meslo-lg-nerd-font"               macbook
  mas "WireGuard"                              macbook
```

Changes nothing. To adopt an entry: [`bier take`](take.md).
