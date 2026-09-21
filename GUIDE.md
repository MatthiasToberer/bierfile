# bier — the guide

`bier` makes sure the same software is on all of your Macs.

You install something on one machine, forget about it, and six months
later it is missing on the other. `bier` writes down what is installed,
keeps that list in a git repository, and shows you a beer glass in the
menu bar: **full** means everything is in order, **empty** means
something differs.

Two ways through this guide:

- **[The quick round](#the-quick-round)** — the commands and nothing
  else. For anyone who knows what a terminal is.
- **[The seven-minute pilsner](#the-seven-minute-pilsner)** — the long
  way, where every step is explained. Nothing is assumed.

At the bottom there are [examples](#examples) with two and three Macs.
The overview in short form is [README.md](README.md).

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

## The quick round

**You need:** macOS, [Homebrew](https://brew.sh), the Command Line Tools
(`xcode-select --install`) and an **empty, private git repository** for
your lists that all Macs can reach over SSH.

**On the first Mac** — the one whose software should serve as the
template:

```sh
git clone git@github.com:MatthiasToberer/bierfile.git ~/bierfile
~/bierfile/install.sh   # asks for your private repository
bier main
```

**On every further Mac:**

```sh
git clone git@github.com:MatthiasToberer/bierfile.git ~/bierfile
~/bierfile/install.sh
bier install          # brings the software from main onto the system
bier sync
```

**Everyday use:**

```sh
bier sync             # record here, fetch there — after every install
bier vault add ~/.zshrc   # a file, not only packages
bier status           # what differs here?
bier list             # what do the others have on top?
bier take             # adopt some of it
bier uninstall htop   # get rid of it everywhere
bier prune            # remove here what was deleted elsewhere
```

That is all. Everything below is detail.

---

## The seven-minute pilsner

### What you need

**A terminal.** The program is called "Terminal" and lives in
`/Applications/Utilities`. Open it; you get a window to type commands
into. Every command in this guide gets typed (or pasted) in there,
followed by Enter.

**Homebrew.** That is the package manager for macOS — a program that
installs other programs. Instead of downloading an app from a website you
type `brew install wget`. `bier` builds entirely on it: it reads and
writes Homebrew's inventory list. If you do not have Homebrew yet, the
install command is on [brew.sh](https://brew.sh). You can check like
this:

```sh
brew --version
```

A version number means all is well. `command not found` means Homebrew is
still missing.

**The Command Line Tools.** They contain the Swift compiler that builds
the menu bar app. Once:

```sh
xcode-select --install
```

**A git repository of your own for your lists.** Git is the program
developers use to keep files in step between machines. `bier` uses it to
move the inventory lists between your Macs. You need an empty
*repository* on a server all of your Macs can reach with an SSH key — a
small Linux box on your network, a NAS, or a repository on GitHub.

**Set it to private.** The lists reveal which software is on your Macs;
that is nobody else's business. It is also why they do not live in the
repository of `bier` itself but in your own. Throughout this guide the
address reads `git@your-server:bierdata.git`; put your own in its place.

### Step 1: The first device

Pick the Mac whose software should serve as the **template**. With two
machines that is usually the one you work on most.

```sh
git clone git@github.com:MatthiasToberer/bierfile.git ~/bierfile
```

`clone` fetches the program from the server and puts it in a folder
`bierfile` in your home directory. The tilde `~` is the shorthand for
that — `~/bierfile` is `/Users/yourname/bierfile`.

That is only the program. Your lists go somewhere else in a moment.

```sh
~/bierfile/install.sh
```

The setup script. It tells you what it is doing at every step:

1. **Checks the requirements** — macOS, git, Homebrew, Swift. If
   something is missing it stops and says what.
2. **Makes `bier` callable anywhere.** It puts a symlink in
   `~/.local/bin` so you do not have to type the full path every time. If
   that folder is not on your search path, it tells you the line to add
   to `~/.zshrc`.
3. **Installs a git hook** that runs the tests before program changes are
   uploaded. For you as a user nothing changes.
4. **Asks for your private repository** for the inventory lists, clones
   it to `~/bierdata` and creates the basic structure inside. If you have
   the address to hand you can skip the question:
   `~/bierfile/install.sh --data git@your-server:bierdata.git`
5. **Creates the configuration** at `~/.config/bier/config`. It holds
   three things: where the program lives (`root`), where your lists live
   (`data`) and what this Mac is called (`host`).
6. **Builds the menu bar app** and puts it in `/Applications`.
7. **Records the inventory** of this Mac and asks whether to upload it.

After that a beer glass hangs in the menu bar at the top right.

Now comes the step that happens **only once in the life of a setup**:

```sh
bier main
```

That declares this Mac's inventory the shared baseline. Every program
installed here ends up in the file `Brewfiles/main`, and from now on that
applies to **all** of your Macs. The command uploads the result right
away.

Have a look:

```sh
bier list
```

```
Brewfiles/main: 138 entries, applies to every device

Device               on top
  mini                     0   (this Mac)
```

138 programs in the shared inventory, and this Mac has nothing on top of
it — naturally, `main` just came from it.

### Step 2: Every further device

On the second Mac, exactly as before:

```sh
git clone git@github.com:MatthiasToberer/bierfile.git ~/bierfile
~/bierfile/install.sh
```

At the fourth step you give the same address for your private repository
as on the first Mac — the lists are already there.

Do **not** type `bier main` here. The command would replace the shared
inventory with this machine's — that is, overwrite it with a nearly empty
list. `bier main` belongs on the template Mac only, and there only once.

Instead:

```sh
bier status
```

```
Recorded but not installed on macbook (bier install):
  - brew "ffmpeg"
  - brew "ghidra"
  - cask "iterm2"
```

The list is long — `bier status` shows it in full, every missing program
individually. (Only the menu in the bar cuts it short, so it does not run
off the screen.)

`bier` now knows what is missing here. Go and get it:

```sh
bier install
```

That installs everything from the shared inventory. **It takes a while** —
depending on the size, half an hour or more, and for some programs macOS
asks for your password. Leave the window open.

When it is through:

```sh
bier sync
```

`sync` records the current inventory and uploads it. From here the second
Mac has caught up, and the beer glass is full.

### Step 3: Everyday use

**The beer glass** in the menu bar checks every 15 minutes and whenever
you open the menu.

- **Full mug with a head of foam** — all in order.
- **Empty mug** — something differs. Click it and it says what.
- **The level rises and falls** — `bier` is working.

In the menu the differences are separated by kind, because they cost
different amounts:

- *installed but not recorded* — you installed something and have not
  uploaded it yet. "Pour a round" does that in seconds.
- *recorded but not installed* — something was added on another Mac.
  "Install missing" opens a terminal, because it can take a while.
- *removed elsewhere, still here* — something was removed on another Mac.
  "Remove" clears it out here too.

In the terminal you really only need one command:

```sh
bier sync
```

After every installation. It records what is new here, fetches what
happened on the other Macs, merges and uploads. It asks nothing and
resolves conflicts on its own.

The program itself is a separate matter, and a rarer one:

```sh
bier upgrade
```

That one never touches your lists. It only looks whether a newer `bier`
is out and puts it in place.

### Step 4: When the Macs should differ

Not everything belongs on every machine. A 5 GB LaTeX package on the
MacBook, for instance.

There are two drawers for that:

- **`Brewfiles/main`** — what should run on **all** Macs.
- **`Brewfiles/<device name>`** — what **only this** Mac has on top.

The two together describe what a device is supposed to have.

What is on the other Mac and might interest you is shown by:

```sh
bier list
```

```
On top of main, and where:
  cask "font-meslo-lg-nerd-font"               macbook
  mas "WireGuard"                              macbook
```

You can adopt it one entry at a time:

```sh
bier take
```

```
What other devices have on top of main:

   1  cask "font-meslo-lg-nerd-font"               macbook
   2  mas "WireGuard"                              macbook

Numbers (e.g. 1 3-5), empty = cancel: 1
Where to?  [m] into main, for all devices   [h] only mini   [c] cancel:
```

The question at the end is the important one:

- **`m` — into `main`:** the font applies to every Mac from now on. It is
  removed from macbook's file, because it is in the shared inventory now.
  Listing it twice would be wrong.
- **`h` — only this Mac:** the font goes into your own file. macbook
  **keeps** its entry. Both then have it, but each one separately.

And the other way round — take something out of the shared inventory and
hand it to a single Mac:

```sh
bier take --from-main
```

You need that when something ended up in `main` that does not belong
there. Remember the rule behind it: **anything that does not belong
everywhere must not be in `main`.**

### Step 5: Files, not only packages

A new Mac with all your programs is still not your Mac. The `.zshrc` is
missing, the editor knows none of your settings. Those go into the
vault.

```sh
bier vault add ~/.zshrc
```

Look at what happened:

```sh
ls -l ~/.zshrc
```

```
~/.zshrc -> ~/.bierfilevault/dot_zshrc
```

The file moved and a link stayed behind. zsh follows it and notices
nothing; you edit `~/.zshrc` as before. The first `bier sync` asks for a
passphrase:

```
The passphrase is the only thing protecting the vault, and
nothing can recover it. Keep a copy somewhere that is not
these Macs — your password manager, or a note in a drawer.
Do that first; this is not the place to invent one.

Passphrase:
```

Take that seriously. Lose it and the vault is scrap paper.

On the next Mac, `bier sync` asks for the same passphrase once, and then
`~/.zshrc` is there. Change it on either Mac, sync, and the other one
has the change. It is the same file, not a copy.

Whole folders work as well:

```sh
bier vault add ~/.config/nvim
```

**When a file is not for everybody:**

```sh
bier vault group laptops mini macbook
bier vault add --for laptops ~/.zshrc
```

The mini tower is not in `laptops` and never opens the file — it does
receive the encrypted copy, it just has no reason to look inside.

**Taking something back out:**

```sh
bier vault forget ~/.zshrc    the real file returns, it stays on this Mac
bier vault drop ~/.zshrc      gone everywhere, after asking
```

Those two are easy to mix up and the consequences differ, exactly like
`bier dump` and `bier prune`.

**If a link ever points nowhere** — you deleted the vault folder, or a
program replaced the link with a file — `bier status` says so and
`bier vault --restore` puts it back. And if bier is gone altogether,
`Safe/README-recovery.txt` explains how to get everything back with
`gpg` and nothing else.

### Step 6: Getting rid of something

Do not just type `brew uninstall` — the program would stay on the list,
and the next `bier install` brings it back. Instead:

```sh
bier uninstall ghidra
```

That uninstalls it, drops it from **every** list and uploads the change.

On the other Mac it is still installed afterwards. There `bier` speaks up
by itself:

```
Removed on another device, still here (bier prune):
  ~ brew "ghidra"
```

```sh
bier prune
```

Asks, then clears it away.

### When something is wrong

```sh
bier version     # which build is running here?
bier config      # where are the program and the lists, what is this Mac called?
bier status      # what differs?
bier help        # every command
```

You also find the version in the menu under **Info**, together with an
entry that opens this guide.

---

## Examples

### Two Macs: you install something new

You are sitting at the Mac mini `mini` and need a tool:

```sh
brew install ripgrep
```

The beer glass empties. A click shows:

```
1 installed but not recorded
    ripgrep  (formula)
Pour a round: record and push
```

You click "Pour a round" — or type `bier sync`. Done, the glass is full
again.

The next day at the MacBook `macbook`:

```sh
bier sync
```

```
Brewfiles/macbook written: 0 on top of 138 in main
New inventory from the other Mac:
  Brewfiles/main | 1 +
```

The glass on the MacBook empties and reports "1 recorded but not
installed". A click on "Install missing", and both Macs have ripgrep.

### Three Macs: one needs special equipment

You have `mini`, `macbook` and on top of that `studio`, the machine for
video editing. DaVinci Resolve lives there, and it has no business on the
other two.

On `studio` you install it as usual and type `bier sync`. Because you
never move it into `main`, it lands in `Brewfiles/studio` and stays
there:

```sh
bier list
```

```
Brewfiles/main: 138 entries, applies to every device

Device               on top
  macbook                  2
  mini                     0
  studio                   3   (this Mac)

On top of main, and where:
  cask "davinci-resolve"                       studio
  cask "font-meslo-lg-nerd-font"               macbook
  mas "WireGuard"                              macbook
```

The other two Macs do **not** nag about Resolve — it is not in the shared
inventory. That is exactly what the two drawers are for.

If it later turns out that macbook's font belongs everywhere after all,
you type `bier take` on any Mac, pick it and answer `m`. From the next
`bier sync` onwards all three fetch it.

### Getting rid of something everywhere

A program has to go from `main`. On any Mac:

```sh
bier uninstall handbrake
```

```
handbrake (cask)
==> Uninstalling Cask handbrake
Brewfiles/mini written: 0 on top of 137 in main
Commit: mini: removed handbrake
In sync with origin.
```

On the other two Macs, next time you look at the menu:

```
1 removed elsewhere, still here
    handbrake  (app)
Remove … (in Terminal)
```

One click, confirm, gone. On all three.
