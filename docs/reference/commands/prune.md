[Docs](../../README.md) › [Commands](README.md)

# bier prune

```
bier prune
```

Uninstalls what is still installed here but was removed on another Mac,
or taken off All Macs while this Mac's group does not keep it. Lists those entries
first and asks.

Taps are removed last, because Homebrew refuses to untap while something
from the tap is still installed. Whatever could not be removed is listed
again at the end.

**See also:** [How removals travel](../../concepts/removals.md)
