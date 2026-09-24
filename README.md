<div align="center">

<img src="docs/assets/bier.svg" width="88" alt="">

# bier

**Your Macs, on tap.**

Keeps the software and dotfiles of several Macs identical —
built on Homebrew, synced peer-to-peer, no server.

[![Release](https://img.shields.io/github/v/release/MatthiasToberer/bierfile?color=b87308&label=release)](https://github.com/MatthiasToberer/bierfile/releases)
![Platform](https://img.shields.io/badge/platform-macOS-333)
[![License](https://img.shields.io/github/license/MatthiasToberer/bierfile?color=1a7f37)](LICENSE)

[Install](#quick-start) · [Documentation](docs/README.md) · [Tutorials](docs/README.md#tutorials) · [Security](SECURITY.md) · [Releases](https://github.com/MatthiasToberer/bierfile/releases)

</div>

<!-- Screenshot: BierMenu full and empty, light and dark menu bar → docs/assets/biermenu.png -->

## Why bier

You install something on the desktop, forget about it, and six months
later it is missing on the laptop. bier writes down what is installed,
shares it directly with your other Macs, and shows a beer glass in the
menu bar: **full** — all in order, **empty** — something to do here.

| | |
| --- | --- |
| **One main inventory** | `main` applies to every Mac. New installs are recorded automatically as that Mac's extras until you move them into `main`. All plain [Brewfiles](https://docs.brew.sh/Brew-Bundle-and-Brewfile). |
| **Removals travel too** | The git history tells "removed elsewhere" from "new here". `bier prune` follows along. |
| **Encrypted dotfiles and app settings** | `bier vault add ~/.zshrc`, or a whole settings folder — AES-256, one shared passphrase, groups per Mac. Files stay where they are. |
| **No server** | Pair once with a one-time code. Macs exchange signed Git history directly — on the local network, over Tailscale or through SSH. |
| **No git knowledge needed** | `bier sync` asks nothing and merges on its own. |
| **Signed releases** | Installation and upgrades check a signing key published away from GitHub. |
| **Out of sight, easy to leave** | Everything bier keeps lives in `~/.barrel`. `bier knockout` signs off and leaves; `rm -rf ~/.barrel` works too. |

## Quick start

Requires macOS, [Homebrew](https://brew.sh) and the Command Line Tools
(`xcode-select --install`). Macs sync over the local network; to sync
them anywhere, use [Tailscale](docs/security/pairing.md#syncing-beyond-the-local-network-tailscale)
or [SSH](docs/security/pairing.md#syncing-over-ssh).

On every Mac, one line — like Homebrew:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/MatthiasToberer/bierfile/main/bootstrap.sh)"
```

It fetches the latest signed release into `~/.barrel`, checks the
signature and sets everything up. Then:

```sh
# on the first Mac, once: this Mac becomes the baseline
bier main

# on every further Mac
bier peer offer                  # shows a one-time code
#   …then on the first Mac:  bier peer pair second-mac.local
bier install
```

From then on, one command after every install:

```sh
bier sync
```

Step by step, assuming nothing:
**[The seven-minute pilsner →](docs/tutorials/seven-minute-pilsner.md)**

> [!WARNING]
> **Back up first.** bier installs *and uninstalls* software on every
> paired Mac, and a wrong entry in a list reaches all of them. This is a
> hobby project without warranty — keep a working Time Machine backup.
> [What can go wrong →](docs/reference/troubleshooting.md)

## Documentation

| | |
| --- | --- |
| **[Getting started](docs/README.md#getting-started)** | Installation, a first trial run |
| **[Tutorials](docs/README.md#tutorials)** | The quick round, the seven-minute pilsner, worked examples |
| **[Concepts](docs/README.md#concepts)** | The two lists, how removals travel, simultaneous changes |
| **[Using bier](docs/README.md#using-bier)** | Everyday sync, adopting entries, removing software, the menu bar |
| **[Vault](docs/README.md#vault)** | Dotfiles, groups, recovery without bier |
| **[Peers & security](docs/README.md#peers--security)** | Pairing, threat model, signed releases |
| **[Reference](docs/README.md#reference)** | Every command, configuration, troubleshooting |
| **[Contributing](docs/README.md#contributing)** | System overview of bier, bier-agent and Bierkasten; design decisions, tests, releases |

## Thanks

*bier* is German for *beer* — and a thank-you to
[Homebrew](https://brew.sh): no brew, no beer. bier is a thin layer on
top of `brew bundle` and would not exist without the work of the Homebrew
maintainers.

MIT licence — see [LICENSE](LICENSE).
