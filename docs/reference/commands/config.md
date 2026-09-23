[Docs](../../README.md) › [Commands](README.md)

# bier config

```
bier config
bier config inventory automatic|manual
```

Shows the settings in effect — config file and environment combined —
and the Macs found in `Brewfiles/`.

`inventory automatic` — the default and the recommended mode — lets
`bier sync` record installed software into this Mac's own list.
`inventory manual` stops that; the Brewfiles stay exactly as you write
them. See [Automatic and manual](../../concepts/lists.md#automatic-and-manual).

**See also:** [Configuration and paths](../configuration.md)
