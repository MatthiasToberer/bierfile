[Docs](../README.md) › Concepts

# main and device lists

Two lists in [Brewfile format](https://docs.brew.sh/Brew-Bundle-and-Brewfile)
together describe what a Mac is supposed to have:

```
Brewfiles/main       what should run on every Mac
Brewfiles/<host>     what this one Mac has on top
```

Both are valid Brewfiles and can be handed straight to
`brew bundle install --file`. You create `main` once, from the inventory
of your template Mac, with [`bier main`](../reference/commands/main.md).
After that, every Mac writes only its own list of extras.

## The rule

> **A device list can only add, never subtract.**

Anything a Mac must explicitly *not* have therefore cannot live in
`main` — it belongs in the lists of the Macs that want it. That sounds
like a limitation, but it spares a whole class of special cases: there is
no exclusion list, no "minus", nothing that changes meaning when `main`
grows. [`bier take`](../using/take.md) moves entries in both directions
when you change your mind.

## Who writes what

| List | Adds entries | Removes entries |
| --- | --- | --- |
| `Brewfiles/<host>` | `bier dump` (and so `bier sync`), `bier take` | `bier take`, `bier uninstall`, `bier retire` |
| `Brewfiles/main` | `bier main`, `bier take` | `bier main`, `bier take`, `bier uninstall` |

`bier dump` reads `main` but never rewrites it. Whatever you install
lands in this Mac's list; promoting it to every Mac is always your
decision.

## What bier compares

For this Mac, bier takes `main` plus this Mac's list and holds it against
what Homebrew reports as installed. Three kinds of difference come out:

| Kind | Meaning | Fixed by |
| --- | --- | --- |
| installed but not recorded | new here | `bier sync` |
| removed elsewhere, still here | another Mac removed it | `bier prune` |
| recorded but not installed | on this Mac's lists, missing here | `bier install` |

What *other* Macs have on top is deliberately not a difference: it says
nothing about whether there is anything to do here. `bier list` shows it.

## Where the lists live

Not in the program repository. The lists reveal which software runs on
your Macs, so they live in a private local repository — `~/bierdata` by
default — and travel only to Macs you have paired. See
[Configuration and paths](../reference/configuration.md).
