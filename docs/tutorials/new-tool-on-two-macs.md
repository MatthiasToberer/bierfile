[Docs](../README.md) › Tutorials

# Two Macs: installing something new

The everyday case. Two Macs, `mini` and `macbook`, set up, paired, and
in one group, `desk`:

```sh
bier group desk mini macbook
```

You install a tool on one and decide it belongs on both.

## Straight to where it belongs

```sh
bier place ripgrep --on desk --now
```

ripgrep is installed on this Mac at once, goes to every Mac online, and
each Mac in `desk` installs it as soon as the change arrives. A Mac that
was switched off installs it on its next sync. `--all` instead of
`--on desk` would give it to every Mac, and every Mac added later.

## Or the other way round: try it first

Install it as usual:

```sh
brew install ripgrep
bier sync
```

`bier sync` records ripgrep on mini, **not assigned**: nothing you try
out on one Mac is forced onto the others. `bier list` shows it:

```
All Macs
  …

Group desk (mini, macbook)
  …

Not assigned, installed on mini (this Mac)
  ripgrep                          formula
```

When it has earned its place:

```sh
bier place ripgrep --on desk --now
```

It leaves mini's own list and goes to the group; macbook installs it as
the change arrives.

## What happened

- A new package lands on the list of the Mac it was installed on, not
  assigned. bier never gives it to a group or to All Macs on its own —
  that decision is yours, and `bier place` is where you make it.
- Software goes to All Macs or to groups, never to a single Mac. With
  two Macs a group of two is enough; with a third you decide whether it
  joins `desk` or gets a group of its own.
- The rules behind this: [Groups](../concepts/groups.md) and
  [All Macs, groups, and what is not assigned](../concepts/lists.md).

---

**Next:** [Three Macs: one with special equipment](special-equipment.md)
