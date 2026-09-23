[Docs](../../README.md) › [Commands](README.md)

# bier dump

```
bier dump [--adopt]
```

Writes `Brewfiles/<host>`: everything installed here that is not already
in `main`. [`bier sync`](sync.md) runs it for you; on its own it
commits nothing.

- **Removes nothing.** An entry that is recorded but not installed stays
  — otherwise you would lose what [`bier take`](take.md) just picked.
- **Leaves out what was removed elsewhere.** Otherwise a dump would turn
  another Mac's removal into a device-specific installation.
  `--adopt` takes such entries in deliberately.
- **Never rewrites `main`.**

`bier dump --main` is understood as [`bier main`](main.md).

**See also:** [How removals travel](../../concepts/removals.md)
