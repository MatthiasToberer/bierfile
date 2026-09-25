[Docs](../../README.md) › [Commands](README.md)

# bier share

```
bier share [--for <group>] <app>
```

Shares an installed app's settings and profiles with All Macs, or with
one group. bier looks where [`bier add`](add.md) looks — the cask's zap
list, the sandbox container, Application Support, Preferences,
`~/.config/<name>` — and takes all of it without asking. Anything that
may hold keys, passwords or accounts stays out, and VPN clients and
password managers are not offered at all.

The app has to be installed on this Mac: the settings are read from
here.

**See also:** [Files for a group](../../vault/groups.md)
