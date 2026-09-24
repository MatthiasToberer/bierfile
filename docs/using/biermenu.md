[Docs](../README.md) › Using bier

# BierMenu

A beer glass in the menu bar. It speaks up only when there is something
for you, and syncs without a terminal.

| Glass | Meaning |
| --- | --- |
| full, with a head of foam | nothing to do |
| empty | something arrived from another Mac, or something is wrong |
| level rising and falling | bier is checking or syncing |

It checks every 15 minutes and whenever you open the menu, by calling
`bier state`. That check reads nobody's app settings, so BierMenu needs
no special permission for it.

## The menu

| Section | Means | Action |
| --- | --- | --- |
| *Something needs you* | the last sync failed, a vault file changed on both Macs, or bier may not read an app's settings | read the line; *Allow access …* opens Full Disk Access where that is the cause |
| *settings from another Mac* | vault files a peer delivered | **Sync now** puts them in place |
| *to install* | on this Mac's lists, not installed | **Install … (in Terminal)** — `bier install` |
| *removed on another Mac* | still installed here | **Remove … (in Terminal)** — `bier prune` |

**Sync now** is always there: it runs `bier sync` in the background —
records, exchanges with the paired Macs, puts arrived settings in place.
Installing and removing software open a terminal, because they take
long, may ask for your password and are worth watching.

Further entries: **Upgrade … (in Terminal)** when a newer release is
out, **Start at login**, **Info** (version, device, the guide) and
**Quit**.

## Full Disk Access

Only when *Sync now* has to read or write an app's settings inside its
sandbox (`~/Library/Containers/…`, HandBrake for example) does BierMenu
need Full Disk Access — macOS counts what bier does as BierMenu's doing.
The menu then says so and offers *Allow access …*; see
[`bier access`](../reference/commands/access.md). Without it, those
settings are simply left alone.

## What it deliberately does not show

What waits to go out, what is installed here but on no list, and what
other Macs have. None of it needs you: the next sync carries it, or it
is your choice. `bier status` and `bier list` show it all.
