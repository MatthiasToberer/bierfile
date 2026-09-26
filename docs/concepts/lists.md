[Docs](../README.md) › Concepts

# All Macs, groups, and what is not assigned

Every Mac is in exactly one [group](groups.md). What it is supposed to
have comes from three lists in [Brewfile format](https://docs.brew.sh/Brew-Bundle-and-Brewfile):

```
Brewfiles/main       All Macs — every Mac, and every Mac added later
Brewfiles/@<group>   what the group's Macs have on top
Brewfiles/<host>     what this one Mac has installed that nobody has
                     given to All Macs or a group yet: not assigned
```

All are valid Brewfiles and can be handed straight to
`brew bundle install --file`. You create `main` once, from the software
of your template Mac, with [`bier init`](../reference/commands/init.md).
From then on you give software to All Macs or to groups with
[`bier place`](../reference/commands/place.md) — never to a single Mac.
A Mac of its own is a group of one.

## Automatic and manual

What a group's Macs do with software installed by hand is a rule of the
group (`bier group rule <group> inventory automatic|manual`).

**Automatic — the default.** You install software as usual; `bier sync`
records it on that Mac's own list, *not assigned*. Nothing you try out
on one Mac is forced onto the others. When it belongs to a group or to
All Macs, `bier place` gives it there.

**Manual — for curating by hand.** `bier sync` records nothing. The
lists contain exactly what you give them, and `bier install` brings
that onto each Mac. Useful for a [trial run](../start/trial-run.md) or if
every entry should be a deliberate choice.

## The rule

> **Lists only add, never subtract.**

A Mac has All Macs plus its group plus what it recorded. Anything a Mac
must *not* have therefore cannot be for All Macs — it belongs to the
groups that want it. That spares a whole class of special cases: no
exclusion list, no "minus", nothing that changes meaning when All Macs
grows. `bier place` moves entries between All Macs and groups whenever
you change your mind.

## Who writes what

| List | Adds entries | Removes entries |
| --- | --- | --- |
| `Brewfiles/main` (All Macs) | `bier init`, `bier place --all`, `bier add --all` | `bier init`, `bier place`, `bier uninstall` |
| `Brewfiles/@<group>` | `bier place --on`, `bier add --group` | `bier place`, `bier uninstall --group`, `bier group --drop` |
| `Brewfiles/<host>` (not assigned) | `bier dump` (and so `bier sync`), `bier add --here` | `bier place`, `bier uninstall`, `bier retire` |

## What bier compares

For this Mac, bier takes All Macs, its group and what it recorded, and
holds that against what Homebrew reports as installed:

| Kind | Meaning | Fixed by |
| --- | --- | --- |
| installed but not recorded | new here | `bier sync` (manual mode: `bier sync --record`) |
| removed elsewhere, still here | taken off a list this Mac follows | `bier prune`, or `bier apply` |
| no longer for All Macs, still here | taken off All Macs, its group does not keep it | `bier prune`, or `bier place` to keep it |
| recorded but not installed | on this Mac's lists, missing here | `bier install`, or `bier apply` |

A change marked *install now* (`bier place … --now`, or moving a Mac to
another group) is applied by each Mac as it arrives, unless its group's
rule says `apply ask`.

## Where the lists live

Not in the program repository. The lists reveal which software runs on
your Macs, so they live in a private local repository — `~/.barrel/data` by
default — together with the `groups` file, and travel only to Macs you
have paired. See [Configuration and paths](../reference/configuration.md).
