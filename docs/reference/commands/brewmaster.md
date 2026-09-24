[Docs](../../README.md) › [Commands](README.md)

# bier brewmaster

```
bier brewmaster
bier doctor
```

Looks this Mac over the way `brew doctor` does, and says for everything
it finds how to put it right. It changes nothing and exits 1 when it
found something.

```
Checking this Mac, its peers and the vault …

Warning: febook does not answer.
  Is it awake, on this network or on Tailscale, and running bier?

Warning: files ending in .hbqueue are shared, and change all the time.
  Add to ~/.barrel/config:  vault_exclude = *.hbqueue

Your bier is ready to pour, apart from 2 thing(s) above.
```

What it checks:

| Area | Findings |
| --- | --- |
| Installation | not moved into `~/.barrel` yet; `~/.barrel/bin` not on the `PATH`; a newer release out; BierMenu older than bier |
| Agent | not installed, or not answering on port 53991 |
| Peers | a paired Mac that does not answer — directly or over SSH — or was never synced with |
| Data | a half-done git rebase, changes not committed, no git name, lines in a Brewfile that are not entries |
| Vault | no passphrase or a locked keychain, a path shared twice, a conflict copy left lying, app settings bier may not read, noise shared as settings (`.hbqueue`, `.sqlite-wal`, journals) |

**See also:** [`status`](status.md), [Troubleshooting](../troubleshooting.md)
