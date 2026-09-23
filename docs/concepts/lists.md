[Docs](../README.md) › Concepts

# main and device lists

Two lists in [Brewfile format](https://docs.brew.sh/Brew-Bundle-and-Brewfile)
together describe what a Mac is supposed to have:

```
Brewfiles/main       what should run on every Mac
Brewfiles/<host>     what this one Mac has on top
```

Both are valid Brewfiles and can be handed straight to
`brew bundle install --file`. **`main` is the main inventory** — the
software every Mac is supposed to have. You create it once, from the
inventory of your template Mac, with
[`bier main`](../reference/commands/main.md).

## Automatic and manual

How the lists are kept up to date depends on the inventory mode.

**Automatic — the default, and the recommended way.** You install
software as usual; `bier sync` records it. What a Mac has beyond `main`
goes into that Mac's own list, so nothing you try out on one Mac is
forced onto the others. When something belongs everywhere, you move it
into `main` with [`bier take`](../using/take.md). `main` changes only
when you decide so.

**Manual — for curating by hand.** `bier sync` records nothing. `main`
and the device lists contain exactly what you write into them, and
`bier install` brings that onto each Mac. Useful for a
[trial run](../start/trial-run.md) or if you want every entry to be a
deliberate choice.

Switch with `bier config inventory automatic|manual` — see
[Configuration](../reference/configuration.md#inventory-mode). The rest
of this documentation assumes automatic mode.

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
