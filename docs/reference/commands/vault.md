[Docs](../../README.md) › [Commands](README.md)

# bier vault

```
bier vault
bier vault add [--for <group|mac>] <path>…
bier vault forget <path>…
bier vault drop <path>…
bier vault group [<name> <mac>… | --drop <name>]
bier vault --restore
bier vault --init
bier vault --passphrase
```

| Command | Effect |
| --- | --- |
| `bier vault` | where the vault is, how many files it holds, whether the passphrase is known here |
| `add` | move files or folders (file by file) into the vault, leave links behind |
| `add --for` | only for a group or one Mac |
| `forget` | the real file returns; out of the vault, stays on this Mac |
| `drop` | out of the vault and off every Mac, after asking |
| `group` | list, define or drop groups |
| `--restore` | put missing or broken links back |
| `--init` | enter the passphrase on this Mac (the installer does this) |
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
