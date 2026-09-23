# bier documentation

bier keeps the Homebrew inventory and the dotfiles of several Macs
identical. It records what is installed, shares it directly with paired
Macs and shows the state as a beer glass in the menu bar.

New here? Start with **[the quick round](tutorials/quick-round.md)** if
you know your way around a terminal, or with
**[the seven-minute pilsner](tutorials/seven-minute-pilsner.md)** if you
would rather have every step explained.

> [!WARNING]
> **Make a backup before you use bier for the first time.** bier
> installs and **uninstalls** software — `bier uninstall`, `bier prune`
> and `bier install` really do reach through. Removing a program can take
> its settings and data with it, and a wrong entry in a list affects
> *all* of your devices. This is a hobby project, provided without any
> warranty; keep a working Time Machine backup or equivalent.

## Getting started

- **[Installation](start/installation.md)** — requirements, what
  `install.sh` does, options, uninstalling
- **[Trial run](start/trial-run.md)** — try bier on two Macs with one
  harmless package before handing it your whole inventory

## Tutorials

- **[The quick round](tutorials/quick-round.md)** — the commands and
  nothing else
- **[The seven-minute pilsner](tutorials/seven-minute-pilsner.md)** — two
  Macs from scratch, every step explained
- **[Two Macs: installing something new](tutorials/new-tool-on-two-macs.md)**
- **[Three Macs: one with special equipment](tutorials/special-equipment.md)**
- **[Getting rid of something everywhere](tutorials/removing-everywhere.md)**
- **[Your dotfiles on a new Mac](tutorials/dotfiles-on-a-new-mac.md)**

## Concepts

- **[main and device lists](concepts/lists.md)** — the one rule
  everything rests on
- **[How removals travel](concepts/removals.md)** — why the git history
  matters
- **[When two Macs change at once](concepts/conflicts.md)**

## Using bier

- **[Everyday: sync and status](using/everyday.md)**
- **[Adopting entries](using/take.md)** — `bier take`
- **[Removing software](using/removing.md)** — `bier uninstall` and
  `bier prune`
- **[BierMenu](using/biermenu.md)** — the glass in the menu bar
- **[Retiring a Mac](using/retiring-a-mac.md)**

## Vault

- **[Dotfiles in the vault](vault/dotfiles.md)**
- **[Groups](vault/groups.md)** — files for some Macs only
- **[Passphrase and recovery](vault/recovery.md)**

## Peers & security

- **[Pairing](security/pairing.md)** — connecting Macs without SSH
- **[Threat model](security/threat-model.md)** — what a peer can and
  cannot do, and who gets to run code on your Mac
- **[Signed releases](security/signed-releases.md)** — `bier trust`
- **[Peer data protocol](../Sources/bier-agent/PEER-DATA-PROTOCOL.md)** —
  the wire contract of the agent

## Reference

- **[Commands](reference/commands/README.md)** — one page per command
- **[Configuration and paths](reference/configuration.md)**
- **[Troubleshooting](reference/troubleshooting.md)**

## Contributing

- **[System overview](contributing/system-overview.md)** — bier,
  bier-agent and Bierkasten: components, keys, endpoints and flows
- **[Architecture](contributing/architecture.md)**
- **[Design decisions](contributing/design-decisions.md)** — and the
  traps that have already sprung
- **[Tests](contributing/testing.md)**
- **[Versions and releases](contributing/releasing.md)**
