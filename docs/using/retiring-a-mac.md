[Docs](../README.md) › Using bier

# Retiring a Mac

A Mac leaves the fleet — sold, broken, or wiped without uninstalling
bier first. Its list would otherwise stay in the shared data forever and
show up in `bier list` and `bier take`.

## The Mac is still there

On that Mac:

```sh
~/bierfile/install.sh --uninstall
```

This turns the vault links back into plain files, takes the Mac out of
the lists and every vault group, and removes bier. See
[Installation › Uninstalling](../start/installation.md#uninstalling).

The removal is committed on the leaving Mac. If it is gone before another
Mac has synced with it, run `bier retire <name>` on one of the others.

## The Mac is gone

On any other Mac:

```sh
bier retire studio
```

```
studio has 3 entries of its own.
  in group laptops
Take studio out? [y/N]
```

bier deletes `Brewfiles/studio`, removes the Mac from every vault group
and commits that; `bier sync` passes it on to the other Macs. Vault files meant only for that Mac stay in the
vault. The git history still has everything, should you need it.

You cannot retire the Mac you are sitting at by name — that is what
`install.sh --uninstall` is for.

## Afterwards

Forget the Mac as a peer, so `bier sync` no longer tries to reach it:

```sh
bier peer remove studio.local
```

If the Mac was lost rather than retired in an orderly way, also change
the vault passphrase — the lost Mac knew it:

```sh
bier vault --passphrase
```
