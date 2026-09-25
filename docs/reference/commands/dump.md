[Docs](../../README.md) › [Commands](README.md)

# bier dump

```
bier dump [--adopt]
```

Writes `Brewfiles/<host>`: everything installed here that neither All
Macs nor this Mac's group gives it — *not assigned*, until
[`bier place`](place.md) gives it somewhere. [`bier sync`](sync.md) runs it for you; on its own it
commits nothing.

- **Removes nothing.** An entry that is recorded but not installed stays
  — otherwise a package given here by hand would drop out again.
- **Leaves out what was removed elsewhere.** Otherwise a dump would turn
  another Mac's removal into something this Mac keeps on its own.
  `--adopt` takes such entries in deliberately.
- **Never rewrites `main`.**

`bier dump --main` is understood as [`bier main`](main.md).

**See also:** [How removals travel](../../concepts/removals.md)
