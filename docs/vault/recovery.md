[Docs](../README.md) › Vault

# Passphrase and recovery

## The passphrase

- One passphrase for all your Macs. Each Mac keeps a working copy in its
  keychain.
- **It cannot be recovered.** Before you put anything in the vault, store
  a copy somewhere that is not these Macs — your password manager, or a
  note in a drawer. Lose it and the vault is scrap paper.
- The installer asks for it once per Mac. Skipped? `bier vault --init`.

### Changing it

```sh
bier vault --passphrase
```

Re-encrypts everything under the new passphrase — into a staging area
first, so a change that dies halfway cannot leave half the vault
unreadable. Every other Mac asks for the new one on its next sync.

Change it whenever a Mac that knew it is lost or leaves your hands.

## A file was deleted by mistake

A vault file deleted here counts as deleted everywhere: the next sync
takes it out of the safe, and the other Macs move theirs to the Trash.
`bier status` shows it first:

```
  ^  vault            ~/.zshrc deleted here
```

Before syncing, put it back from the vault's copy:

```sh
bier vault --restore
```

After a sync, it is in the Trash on the other Macs, and in
`~/.barrel/state/backups/` wherever bier replaced it.

## Without bier

`Safe/README-recovery.txt` in your data repository is unencrypted and
explains how to get everything back with plain `gpg`:

```sh
gpg -d dot_zshrc.gpg > ~/.zshrc
```

Earlier versions of every file are in the git history of the data
repository.

## Taking bier off a Mac

The files from the vault are real files where they belong, so nothing
goes missing when bier leaves — neither with `bier knockout` nor with
`rm -rf ~/.barrel`. See
[Installation › Uninstalling](../start/installation.md#uninstalling).
