[Docs](../../README.md) › [Commands](README.md)

# bier uninstall

```
bier uninstall [--everywhere | --from-main [--keep <group>,…] | --group <g> | --here] <package>…
```

Uninstalls each package here and asks which lists lose it:

| Answer | Flag | Lists afterwards |
| --- | --- | --- |
| `a` everywhere | `--everywhere` | off All Macs, every group and every Mac's list |
| `m` off All Macs | `--from-main [--keep <group>,…]` | off All Macs; only the groups named keep it |
| `g` off a group | `--group <g>` | off that group's list; offered for this Mac's group |
| `h` only here | `--here` | off what this Mac recorded and nobody assigned |

A Mac whose group keeps it keeps the program installed, this one
included; taking it off another group leaves it installed here. Without a flag and without a terminal to ask, bier stops
before changing anything. `bier rm` is the same command.

The name can be a formula, cask, tap, VS Code extension, or an `npm`,
`cargo`, `uv`, `krew`, `whalebrew` or `flatpak` entry. App Store (`mas`)
apps are taken off the lists, but you delete the app yourself —
uninstalling them would need `sudo`; so are `go` entries, which have no
uninstaller.

If an uninstall fails, the entry stays on the lists as long as the
program is installed. In automatic inventory mode what this Mac has is
recorded afresh afterwards; in manual mode the lists stay as you wrote
them.

The other Macs see the change after the next `bier sync` and offer
[`bier prune`](prune.md). To remove it on the other Macs at once:
`bier place <package> --none --now`.

**See also:** [Removing software](../../using/removing.md)
