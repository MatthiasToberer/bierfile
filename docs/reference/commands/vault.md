[Docs](../../README.md) › [Commands](README.md)

# bier vault

```
bier vault
bier vault add [--for <group>] <path>…
bier vault forget <path>…
bier vault drop <path>…
bier vault group …           the same as bier group
bier vault --restore
bier vault --init
bier vault --passphrase
```

| Command | Effect |
| --- | --- |
| `bier vault` | where the vault is, how many files it holds, whether the passphrase is known here |
| `add` | take files or folders in; they stay where they are, the vault keeps a copy. A folder is tracked as a whole |
| `add --for` | only for a group or one Mac |
| `forget` | stop syncing it; the file stays on every Mac |
| `drop` | out of the vault and off every Mac, into the Trash, after asking |
| `group` | list, define or drop groups |
| `--restore` | put back a file deleted here, from the vault's copy |
| `--init` | enter the passphrase on this Mac (the installer does this); `--init --stdin` takes it from standard input, checked against the safe — the menu bar glass asks this way |
| `--passphrase` | change the passphrase and re-encrypt everything |

Only files below your home folder can go into the vault.

`bier sync` seals a file only when it changed on this Mac, and takes the
safe's version only when it changed elsewhere. When a file changed on
both sides, nothing is overwritten: the other version is put next to it
as `<file>.from-safe`. Merge what you need; the next sync distributes
the file as it is then. A Mac that has not synced its vault since this
behaviour arrived treats every difference that way once.

**See also:** [Vault](../../vault/dotfiles.md), [Groups](../../vault/groups.md),
[Passphrase and recovery](../../vault/recovery.md)
