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

Nothing moves: `~/.zshrc` stays a plain file where it was, and you edit
it exactly as before. The vault keeps a copy in `~/.barrel/vault`.

A folder such as `~/.config/nvim` is tracked as a whole: a file you
create in it later comes along with the next sync, and one you delete
there goes to the Trash on the other Macs. Only files below your home
folder can go into the vault.

Share it:

```sh
bier sync
```

bier encrypts them into `Safe/` in your data repository and exchanges
them with macbook. Only the encrypted copies leave this Mac.

## On macbook: out of the vault

```sh
bier sync
```

```
kept: ~/.zshrc.backup
added: ~/.zshrc
added: ~/.config/nvim/init.lua
```

macbook had a `.zshrc` of its own. It is not thrown away but kept as
`~/.zshrc.backup`. Had the two been identical, there would be nothing to
save and no backup is made. A `.zshrc` that was a link to somewhere
else is left alone, and bier says so.

## Changing it later

Edit `~/.zshrc` on mini. Before anything travels, `bier status` says so:

```
Sync (bier sync):
  ^  vault            /Users/you/.zshrc changed here
```

`bier sync` on mini encrypts the change and hands it to macbook. It
arrives there encrypted: macbook's `~/.zshrc` changes only when macbook
opens the safe, because only macbook's keychain holds the passphrase.
Until then its `bier status` shows

```
Sync (bier sync):
  v  vault            /Users/you/.zshrc newer in the safe
```

and BierMenu on macbook puts it in place on its own at the next check.
In a terminal, `bier sync` on macbook does the same.

## Changed on both Macs

If both Macs edit the file before either syncs, bier overwrites
neither. The Mac that syncs second keeps its own version and gets the
other one next to it:

```
changed here and on another Mac: /Users/you/.zshrc
  the other version is in /Users/you/.zshrc.from-safe
  merge what you need into /Users/you/.zshrc; the next sync keeps it as it is then
```

Take what you need from `~/.zshrc.from-safe`, delete it, and
`bier sync`: your merged file goes to every Mac. `bier status` reminds
you of a copy left lying around.

## Only for some Macs

The mini is a desktop tower; a laptop-only setting has no business
there:

```sh
bier group laptops macbook
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
