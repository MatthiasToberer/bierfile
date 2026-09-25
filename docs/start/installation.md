[Docs](../README.md) › Getting started

# Installation

## Requirements

| What | Why | Check |
| --- | --- | --- |
| macOS | BierMenu, the agent and the keychain are macOS-only | — |
| [Homebrew](https://brew.sh) | bier reads and writes Homebrew's inventory | `brew --version` |
| Command Line Tools | git, and the Swift compiler for BierMenu and the agent | `swiftc --version` |
| git name and address | bier commits on your behalf; `install.sh` asks if they are missing | `git config user.name` |

Install the Command Line Tools with `xcode-select --install`. If that
answers that the software is "not currently available from the Software
Update server" — common on fresh or very new systems — download them from
[developer.apple.com/download/all](https://developer.apple.com/download/all)
instead (search for "Command Line Tools"; a free Apple ID is enough).

You do **not** need an account on a data server or a private GitHub
repository. An SSH login on the other Macs is optional — one way to
reach them when they are not on the same network.

### Before you install: Macs on different networks

Paired Macs reach each other on the local network. If they should also
sync when they are apart — a laptop on the road, a desktop at home —
set up [Tailscale](https://tailscale.com) on every Mac **first**. It
connects them privately wherever they are and encrypts the traffic
between them. You then pair with Tailscale names; see
[Syncing beyond the local network](../security/pairing.md#syncing-beyond-the-local-network-tailscale).
Where SSH reaches the other Mac, that works too, without Tailscale — see
[Syncing over SSH](../security/pairing.md#syncing-over-ssh).

## Install

One line, like Homebrew:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/MatthiasToberer/bierfile/main/bootstrap.sh)"
```

`bootstrap.sh` finds the newest release, fetches it into
`~/.barrel/bier`, and checks its signature against the key published on
a separate host — it prints the fingerprint; compare it with one you got
some other way. A release that is not signed with that key installs
nothing. Then it hands over to `install.sh`, which reports every step:

1. **Checks the requirements** and stops with a clear message if
   something is missing.
2. **Puts the `bier` command in `~/.barrel/bin`** and offers to add that
   folder to your `PATH` in `~/.zshrc`.
3. **Creates `~/.barrel/data`**, the private local repository for your
   lists.
4. **Writes `~/.barrel/config`** with `root`, `data` and `host` —
   see [Configuration](../reference/configuration.md).
5. **Creates the vault** in `~/.barrel/vault` and asks for its
   passphrase.
6. **Builds BierMenu** into `~/.barrel` and starts it.
7. **Installs the local Bier agent** with a private Ed25519 peer identity
   for this Mac, and records this Mac's inventory.

If `bier` answers `command not found` afterwards, the current shell does
not know the new `PATH` yet. Open a new terminal or type `exec zsh`.

Running the line again is harmless: it runs the installed installer
again, which replaces what is there.

### Everything in one folder

```
~/.barrel/
  bier/          the program
  bin/bier       the command
  BierMenu.app   the menu bar app
  config, peers  settings, paired Macs
  data/          your lists and the encrypted safe
  vault/         plain copies of the files you share
  state/         what this Mac last agreed on, backups
  agent/         the agent and this Mac's identity
```

Only a LaunchAgent (to start the agent at login), a `PATH` line in
`~/.zshrc` and the vault passphrase in the keychain live outside it.

### An installation from before

An installation from before `~/.barrel` — with `~/bierfile`,
`~/bierdata`, `~/.bierfilevault` and `~/.config/bier` — is moved in by
the next `bier upgrade` or `install.sh`: settings, agent, data and vault
go into `~/.barrel`, vault links in your home folder become plain files,
and the old command and app are removed. A data folder or vault you set
up somewhere else stays where it is.

## Options

Handed on to `install.sh`. With the one line, put them after a `_`:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/MatthiasToberer/bierfile/main/bootstrap.sh)" _ --manual-inventory
```

| Option | Effect |
| --- | --- |
| `--data <folder>` | keep the lists somewhere other than `~/.barrel/data` |
| `--manual-inventory` | manual mode: record only what you write into the Brewfiles yourself. The default is automatic — see [Automatic and manual](../concepts/lists.md#automatic-and-manual) |
| `--dry-run` | say what would happen, change nothing |
| `--uninstall` | take bier off this Mac — the same as `bier knockout` |
| `--yes` | answer every question with yes (used by `bier upgrade`) |

## After installing

- On the **first** Mac: `bier main`, once — its software becomes what
  All Macs have; see [All Macs, groups, and what is not assigned](../concepts/lists.md).
- On **every further** Mac: pair it — see [Pairing](../security/pairing.md) —
  then `bier install`.
- Put every Mac in a group — `bier group laptops mini macbook` — see
  [Groups](../concepts/groups.md). A new Mac is *new* until it is moved.

The [seven-minute pilsner](../tutorials/seven-minute-pilsner.md) walks
through both.

## Upgrading

```sh
bier upgrade
```

Looks for a newer release, checks it out, verifies its signature against
the key the installation pinned (see
[Signed releases](../security/signed-releases.md)), and runs `install.sh`
again. It never touches your lists. BierMenu offers the
same when a release is waiting.

## Uninstalling

```sh
bier knockout --dry-run    # look first
bier knockout
```

After you type `knockout` to confirm, it:

1. syncs one last time, so nothing made on this Mac is lost,
2. takes this Mac out of the lists and its group and hands that
   to the paired Macs,
3. signs off at every paired Mac — each forgets this Mac's key and
   address; one that cannot be reached is named, with what to run there,
4. takes bier off this Mac: the agent, BierMenu, the `bier` command, the
   `PATH` line and the passphrase in the keychain,
5. asks whether to delete `~/.barrel` as well.

Files from the vault stay where they are, as plain files. Installed
Homebrew packages stay installed.

The blunt way out is `rm -rf ~/.barrel`: your files stay, the agent
removes its LaunchAgent the next time it would start, and the other
Macs are not told — `bier peer remove <name>` on each of them does that.
