[Docs](../../README.md) › [Commands](README.md)

# bier retire

```
bier retire <name>
```

Takes a Mac out of the fleet: deletes `Brewfiles/<name>`, removes the
Mac from every vault group and commits. Shows what the Mac had and asks
first. Vault files meant only for that Mac stay; the git history keeps
everything.

For the Mac you are sitting at, use `install.sh --uninstall` instead.

**See also:** [Retiring a Mac](../../using/retiring-a-mac.md)
