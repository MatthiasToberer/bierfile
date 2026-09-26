[Docs](../../README.md) › [Commands](README.md)

# bier state

```
bier state [--fetch]
```

Machine-readable state for BierMenu: tab-separated lines such as
`STATE ok|drift`, `INVENTORY automatic|manual`, `NEW`, `STALE`,
`DROPPED`, `GONE`, what the next sync carries (`SEND`, `UNCOMMITTED`,
`VAULT_OUT`, `VAULT_IN`, `VAULT_BOTH`, `VAULT_LEFT`), `VAULTPASS missing|locked`
(the safe holds files this Mac cannot open yet), `VERSION`, and — with
`--fetch`, which also looks for new releases — `NEWCODE <version>` or
`OFFLINE`.

Meant for the app, not for people. Use [`bier status`](status.md).
