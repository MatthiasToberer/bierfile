[Docs](../../README.md) › [Commands](README.md)

# bier undo

```
bier undo <commit>
```

Takes back one change: a new change that undoes it, passed on to every
Mac like any other. The commit is the short name `bier report` and
`git log` show, and what Bierkasten's *Activity* offers as **Undo**.

A change marked *install now* is undone the same way: this Mac and every
Mac that receives the undo remove what it installed, and install what it
removed. A change that later changes build on is refused rather than
half undone.
