[Docs](../../README.md) › [Commands](README.md)

# bier push

```
bier push [message]
```

Commits `Brewfiles/` and `Safe/` without recording first. With a data
remote configured, it also fetches, merges and pushes; with peers only,
the commit stays local until the next [`bier sync`](sync.md).

Rarely needed — `bier sync` does the same and more.
