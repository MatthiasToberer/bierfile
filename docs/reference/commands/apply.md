[Docs](../../README.md) › [Commands](README.md)

# bier apply

```
bier apply
bier apply --received
```

Brings this Mac in line with its lists: installs what All Macs and its
group name and it lacks, and removes what was taken off — `bier install`
and `bier prune` in one.

`--received` is what the agent and `bier sync` run when changes come
in: it acts only when one of them was marked *install now*
(`bier place … --now`) or this Mac moved to another group, and only
when its group's rule is `apply automatic`.

**See also:** [`place`](place.md), [`group`](group.md)
