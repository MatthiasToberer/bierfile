[Docs](../../README.md) › [Commands](README.md)

# bier group

```
bier group
bier group <group> <mac>…
bier group move <mac> <group>
bier group rule <group> apply automatic|ask
bier group rule <group> inventory automatic|manual
bier group --drop <group>
```

Every Mac is in exactly one group; a Mac in none is *new*.

- **`bier group`** lists the groups, their Macs and rules, marks the one
  this Mac is in, and names the new Macs.
- **`bier group <group> <mac>…`** makes the group exactly these Macs.
  They leave their old groups; former members not named become new.
- **`bier group move <mac> <group>`** moves one Mac.
- **`bier group rule …`** sets how the group's Macs take changes:
  `apply automatic` (default) installs and removes what arrives marked
  *install now*, `apply ask` only reports it; `inventory automatic`
  (default) records what someone installs by hand, `manual` does not.
- **`bier group --drop <group>`** deletes the group and the software
  given to it; its Macs become new.

Every change goes out at once. A Mac that moved takes on its new group
as soon as the change reaches it: the group's software is installed,
what only the old group had is removed, and the group's files and app
settings are put in place over its own, which are kept as a backup.

`bier vault group` is the same command by its old name.

**See also:** [Groups](../../concepts/groups.md)
