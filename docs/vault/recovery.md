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

## A link points nowhere

You deleted `~/.bierfilevault`, or a program replaced a link with a
plain file. `bier status` reports it:

```
  ! link points nowhere: ~/.zshrc
    bier vault --restore puts the links back.
```

```sh
bier vault --restore
```

## Without bier

`Safe/README-recovery.txt` in your data repository is unencrypted and
explains how to get everything back with plain `gpg`:

```sh
gpg -d dot_zshrc.gpg > ~/.zshrc
```

Earlier versions of every file are in the git history of the data
repository.

## Taking bier off a Mac

`install.sh --uninstall` turns every vault link back into a plain file
*before* it removes anything, so no dotfile goes missing. See
[Installation › Uninstalling](../start/installation.md#uninstalling).
