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

You do **not** need an SSH login on the other Macs, an account on a data
server or a private GitHub repository.

### Before you install: Macs on different networks

Paired Macs reach each other on the local network. If they should also
sync when they are apart — a laptop on the road, a desktop at home —
set up [Tailscale](https://tailscale.com) on every Mac **first**. It
connects them privately wherever they are and encrypts the traffic
between them. You then pair with Tailscale names; see
[Syncing beyond the local network](../security/pairing.md#syncing-beyond-the-local-network-tailscale).

## Install

```sh
git clone https://github.com/MatthiasToberer/bierfile.git ~/bierfile
~/bierfile/install.sh
```

`install.sh` reports every step:

1. **Checks the requirements** and stops with a clear message if
   something is missing.
2. **Links `bier` into `~/.local/bin`.** If that folder is not on your
   `PATH`, it prints the line to add to `~/.zshrc`.
3. **Installs a git hook** in the program repository that runs the tests
   before code is pushed. Users never notice it.
4. **Creates `~/bierdata`**, the private local repository for your lists.
5. **Writes `~/.config/bier/config`** with `root`, `data` and `host` —
   see [Configuration](../reference/configuration.md).
6. **Builds BierMenu** and puts it in `/Applications`.
7. **Installs the local Bier agent** with a private Ed25519 peer identity
   for this Mac, and records this Mac's inventory.

If `bier` answers `command not found` afterwards, the current shell does
not know the new `PATH` yet. Open a new terminal or type `exec zsh`.

Running `install.sh` again is harmless: it replaces what is there.

## Options

| Option | Effect |
| --- | --- |
| `--data <folder>` | keep the lists somewhere other than `~/bierdata` |
| `--manual-inventory` | manual mode: record only what you write into the Brewfiles yourself. The default is automatic — see [Automatic and manual](../concepts/lists.md#automatic-and-manual) |
| `--dry-run` | say what would happen, change nothing |
| `--uninstall` | take bier off this Mac |
| `--yes` | answer every question with yes (used by `bier upgrade`) |

## After installing

- On the **first** Mac: `bier main`, once — see
  [main and device lists](../concepts/lists.md).
- On **every further** Mac: pair it — see [Pairing](../security/pairing.md) —
  then `bier install`.

The [seven-minute pilsner](../tutorials/seven-minute-pilsner.md) walks
through both.

## Upgrading

```sh
bier upgrade
```

Looks for a newer release, checks it out, verifies its signature if you
asked for that with [`bier trust`](../security/signed-releases.md), and
runs `install.sh` again. It never touches your lists. BierMenu offers the
same when a release is waiting.

## Uninstalling

```sh
~/bierfile/install.sh --dry-run --uninstall    # look first
~/bierfile/install.sh --uninstall
```

In this order it:

1. turns every vault link back into a plain file, so no dotfile goes
   missing,
2. takes this Mac out of the lists and out of every vault group
   (`bier retire --self`) and commits that — other Macs only see it if
   they sync with this one before it is gone; otherwise run
   `bier retire <name>` on one of them,
3. stops and removes BierMenu and the agent, the `bier` link and the
   vault passphrase in the keychain,
4. asks whether to delete `~/.config/bier/config`.

It does **not** touch the data repository or the vault files themselves.
Installed Homebrew packages stay installed.
