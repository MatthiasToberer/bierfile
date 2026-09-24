[Docs](../../README.md) › [Commands](README.md)

# bier access

```
bier access
```

Explains, and opens, what macOS needs before bier can read an app's
settings inside its sandbox container (`~/Library/Containers/…`): **Full
Disk Access**, granted by you in System Settings › Privacy & Security —
for the terminal bier runs in, and for `~/.barrel/BierMenu.app`, which
runs bier on its own. It opens that pane and shows BierMenu in the
Finder, so you can drag it into the list.

Without it, `bier status` marks such settings `no access`, and a sync
leaves them alone — they are never taken for deleted. BierMenu offers
*Allow access …* for the same.

BierMenu is signed on your Mac only; after `bier upgrade` macOS may ask
again.
