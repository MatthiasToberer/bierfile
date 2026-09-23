# bier

**Keeps the software inventory of several Macs identical** — with
Homebrew, a git repository and a beer glass in the menu bar.

> **On the name.** *bier* is German for *beer*, and the glass in the menu
> bar fills up when everything is in order. It is also a thank-you to
> [Homebrew](https://brew.sh): no brew, no beer. `bier` is a thin layer
> on top of `brew bundle` and would not exist without the work of the
> Homebrew maintainers.

You install something on the desktop machine, forget about it, and six
months later it is missing on the laptop. `bier` writes down what is
installed, keeps that list in a git repository, and tells you on every
device what differs — **full** means everything is in order, **empty**
means there is something to do here.

It is a shell script with no dependencies beyond Homebrew and git, plus a
small menu bar app in Swift. Nothing runs in the cloud, nothing phones
home; your lists live in a repository that belongs to you.

> [!WARNING]
> **Make a backup before you use `bier` for the first time.**
>
> `bier` installs and **uninstalls** software on your Mac — `bier
> uninstall`, `bier prune` and `bier install` really do reach through.
> Removing a program can take its settings and data with it, and a wrong
> entry in a list affects *all* of your devices.
>
> This is a hobby project, provided without any warranty. Use it at your
> own risk; I accept no liability for lost data or removed software. Keep
> a working backup — Time Machine or something equivalent — and make sure
> it actually works.

---

## What it does

- **Record and sync.** `bier sync` writes down what is on this Mac and
  pushes it to the others.
- **Show the differences.** What is installed here but recorded nowhere?
  What is on the list but missing from this device?
- **Allow differences.** Not everything belongs everywhere. A device may
  have extras without them being forced on the others.
- **Carry removals across.** A plain "what is installed" snapshot cannot
  do that. `bier` uses the git history to tell whether a program was
  newly added or removed elsewhere — and treats the two differently.
- **Work without git knowledge.** `bier sync` fetches, pushes and merges;
  `bier upgrade` puts a newer program in place. Neither asks anything nor
  demands anything.
- **Sit in the menu bar.** One glance tells you whether this Mac differs.

## How it works

Two lists in
[Brewfile format](https://docs.brew.sh/Brew-Bundle-and-Brewfile) together
describe what a device is supposed to have:

    Brewfiles/main       what should run on every Mac
    Brewfiles/<host>     what this one Mac has on top

Both are valid Brewfiles and can be handed straight to
`brew bundle install --file`. You create `main` once from the inventory
of your main machine; after that every Mac only writes its own list of
extras.

From this follows the rule that carries everything: **a device file can
only add, never subtract.** So anything a device must explicitly *not*
have cannot live in `main`. That sounds like a limitation, but it spares
you a whole class of special cases — and `bier take` moves entries in
both directions when you change your mind.

## Requirements

- macOS with [Homebrew](https://brew.sh)
- the Command Line Tools (`xcode-select --install`) for the app
- an **empty, private git repository** for your lists, reachable over SSH
  from every device — GitHub, a NAS or a server of your own

Keep that repository private: your lists reveal which software runs on
your machines.

## Installation

On the Mac whose software should serve as the template:

```sh
git clone https://github.com/MatthiasToberer/bierfile.git ~/bierfile
~/bierfile/install.sh
```

`install.sh` checks the requirements, makes `bier` callable, asks for the
address of your private repository, builds the menu bar app and records
this Mac's inventory. The address can also be passed in:

```sh
~/bierfile/install.sh --data git@github.com:yourname/bierfile.git
```

Then, once and only once, set the shared baseline:

```sh
bier main
```

On every further Mac the same `git clone` and `install.sh`, but
**instead** of `bier main`:

```sh
bier install    # brings the software from main onto this device
bier sync       # records what this Mac has on top
```

Step by step and assuming nothing: **[GUIDE.md](GUIDE.md)**.

## Everyday use

```sh
bier sync              # record here and exchange directly with your peers
bier status            # what differs here?
bier list              # what do the others have on top?
bier take              # adopt some of it
bier uninstall ghidra  # get rid of it everywhere
bier prune             # remove here what was deleted elsewhere
bier upgrade           # put a newer bier in place
```

Most of the time you only need the first one.

## Files, not only packages

Packages are half of what makes a Mac yours. The other half is the
files: `.zshrc`, an editor's configuration, notes you want everywhere.

```sh
bier vault add ~/.zshrc
```

The file moves into the vault and a symlink stays behind, so it goes on
living where the program that reads it expects it. `bier sync` encrypts
it and uploads it; the next `bier sync` on another Mac decrypts it and
puts the link there. Editing it on either Mac edits the same file.

Encrypted with gpg, AES-256, under **one passphrase your Macs share**.
A new Mac needs nothing but that passphrase. The plain files live in
`~/.bierfilevault`, outside every repository, so nothing can commit
them by accident.

Not everything belongs on every Mac:

```sh
bier vault group laptops mini macbook
bier vault add --for laptops ~/.zshrc
```

A Mac outside the group still receives the encrypted copy. It simply
never opens it.

**The passphrase cannot be recovered.** Keep a copy where you keep your
other passwords, before you put anything in the vault. `Safe/`
carries an unencrypted note explaining how to get the files back with
`gpg` alone, without bier.

## Commands

| Command | what it does |
| --- | --- |
| `bier dump [--adopt]` | record what this Mac has on top of `main` |
| `bier sync [message]` | `dump`, commit, exchange directly with peers — the everyday command |
| `bier upgrade [--force]` | install a newer release of `bier` itself |
| `bier status` | check the system against the lists |
| `bier list` | overview of all devices |
| `bier diff [host…]` | compare the inventory with other devices |
| `bier install` | bring `main` and this device's own list onto the system |
| `bier take` | pull entries from other devices into `main` or here |
| `bier take --from-main` | hand an entry from `main` to a single device |
| `bier main` | create `main` from this Mac — once in a lifetime |
| `bier uninstall <pkg>` | uninstall and drop from every list |
| `bier prune` | remove what was deleted on another Mac |
| `bier push [message]` | commit the lists and upload them |
| `bier vault add <path>` | take a file or folder into the vault |
| `bier vault group` | which Macs a vault file is meant for |
| `bier retire <name>` | take a Mac out of the fleet |
| `bier trust [url]` | verify Bier program releases against a key published elsewhere |
| `bier peer trust [url]` | alias for `bier trust`; the agent uses the same signed Bier release |
| `bier config` | show which settings are in effect |
| `bier version` | version, commit and paths |
| `bier help` | the same overview in the terminal |

## Adopting an entry

`bier list` shows what the other devices have on top. `bier take` lets
you pick and asks where it should go:

```
What other devices have on top of main:

   1  cask "font-meslo-lg-nerd-font"               macbook
   2  mas "WireGuard"                              macbook

Numbers (e.g. 1 3-5), empty = cancel: 1
Where to?  [m] into main, for all devices   [h] only mini   [c] cancel: m
```

- **into `main`** — applies to every device from now on and therefore
  disappears from the device lists. Listing it twice would be wrong.
- **only this Mac** — goes into this device's own list, the others keep
  theirs. Both then have it device-specifically.

The other direction, `bier take --from-main`, takes an entry out of the
shared inventory and hands it to a single device. That turns "runs
everywhere" into "runs here only".

## Removing something

A snapshot of the system cannot carry removals across — it only sees what
is there. So removing is a command of its own:

```sh
bier uninstall ghidra
```

That uninstalls it, drops the entry from every list and uploads. On the
other Mac ghidra is still installed afterwards but no longer on any list
— the same state as a freshly installed package.

The two can still be told apart, because **the git history knows**: if an
entry used to be on a list and is now gone, it was a removal; if it was
never there, it is new. `bier status` separates them:

```
Installed on mini but not recorded (bier dump):
  + brew "htop"
Removed on another device, still here (bier prune):
  ~ brew "ghidra"
```

`bier prune` clears out the second kind, after asking.

## The menu bar

**BierMenu** shows the state of this Mac without you having to ask:

- **full mug with a head of foam** — system and lists agree
- **empty mug** — something differs here
- **the level moves** — it is checking

A click shows what differs, separated by kind: *not recorded* is done in
the background with one click, *remove* and *install missing* open a
terminal — those take time, ask for a password and can fail, so you
should be able to watch.

What **other** devices have more or less of is deliberately absent. It
says nothing about whether there is anything to do on *this* Mac. That is
what `bier list` is for.

The app computes nothing itself; it calls `bier state`, every 15 minutes
and whenever the menu is opened.

## When two Macs change something at once

Lists of packages have no order, and almost always *both* sides are
right. `bier` therefore sets `merge=union` for the lists: git merges
simultaneous changes itself instead of leaving a conflict behind. Should
one survive anyway, `bier sync` resolves it by the same rule — keep
both sides, carry on. Duplicate lines do not bother Homebrew and
disappear with the next `bier sync`.

If it really cannot be done, `bier` aborts and rolls everything back
rather than leaving something half finished.

## Where things live

Your lists live in *your* private repository, not in this one — they are
nobody else's business, and you would not have write access here anyway.
`install.sh` sets up both and records the paths in
`~/.config/bier/config`:

    root = /Users/yourname/bierfile     # this program
    data = /Users/yourname/bierdata     # your lists
    host = mini                         # what this device is called

`bier config` shows what is currently in effect.

## Further reading

- **[GUIDE.md](GUIDE.md)** — setup and everyday use step by step, with
  examples for two and three Macs. Assumes nothing.
- **[DEVELOPMENT.md](DEVELOPMENT.md)** — how it is built, which design
  decisions were made and why, and how the tests work.

## Licence

MIT — see [LICENSE](LICENSE).
