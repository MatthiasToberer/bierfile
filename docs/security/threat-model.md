[Docs](../README.md) › Peers & security

# Threat model

bier installs and removes software and moves your dotfiles between Macs.
This page states plainly who can make it do what, and where the limits
are. Report vulnerabilities as described in
[SECURITY.md](../../SECURITY.md).

## What bier protects

| Asset | Protection |
| --- | --- |
| your package lists | never in the public repository; shared only with paired Macs |
| your dotfiles | encrypted with gpg (AES-256) before they leave `~/.bierfilevault` |
| your Mac | the agent never executes commands; Brewfiles are checked before `brew` sees them |
| the program itself | optionally, releases are verified against a signing key you pinned |

## The peer agent

Each Mac runs a small agent, reachable by paired Macs on TCP port 53991.

**It accepts**

- a public health check,
- the pairing handshake, while an offer is open,
- requests **signed with the Ed25519 key of a paired Mac** — within a
  five-minute clock window and with a nonce that is never accepted twice.

**It transfers only** `.gitattributes`, `Brewfiles/` and `Safe/` (already
encrypted), plus git history as verified bundles. Configuration, keys,
source code and the `.git` directory itself cannot cross.

**It rejects** path traversal, symlinks, duplicate or oversized chunks,
stale snapshots and any file not named in the manifest. Incoming data is
staged and replaces the live data only as a whole, after every digest
has been checked; an interrupted transfer is discarded. An existing Mac
accepts only history that contains its current commit — a peer cannot
rewrite history.

**It never** runs a shell command, a git command chosen by the peer, or
anything else it was sent. Details:
[peer data protocol](../../Sources/bier-agent/PEER-DATA-PROTOCOL.md).

### Transport

The connection is plain HTTP over TCP. Requests are authenticated;
**the traffic is not encrypted, and responses are not signed.** On the
network between two Macs this means:

- someone who can listen can read your package lists (the vault stays
  encrypted),
- someone who can intercept and alter traffic between two paired Macs
  could feed altered list content into a sync.

Use bier on networks you trust, or through a VPN you control.

## A paired Mac is trusted

Pairing is a statement of trust. A paired Mac — or someone controlling
it — can change the shared lists. Consequences, and what limits them:

- **Added entries** reach your Mac as *recorded but not installed*.
  Nothing is installed until you run `bier install` or accept it in the
  menu.
- **Removed entries** reach your Mac as *removed elsewhere*. Nothing is
  uninstalled until you confirm `bier prune`.
- **Code hidden in a Brewfile.** A Brewfile is Ruby: `brew bundle`
  evaluates it, and a line such as `brew "wget"; system("…")` would run.
  bier therefore checks **every whole line** against the grammar of a
  package entry. `bier install` and `bier take` refuse a file that holds
  anything else; `bier status` warns about it unasked. Options are
  allowed by name — `postinstall` is not, because its value is a shell
  command.
- **The vault.** A paired Mac knows the passphrase. If one is lost or
  leaves your hands, [change it](../vault/recovery.md#changing-it) and
  [retire](../using/retiring-a-mac.md) the Mac.

Only pair Macs you control.

## Who gets to run code on your Mac

`bier upgrade` checks out a release tag and runs its `install.sh`.
Whoever can push a tag to the program repository can therefore run code
on every installation that upgrades. That is the trust boundary.

[`bier trust`](signed-releases.md) narrows it: once you pin a signing
key, `bier upgrade` refuses any release that is not signed with it.

## Out of scope

- Anyone with access to your macOS user account. They can read the
  keychain, the plain vault files and the peer identity.
- The packages themselves. bier installs what Homebrew installs; whether
  a formula or cask is trustworthy is Homebrew's domain and yours.
- Macs you paired and no longer control, until you retire them.
