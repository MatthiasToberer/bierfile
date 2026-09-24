[Docs](../../README.md) › [Commands](README.md)

# bier knockout

```
bier knockout [--dry-run]
```

Takes bier off this Mac and this Mac out of the group. After you type
`knockout` to confirm, it:

1. syncs one last time, so nothing made here is lost;
2. takes this Mac out of `Brewfiles/` and every vault group, and hands
   that to the paired Macs;
3. signs off at every paired Mac — each forgets this Mac's key and the
   addresses it reached it by, and accepts nothing from it any more;
4. takes bier off this Mac: the agent and its LaunchAgent, BierMenu, the
   `bier` command, the `PATH` line and the vault passphrase in the
   keychain;
5. asks whether to delete `~/.barrel` as well — the data, the vault
   copies and the backups. Without, it keeps them.

Files from the vault stay where they are, as plain files. Installed
Homebrew packages stay installed. `--dry-run` shows the plan and
changes nothing. It needs a terminal to ask at.

A paired Mac that cannot be reached is named at the end, with what to
run on it: `bier peer remove <this Mac>`, and its address there.

`install.sh --uninstall` runs the same. The blunt alternative is
`rm -rf ~/.barrel`: your files stay, the LaunchAgent removes itself, and
the other Macs are not told.

**See also:** [`retire`](retire.md), [Installation › Uninstalling](../../start/installation.md#uninstalling)
