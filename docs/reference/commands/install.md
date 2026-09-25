[Docs](../../README.md) › [Commands](README.md)

# bier install

```
bier install
```

Installs everything this Mac's lists name: All Macs (`Brewfiles/main`),
its group (`Brewfiles/@<group>`), and what it recorded itself
(`Brewfiles/<host>`), each with `brew bundle install`.

Before installing anything, **every** file is checked: a line that is
not a package entry makes bier refuse, rather than let `brew` run it.
See the [threat model](../../security/threat-model.md#a-paired-mac-is-trusted).

This can take a long time on a new Mac, and macOS may ask for your
password. BierMenu's *Install missing* runs it in a terminal.
