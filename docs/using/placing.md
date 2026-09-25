[Docs](../README.md) › Using bier

# Where software belongs

Software goes to **All Macs** or to **groups** — never to a single Mac.
A Mac of its own is a group of one. `bier place` says where a package
belongs; bier writes the lists for it.

```sh
bier place firefox --all                 # every Mac, and every Mac added later
bier place blender --on studio           # the group studio
bier place jq --on laptops,studio        # several groups
bier place nmap --none                   # off every list
```

`place` writes exactly the lists named and takes the package off the
others. It works for a package no Mac has yet: bier asks Homebrew or the
App Store what it is.

## Now, or later

```sh
bier place firefox --on laptops --now
```

Without `--now` only the lists change; each Mac installs or removes when
someone runs `bier install` / `bier prune` there, or `bier apply`.

With `--now` this Mac installs or removes the package at once, the
change goes to every Mac online, and each Mac that receives it brings
itself in line with its lists — right away through its agent, or on its
next sync when it was away. A group whose rule is `apply ask` only
reports it; its Macs install with `bier apply`.

## What was installed by hand

`bier sync` records what someone installs on a Mac on that Mac's own
list: *not assigned*. `bier list` shows it under "Not assigned,
installed on …". Give it to a group or to All Macs with `bier place`, or
remove it with [`bier uninstall --here`](removing.md).

## Finding a name

```sh
bier search firefox
```

lists what Homebrew and the App Store have by that name, and whether it
is on a list already.

In Bierkasten all of this is one panel: select a package, tick All Macs
or groups, choose whether to install right away, apply.
