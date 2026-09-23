[Docs](../../README.md) › [Commands](README.md)

# bier state

```
bier state [--fetch]
```

Machine-readable state for BierMenu: tab-separated lines such as
`STATE ok|drift`, `NEW`, `STALE`, `GONE`, `VERSION`, and — with
`--fetch`, which also looks for new releases — `NEWCODE <version>` or
`OFFLINE`.

Meant for the app, not for people. Use [`bier status`](status.md).
