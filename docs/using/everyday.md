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
2. encrypts changed vault files into `Safe/`,
3. commits, then exchanges history with every paired Mac and merges,
4. puts new vault files in place on this Mac.

It asks nothing and resolves conflicts on its own. BierMenu's
*Pour a round* runs the same command.

A commit message of your own is optional: `bier sync "set up the
studio"`.

## What differs here?

```sh
bier status
```

```
Installed on mini but not recorded (bier dump):
  + brew "htop"
Removed on another device, still here (bier prune):
  ~ brew "ghidra"
Recorded but not installed on mini (bier install):
  - cask "iterm2"

Git:
  ## main
```

| Mark | Meaning | Next step |
| --- | --- | --- |
| `+` | installed here, not recorded | `bier sync` |
| `~` | removed on another Mac, still here | `bier prune` |
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
