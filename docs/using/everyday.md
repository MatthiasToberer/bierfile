[Docs](../README.md) › Using bier

# Everyday: sync and status

## One command after every install

```sh
bier sync
```

In order, it:

1. records what is installed here that is not on a list yet
   ([`bier dump`](../reference/commands/dump.md)) — skipped in
   [manual inventory mode](../reference/configuration.md#inventory-mode),
2. encrypts vault files changed on this Mac into `Safe/`,
3. commits, then exchanges history with every paired Mac and merges,
4. puts vault files that are new or changed elsewhere in place on this
   Mac.

It asks nothing and resolves conflicts on its own. BierMenu's
BierMenu's *Sync now* runs the same command.

A commit message of your own is optional: `bier sync "set up the
studio"`.

## What differs here?

```sh
bier status
```

```
Sync (bier sync):
  -> to macbook       1 commit(s) from here not sent yet
  ^  vault            /Users/you/.zshrc changed here
  v  vault            /Users/you/.gitconfig newer in the safe

Installed on mini but not recorded (bier sync):
  + brew "htop"
Removed on another device, still here (bier prune):
  ~ brew "ghidra"
No longer in main, still here (bier prune, or bier take to keep it):
  ~ brew "nmap"
Recorded but not installed on mini (bier install):
  - cask "iterm2"

Git:
  ## main
```

The first block is what the next `bier sync` would carry, Brewfiles and
vault alike:

| Mark | Meaning | Next step |
| --- | --- | --- |
| `->` | commits made here that a paired Mac has not had yet | `bier sync` |
| `^` | changed here: a Brewfile not committed, a vault file edited | `bier sync` |
| `v` | a paired Mac delivered a newer vault file | `bier sync` (BierMenu does it on its own) |
| `!` | a vault file changed on both sides, or a `.from-safe` copy left from that | merge, delete the copy, `bier sync` |

It uses only what this Mac knows; nothing is asked over the network.
The rest compares this Mac with its lists:

| Mark | Meaning | Next step |
| --- | --- | --- |
| `+` | installed here, not recorded | `bier sync` (manual inventory: `bier sync --record`) |
| `~` | removed on another Mac, still here | `bier prune` |
| `~` | taken out of `main`, another Mac keeps it | `bier prune`, or `bier take` to keep it |
| `-` | recorded for this Mac, not installed | `bier install` |

`bier status` also warns about vault links that point nowhere and about
lines in a Brewfile that are not package entries — see
[Troubleshooting](../reference/troubleshooting.md).

## What do the others have?

```sh
bier list             # main, every Mac's extras, and who has what
bier diff             # this Mac against each other Mac
bier diff studio      # against one
```

What other Macs have on top never counts as a difference *here*. To
adopt something: [`bier take`](take.md).

## Keeping bier itself current

```sh
bier upgrade
```

Separate from `sync` on purpose: `sync` is about your Macs, `upgrade`
about the program. It never touches your lists. See
[Installation › Upgrading](../start/installation.md#upgrading).
