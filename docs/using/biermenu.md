[Docs](../README.md) › Using bier

# BierMenu

BierMenu shows the state of this Mac in the menu bar without you having
to ask.

| Glass | Meaning |
| --- | --- |
| full, with a head of foam | system and lists agree |
| empty | something differs here |
| level rising and falling | bier is checking or working |

It checks every 15 minutes and whenever you open the menu. The app
computes nothing itself — it calls `bier state` and shows the result.

## The menu

A click lists what differs, grouped by what it costs:

| Section | Action |
| --- | --- |
| installed but not recorded | **Pour a round: record and push** — runs `bier sync` in the background |
| removed elsewhere, still here | **Remove … (in Terminal)** — runs `bier prune` |
| recorded but not installed | **Install missing … (in Terminal)** — runs `bier install` |

Recording is quick and safe, so it happens in the background. Removing
and installing take time, may ask for your password and can fail — they
open a terminal so you can watch.

Further entries:

- **Upgrade … (in Terminal)** — appears when a newer bier release is
  out, or when the app itself is older than the installed `bier`.
- **Check now**, **Start at login**, **Quit**.
- **Info** — version, commit, device name, *Open the guide* and *Show
  folder in Finder*.

## What it deliberately does not show

What **other** Macs have more or less of. It says nothing about whether
there is anything to do on *this* Mac, and it would turn into a wall of
noise past two or three Macs. That is what `bier list` is for.

## When it reports an error

"The inventory server could not be reached" or "The code server could
not be reached" means a fetch failed — usually no network, or a paired
Mac asleep. See [Troubleshooting](../reference/troubleshooting.md).
