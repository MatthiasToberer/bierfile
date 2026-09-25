[Docs](../README.md) › Vault

# Files for a group

Files and app settings go to All Macs or to a group, like software. The
groups are the same everywhere — see [Groups](../concepts/groups.md):

```sh
bier group laptops mabook febook              # every Mac is in one group
bier vault add --for laptops ~/.config/battery-tweaks
bier share --for laptops handbrake-app        # an app's settings
```

A Mac outside the group still receives the encrypted copy. It simply
never opens it.

## When a Mac changes groups

It takes on its new group at once: the new group's files and settings
are put in place — its own versions are kept as a backup next to them —
and the old group's files stay on the Mac as they are, no longer kept in
step.

## How it is stored

The scope is part of the path: `@laptops/dot_zshrc` goes to the Macs in
`laptops`. There is no second list to keep in step. Which Macs are in
which group is kept in `groups` in the data repository.

`bier vault group` still works: it is `bier group` by its old name.
After `bier group --drop <name>`, files under `@<name>/` go to nobody
until the group exists again; `bier vault drop` removes them for good.
[Retiring a Mac](../using/retiring-a-mac.md) takes it out of its group
automatically.
