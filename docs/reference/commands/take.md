[Docs](../../README.md) › [Commands](README.md)

# bier take

```
bier take
bier take --from-main
```

Interactive. Moves entries between `main` and the device lists.

- **`bier take`** lists what other Macs have on top of `main`. Pick
  entries (`1 3-5`), then choose **`m`** — into `main`, removed from the
  device lists — or **`h`** — into this Mac's own list, the others keep
  theirs.
- **`bier take --from-main`** lists `main`. Pick entries, then the Mac
  to hand them to.

bier shows the plan and asks before changing anything, commits, and
offers to install the picks here. The other Macs see the change after
the next `bier sync`.

**See also:** [Adopting entries](../../using/take.md)
