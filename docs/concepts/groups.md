[Docs](../README.md) › Concepts

# Groups

Every Mac is in exactly one group. Everything bier keeps in step goes to
**All Macs** or to a **group** — software, files, app settings and the
rules for how a Mac takes changes. A Mac has All Macs plus its group,
nothing in between. With one Mac that is a group of one; with a hundred
it is still a handful of groups to look at.

```sh
bier group                          # the groups, their Macs and rules
bier group laptops mabook febook    # exactly these Macs; they leave their old group
bier group move minima studio       # one Mac to another group
bier group rule laptops apply ask   # automatic (default) or ask
bier group rule laptops inventory manual
bier group --drop laptops           # its Macs become new
```

A Mac in no group is **new** — a freshly paired one, until it is moved.

## Software to a group

```sh
bier place firefox --all            # every Mac, and every Mac added later
bier place blender --on studio      # the group studio, and who joins it later
bier place jq --on laptops,studio   # several groups
bier place nmap --none              # off every list
bier place firefox --on laptops --now
```

`place` writes exactly the lists named and takes the package off the
others. A single Mac is not a target: give it to its group. `--now`
marks the change *install now*: this Mac installs or removes the
package at once, and every Mac that receives the change — through its
agent, or on its next sync when it was away — brings itself in line with
its lists. A group with `apply ask` only reports it; its Macs install
with `bier apply`.

What someone installs by hand on a Mac is recorded on that Mac's own
list: *not assigned*. Give it to a group or to All Macs with `place`.

## Moving a Mac

When a Mac moves, it takes on its new group's rules as soon as the
change reaches it: the new group's software is installed, what only the
old group had is removed, and the new group's files and app settings
replace its own — which are kept as a backup next to them. An app that
is running is left until it quits.

## Where it is kept

`groups` in the data repository, one line each — `laptops = mabook
febook`, `laptops.apply = ask`. Software given to a group is in
`Brewfiles/@laptops`, files in the vault under `@laptops/`. Before bier
kept groups, each Mac had a list of its own; the first time, every such
Mac becomes a group of its own holding that list, so nothing is lost.
