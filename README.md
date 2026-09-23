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
| **One list, plus extras** | `main` applies to every Mac, a small list per Mac sits on top. Both are plain [Brewfiles](https://docs.brew.sh/Brew-Bundle-and-Brewfile). |
| **Removals travel too** | The git history tells "removed elsewhere" from "new here". `bier prune` follows along. |
| **Encrypted dotfiles** | `bier vault add ~/.zshrc` — AES-256, one shared passphrase, groups per Mac. |
| **No server, no SSH** | Pair once with a one-time code. Macs exchange signed Git history directly. |
| **No git knowledge needed** | `bier sync` asks nothing and merges on its own. |
| **Signed releases** | `bier trust` pins a signing key published away from GitHub. |

## Quick start

Requires macOS, [Homebrew](https://brew.sh) and the Command Line Tools
(`xcode-select --install`).

```sh
# on the first Mac
git clone https://github.com/MatthiasToberer/bierfile.git ~/bierfile
~/bierfile/install.sh
bier main                        # once: this Mac becomes the baseline

# on every further Mac
git clone https://github.com/MatthiasToberer/bierfile.git ~/bierfile
~/bierfile/install.sh
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
| **[Contributing](docs/README.md#contributing)** | Architecture, design decisions, tests and releases |

## Thanks

*bier* is German for *beer* — and a thank-you to
[Homebrew](https://brew.sh): no brew, no beer. bier is a thin layer on
top of `brew bundle` and would not exist without the work of the Homebrew
maintainers.

MIT licence — see [LICENSE](LICENSE).
