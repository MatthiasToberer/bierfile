[Docs](../../README.md) › [Commands](README.md)

# bier uninstall

```
bier uninstall <package>…
```

Uninstalls each package here and removes it from **every** list —
`main` and all device lists — then commits. `bier rm` is the same.

The name can be a formula, cask, tap or VS Code extension. App Store
(`mas`) apps are taken off the lists, but you delete the app yourself —
uninstalling them would need `sudo`.

If an uninstall fails, the entry stays on the lists as long as the
program is installed.

The other Macs see the removal after the next `bier sync` and offer
[`bier prune`](prune.md).

**See also:** [Removing software](../../using/removing.md)
