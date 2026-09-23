[Docs](../README.md) › Vault

# Groups

Not every file belongs on every Mac. A group names a set of Macs:

```sh
bier vault group laptops mini macbook
bier vault add --for laptops ~/.config/battery-tweaks
```

A Mac outside the group still receives the encrypted copy. It simply
never opens it.

## Commands

| Command | Effect |
| --- | --- |
| `bier vault group` | list the groups, marking the ones this Mac is in |
| `bier vault group <name> <mac>…` | create or redefine a group |
| `bier vault group --drop <name>` | delete a group |
| `bier vault add --for <name> <path>` | add a file for a group |
| `bier vault add --for <mac> <path>` | add a file for one Mac only |

A device name works as a group of one — no need to define it.

## How it is stored

The scope is part of the path: `@laptops/dot_zshrc` goes to the Macs in
`laptops`, `@mini/dot_zshrc` only to `mini`. There is no second list to
keep in step. The group definitions themselves travel encrypted in the
vault as well.

After `--drop`, files under `@<name>/` go to nobody until the group
exists again; `bier vault drop` removes them for good.
[Retiring a Mac](../using/retiring-a-mac.md) takes it out of every
group automatically.
