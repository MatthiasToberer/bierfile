[Docs](../../README.md) › [Commands](README.md)

# bier uninstall

```
bier uninstall [--everywhere | --from-main [--keep <mac>,…] | --here] <package>…
```

Uninstalls each package here and asks which lists lose it:

| Answer | Flag | Lists afterwards |
| --- | --- | --- |
| `a` everywhere | `--everywhere` | off `main` and every Mac's list |
| `m` out of main | `--from-main [--keep <mac>,…]` | off `main`; only the Macs named keep it on their own lists |
| `h` only here | `--here` | off this Mac's list; not offered when the entry is in `main` |

A Mac named with `--keep` keeps the program installed, this one
included. Without a flag and without a terminal to ask, bier stops
before changing anything. `bier rm` is the same command.

The name can be a formula, cask, tap or VS Code extension. App Store
(`mas`) apps are taken off the lists, but you delete the app yourself —
uninstalling them would need `sudo`.

If an uninstall fails, the entry stays on the lists as long as the
program is installed. In automatic inventory mode this Mac's list is
recorded afresh afterwards; in manual mode it is left as you wrote it.

The other Macs see the change after the next `bier sync` and offer
[`bier prune`](prune.md).

**See also:** [Removing software](../../using/removing.md)
