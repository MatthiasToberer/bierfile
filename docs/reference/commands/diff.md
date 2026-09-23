[Docs](../../README.md) › [Commands](README.md)

# bier diff

```
bier diff [host…]
```

Compares what this Mac is supposed to have with what other Macs are
supposed to have — `main` plus each device list. Without arguments,
against every other Mac.

```
== mini  vs.  macbook ==
  only macbook:  cask "font-meslo-lg-nerd-font"
  only macbook:  mas "WireGuard"
```

Compares lists, not installed software. Changes nothing.
