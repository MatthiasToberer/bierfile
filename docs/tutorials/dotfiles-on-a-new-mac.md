[Docs](../README.md) › Tutorials

# Your dotfiles on a new Mac

Packages are half of what makes a Mac yours. The other half is files:
`.zshrc`, an editor's configuration, the notes you want everywhere. This
tutorial puts them in the vault on one Mac and has them appear on
another.

You need two paired Macs, `mini` and `macbook`, both installed with the
**same** vault passphrase. (Skipped it during installation? Set it with
`bier vault --init`.)

## On mini: into the vault

```sh
bier vault add ~/.zshrc
bier vault add ~/.config/nvim
```

Look at what happened:

```sh
ls -l ~/.zshrc
```

```
~/.zshrc -> ~/.bierfilevault/dot_zshrc
```

The file moved into `~/.bierfilevault` and a link stayed behind. zsh
follows it and notices nothing; you edit `~/.zshrc` exactly as before.

A folder such as `~/.config/nvim` is taken in **file by file**: each file
gets its own link, and the folder itself stays a real folder. A file you
create in it later is not in the vault until you `bier vault add` it too.
Only files below your home folder can go into the vault.

Share it:

```sh
bier sync
```

bier encrypts both into `Safe/` in your data repository and exchanges
them with macbook. The plain files never leave `~/.bierfilevault`.

## On macbook: out of the vault

```sh
bier sync
```

```
kept: ~/.zshrc.backup
linked: ~/.zshrc
linked: ~/.config/nvim/init.lua
```

macbook had a `.zshrc` of its own. It is not thrown away but kept as
`~/.zshrc.backup`. Had the two been identical, there would be nothing to
save and no backup is made. A `.zshrc` that was already a link to
somewhere else is left alone, and bier says so.

From now on it is one file on two Macs: change it on either, `bier sync`,
and the other has the change.

## Only for some Macs

The mini is a desktop tower; a laptop-only setting has no business
there:

```sh
bier vault group laptops macbook
bier vault add --for laptops ~/.config/battery-tweaks
```

mini receives the encrypted copy like everything else, but never opens
it. More in [Groups](../vault/groups.md).

## Taking something back out

```sh
bier vault forget ~/.zshrc    # the real file returns; it stays on this Mac
bier vault drop ~/.zshrc      # gone from the vault everywhere, after asking
```

They are easy to confuse and the consequences differ — `forget` is local,
`drop` affects every Mac.

## Before you rely on it

**Write the passphrase down somewhere that is not these Macs.** It cannot
be recovered, and without it the vault is scrap paper. What to do if
something goes wrong: [Passphrase and recovery](../vault/recovery.md).

---

**Back to:** [Documentation](../README.md)
