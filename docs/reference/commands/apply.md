[Docs](../../README.md) › [Commands](README.md)

# bier apply

```
bier apply
bier apply --everywhere
bier apply --received
```

Brings this Mac in line with its lists: installs what All Macs and its
group name and it lacks, and removes what was taken off — `bier install`
and `bier prune` in one.

`--everywhere` does it on every Mac: this one at once, the others as
the request reaches them — right away through their agents, or on their
next sync when they are away. That is how software that is on a Mac's
lists but not installed there yet gets installed from another Mac, or
from Bierkasten. A group with `apply ask` only reports it.

`--received` is what the agent and `bier sync` run when changes come
in: it acts only when one of them was marked *install now*
(`bier place … --now`) or this Mac moved to another group, and only
when its group's rule is `apply automatic`.

**See also:** [`place`](place.md), [`group`](group.md)
