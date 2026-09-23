[Docs](../README.md) › Tutorials

# The seven-minute pilsner

Two Macs, from nothing to identical, with every step explained. Nothing
is assumed. In a hurry? [The quick round](quick-round.md) has only the
commands.

> [!WARNING]
> bier installs and uninstalls software on every paired Mac. Make sure
> you have a working backup before you start.

**Contents**

1. [What you need](#what-you-need)
2. [The first Mac](#step-1-the-first-mac)
3. [Every further Mac](#step-2-every-further-mac)
4. [Everyday use](#step-3-everyday-use)
5. [When the Macs should differ](#step-4-when-the-macs-should-differ)
6. [Files, not only packages](#step-5-files-not-only-packages)
7. [Getting rid of something](#step-6-getting-rid-of-something)

## What you need

**A terminal.** The program is called Terminal and lives in
`/Applications/Utilities`. Every command in this tutorial is typed (or
pasted) there, followed by Enter.

**Homebrew.** The package manager for macOS — a program that installs
other programs. Instead of downloading an app from a website you type
`brew install wget`. bier builds entirely on it: it reads and writes
Homebrew's inventory list. If you do not have it yet, the install command
is on [brew.sh](https://brew.sh). Check:

```sh
brew --version
```

A version number means all is well. `command not found` means Homebrew
is still missing.

**The Command Line Tools.** They contain git and the Swift compiler that
builds the menu bar app. Once:

```sh
xcode-select --install
```

A window appears and offers to install them. If it says instead that the
software is "not currently available from the Software Update server",
that path is closed — it happens on fresh or very new systems. Fetch them
by hand from
[developer.apple.com/download/all](https://developer.apple.com/download/all):
search for "Command Line Tools", take the one matching your macOS and
install the package. A free Apple ID is enough. Afterwards this has to
answer:

```sh
swiftc --version
```

**A name and an address for git.** bier commits on your behalf, and git
refuses to commit without them. `install.sh` asks; you can also set them
yourself:

```sh
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

**Optional: Tailscale.** Paired Macs sync over the local network. If
yours should also sync when they are apart — a laptop on the road —
install [Tailscale](https://tailscale.com) on every Mac **now**, before
bier, and pair with Tailscale names later. How:
[Syncing beyond the local network](../security/pairing.md#syncing-beyond-the-local-network-tailscale).

**Nothing else.** No SSH login on the other Mac, no data server, no
account anywhere. The installer creates a private peer identity for each
Mac and a local repository for your lists. The lists reveal which
software you use, so they never go to the public program repository or to
any service — only to Macs you pair explicitly.

## Step 1: The first Mac

Pick the Mac whose software should serve as the **template**. With two
machines that is usually the one you work on most.

```sh
git clone https://github.com/MatthiasToberer/bierfile.git ~/bierfile
```

`clone` fetches the program and puts it in a folder `bierfile` in your
home directory. The tilde `~` is shorthand for that: `~/bierfile` is
`/Users/yourname/bierfile`. That is only the program — your lists go
somewhere else in a moment.

```sh
~/bierfile/install.sh
```

The setup script says what it is doing at every step: it checks the
requirements, makes `bier` callable from anywhere, creates `~/bierdata`
for your lists, builds the menu bar app, installs the local agent and
records this Mac's inventory. (The full list is in
[Installation](../start/installation.md).)

It also asks for a **vault passphrase** — the key to the encrypted
dotfiles in [step 5](#step-5-files-not-only-packages). Every Mac uses the
same one. Store it in your password manager *before* you type it;
nothing can recover it.

Afterwards a beer glass hangs in the menu bar at the top right.

Now the step that happens **only once in the life of a setup**:

```sh
bier main
```

This declares this Mac's inventory the shared baseline. Every program
installed here ends up in `Brewfiles/main` — the main inventory, which
from now on applies to **all** of your Macs.

bier runs in **automatic** mode unless you chose otherwise: from here
on, everything you install is recorded by `bier sync`, and anything
beyond `main` goes into this Mac's own list until you decide it belongs
everywhere ([step 4](#step-4-when-the-macs-should-differ)). Have a look:

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

## Step 2: Every further Mac

On the second Mac, exactly as before:

```sh
git clone https://github.com/MatthiasToberer/bierfile.git ~/bierfile
~/bierfile/install.sh
```

The second installation starts with empty scaffolding. Open pairing
there:

```sh
bier peer offer
```

```
Pairing is open for 10 minutes.
On the other Mac run:  bier peer pair macbook.local
One-time code: 3f9a-c21e-...
```

Run the printed command on the **first** Mac and enter the code:

```sh
bier peer pair macbook.local
```

Both Macs store each other's public key and address, and the code is
spent. bier then synchronises the two: an untouched second installation
receives the first Mac's lists and their complete history, and one that
already recorded its own inventory keeps it and gets the rest. (How that is
protected: [Pairing](../security/pairing.md).)

> [!CAUTION]
> Do **not** type `bier main` on the second Mac. It would replace the
> shared inventory with this machine's nearly empty one. `bier main`
> belongs on the template Mac only, and there only once.

Instead, back on the second Mac:

```sh
bier status
```

```
Recorded but not installed on macbook (bier install):
  - brew "ffmpeg"
  - brew "ghidra"
  - cask "iterm2"
  …
```

bier knows what is missing here. Go and get it:

```sh
bier install
```

This installs everything from the shared inventory. **It takes a
while** — half an hour or more, depending on the size — and for some
programs macOS asks for your password. Leave the window open.

When it is through:

```sh
bier sync
```

The second Mac has caught up, and its glass is full.

## Step 3: Everyday use

**The glass** in the menu bar checks every 15 minutes and whenever you
open the menu.

| Glass | Meaning |
| --- | --- |
| full, with a head of foam | all in order |
| empty | something differs — click it and it says what |
| level rising and falling | bier is working |

In the menu, differences are grouped by what they cost:

- **installed but not recorded** — you installed something and have not
  shared it yet. *Pour a round* does that in seconds.
- **recorded but not installed** — something was added on another Mac.
  *Install missing* opens a terminal, because it can take a while.
- **removed elsewhere, still here** — something was removed on another
  Mac. *Remove* clears it out here too.

In the terminal you really only need one command, after every
installation:

```sh
bier sync
```

It records what is new here, exchanges history with your paired Macs and
merges. It asks nothing and resolves conflicts on its own.

The program itself is a separate, rarer matter:

```sh
bier upgrade
```

That never touches your lists. It only looks whether a newer bier is out
and puts it in place.

## Step 4: When the Macs should differ

Not everything belongs on every machine — a 5 GB LaTeX distribution on
the laptop, for instance. There are two drawers for that:

- **`Brewfiles/main`** — what should run on **all** Macs.
- **`Brewfiles/<device name>`** — what **only this** Mac has on top.

What other Macs have on top is shown by `bier list`; you adopt it one
entry at a time:

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

- **`m` — into main:** the font applies to every Mac from now on and
  leaves macbook's own list, because listing it twice would be wrong.
- **`h` — only this Mac:** the font goes into your own list. macbook
  keeps its entry; both have it, each separately.

The other way round — out of the shared inventory, to a single Mac — is
`bier take --from-main`. The rule behind both: **anything that does not
belong everywhere must not be in `main`.** More in
[main and device lists](../concepts/lists.md).

## Step 5: Files, not only packages

A new Mac with all your programs is still not your Mac: the `.zshrc` is
missing, the editor knows none of your settings. Those go into the
vault.

```sh
bier vault add ~/.zshrc
ls -l ~/.zshrc
```

```
~/.zshrc -> ~/.bierfilevault/dot_zshrc
```

The file moved and a link stayed behind. zsh follows it and notices
nothing; you edit `~/.zshrc` as before. `bier sync` encrypts it and
shares it.

The second Mac needs the **same** passphrase — type it when its
installer asks, or later with `bier vault --init`. Its next `bier sync`
then puts `~/.zshrc` in place. That Mac's own copy is not thrown away:

```
kept: ~/.zshrc.backup
linked: ~/.zshrc
```

Change it on either Mac, sync, and the other has the change — it is the
same file, not a copy. Groups, recovery and the rest:
[Vault](../vault/dotfiles.md).

## Step 6: Getting rid of something

Do not just type `brew uninstall` — the program would stay on the list,
and the next `bier install` would bring it back. Instead:

```sh
bier uninstall ghidra
```

That uninstalls it and drops it from **every** list; the next
`bier sync` passes that on. On the other Mac it is still installed, and
bier says so:

```
Removed on another device, still here (bier prune):
  ~ brew "ghidra"
```

```sh
bier prune
```

It asks, then clears it away. Why bier can tell a removal from a new
package: [How removals travel](../concepts/removals.md).

## When something is wrong

```sh
bier version     # which build is running here?
bier config      # where are program and lists, what is this Mac called?
bier status      # what differs?
bier help        # every command
```

More in [Troubleshooting](../reference/troubleshooting.md).

---

**Next:** [Two Macs: installing something new](new-tool-on-two-macs.md)
