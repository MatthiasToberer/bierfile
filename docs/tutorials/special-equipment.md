[Docs](../README.md) › Tutorials

# Three Macs: one with special equipment

Three Macs: `mini`, `macbook`, and `studio`, the machine for video
editing. DaVinci Resolve lives on `studio` and has no business on the
other two. So `studio` gets a group of its own:

```sh
bier group desk mini macbook
bier group video studio
```

## Give it to the group that needs it

On any Mac:

```sh
bier place davinci-resolve --on video --now
```

`studio` installs it as the change arrives. On any Mac:

```sh
bier list
```

```
All Macs
  …

Group desk (mini, macbook)
  font-meslo-lg-nerd-font          app

Group video (studio)
  davinci-resolve                  app
```

The other two Macs do **not** nag about Resolve — it is not theirs. A
second editing Mac later only has to join `video` to get it:

```sh
bier group move studio2 video
```

## Later: something turns out to belong everywhere

The font should be on every Mac after all:

```sh
bier place font-meslo-lg-nerd-font --all --now
```

It leaves `desk` and is for All Macs; `studio` installs it as the change
arrives.

## The other direction

Something for All Macs should only be on `studio` — say a large
toolchain:

```sh
bier place toolchain --on video --now
```

It leaves All Macs; `mini` and `macbook` remove it as the change
arrives, `studio` keeps it. Without `--now` they report it after the
next `bier sync` as *no longer for All Macs, still here* and remove it
with `bier prune` — or you keep it for them with another `bier place`.

## Moving a Mac

`macbook` becomes an editing machine too:

```sh
bier group move macbook video
```

It takes on `video` at once: Resolve and the toolchain are installed,
what only `desk` had is removed, and `video`'s files and app settings
replace its own, which stay as a backup. In Bierkasten you drag the Mac
onto the group and see all of that before it moves.

---

**Next:** [Getting rid of something everywhere](removing-everywhere.md)
