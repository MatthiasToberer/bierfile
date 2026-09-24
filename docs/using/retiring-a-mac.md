[Docs](../README.md) › Using bier

# Retiring a Mac

A Mac leaves the fleet — sold, broken, or wiped without uninstalling
bier first. Its list would otherwise stay in the shared data forever and
show up in `bier list` and `bier take`.

## The Mac is still there

On that Mac:

```sh
bier knockout
```

This syncs one last time, takes the Mac out of the lists and every vault
group, hands that to the other Macs, signs off at each of them — they
forget its key and address — and removes bier. The files from the vault
stay where they are. See
[Installation › Uninstalling](../start/installation.md#uninstalling).

A Mac that could not be reached at that moment is named, with what to
run there: `bier peer remove <name>`, and `bier retire <name>` if the
removal has not reached it through the others.

## The Mac is gone

On every other Mac, so they stop trusting it and stop trying to reach it:

```sh
bier peer remove studio          # its key
bier peer remove studio.local    # the address it was paired with (bier peer list)
```

And on any one of them:

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
`bier knockout` is for.

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
