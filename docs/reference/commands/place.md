[Docs](../../README.md) › [Commands](README.md)

# bier place

```
bier place <package> --all | --on <group>,… | --none [--now]
```

Says where a package belongs: **All Macs** (`--all`, every Mac and every
Mac added later), one or more **groups** (`--on laptops,studio`), or
nowhere (`--none`). bier writes exactly those lists — `main`,
`Brewfiles/@<group>` — and takes the package off every other list,
including the Macs' own lists of what is not assigned. A single Mac is
not a target: give it to its group.

The package need not be on any list or installed anywhere: bier asks
Homebrew or the App Store what it is (`bier search` finds names).

**`--now`** marks the change *install now*: this Mac installs or removes
the package at once, the change goes to every Mac online, and each Mac
that receives it installs and removes what its lists now say — through
its agent as it arrives, or on its next sync when it was away. A group
with the rule `apply ask` only reports it.

Without `--now` only the lists change.

**See also:** [Where software belongs](../../using/placing.md), [`group`](group.md), [`apply`](apply.md)
