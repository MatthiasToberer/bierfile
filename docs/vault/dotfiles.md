[Docs](../README.md) › Vault

# Dotfiles in the vault

Packages are half of what makes a Mac yours. The vault carries the other
half: `.zshrc`, an editor's configuration, notes you want everywhere.

```sh
bier vault add ~/.zshrc
```

The file moves into `~/.bierfilevault` and a symlink stays behind, so it
goes on living where the program that reads it expects it. `bier sync`
encrypts it and shares it; the next `bier sync` on another Mac decrypts
it and puts the link there — or BierMenu does, on its own. Change it on
either Mac and sync, and the others get the change.

A walk-through with two Macs:
[Your dotfiles on a new Mac](../tutorials/dotfiles-on-a-new-mac.md).

## How it is stored

| Where | What |
| --- | --- |
| `~/.bierfilevault` | the plain files, outside every repository |
| `~/bierdata/Safe/` | the encrypted copies — the only part that travels |
| the keychain | this Mac's working copy of the passphrase |

Encryption is gpg, symmetric, AES-256, under **one passphrase all your
Macs share**. A new Mac needs nothing but that passphrase. Because the
plain files live in a different directory, nothing can commit them by
accident.

Names in the vault mirror the path below your home folder, with `dot_`
for a leading dot: `~/.config/nvim/init.lua` is
`dot_config/nvim/init.lua`.

## Commands

| Command | Effect |
| --- | --- |
| `bier vault` | what is in it, and whether this Mac knows the passphrase |
| `bier vault add <path>…` | take files or folders in |
| `bier vault add --for <group> <path>` | only for some Macs — see [Groups](groups.md) |
| `bier vault forget <path>` | take it back out; the real file returns, **on this Mac only** |
| `bier vault drop <path>` | remove it from the vault **everywhere**, after asking |
| `bier vault --restore` | put missing or broken links back |
| `bier vault --init` | enter the passphrase on this Mac |
| `bier vault --passphrase` | change the passphrase everywhere |

`forget` and `drop` are easy to mix up; the difference is the same as
between `dump` and `prune` — here only, or everywhere.

## Folders

A folder is taken in **file by file**. Each file gets its own link and
the folder stays a real folder, so nothing written into it later can
silently land outside the vault — but a new file there is also not in the
vault until you add it.

## When a file already exists

On the receiving Mac, four cases:

| At the destination | bier does |
| --- | --- |
| nothing | links it |
| its own link | nothing, already done |
| a plain file | keeps it as `<name>.backup`, then links — no backup if the two are identical |
| someone else's link | leaves it alone and says so |

## When it changes

Each Mac keeps its own plain copy in `~/.bierfilevault` and remembers
what it and the safe last agreed on. A sync then knows which side
changed:

| Changed | bier sync does |
| --- | --- |
| only here | encrypts it and hands it to the other Macs |
| only elsewhere | puts the new version in place here |
| on both sides | keeps yours and puts the other next to it as `<name>.from-safe` |

After a conflict, merge what you need, delete the `.from-safe` copy and
sync again; your version then goes everywhere. `bier status` lists what
is waiting, see [Everyday use](../using/everyday.md#what-differs-here).

## Why a link

The program reading the file finds it where it always did, and every
edit lands in the vault without an extra step. Editors and tools write
through the link and keep it — checked with vim, `>>`, `sed -i`, Python
and `cp`.
