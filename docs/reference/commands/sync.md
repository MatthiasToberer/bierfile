[Docs](../../README.md) › [Commands](README.md)

# bier sync

```
bier sync [--record] [message]
```

The everyday command. Run it after every install.

1. Records what is installed here and not on a list yet
   ([`bier dump`](dump.md)). In manual inventory mode this step is
   skipped and the Brewfiles stay as you wrote them, unless you pass
   `--record`.
2. Encrypts changed vault files into `Safe/`.
3. Commits `Brewfiles/` and `Safe/`, then exchanges history with every
   paired Mac and merges. Each peer is visited twice, so the common
   result reaches all of them.
4. Puts new or changed vault files in place on this Mac.

It asks nothing and resolves list conflicts itself — see
[When two Macs change at once](../../concepts/conflicts.md). If a paired
Mac cannot be reached, it stops with an error; see
[Troubleshooting](../troubleshooting.md).

The optional message replaces the default commit message
`<host>: inventory updated`.

Without paired Macs, `sync` works against the data repository's `origin`
if one is configured, and otherwise only commits locally.

**See also:** [`status`](status.md), [`peer sync`](peer.md)
