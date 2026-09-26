[Docs](../../README.md) › [Commands](README.md)

# bier diff

> Out of sight since 0.50.12: `bier list` and Bierkasten show this. The command still
> works and says so.

```
bier diff [host…]
```

Compares what this Mac is supposed to have with what other Macs are
supposed to have — All Macs, its group and what it recorded. Without arguments,
against every other Mac.

```
== mini  vs.  macbook ==
  only macbook:  cask "font-meslo-lg-nerd-font"
  only macbook:  mas "WireGuard"
```

Compares lists, not installed software. Changes nothing.
