[Docs](../README.md) › Contributing

# The barrel: one folder, copies instead of links

Design for the move to `~/.barrel`, agreed on 2026-09-24. It is built in
four steps, in this order; each one ships on its own.

## Goal

bier shows itself as little as possible, and leaving it is one command:

```sh
rm -rf ~/.barrel
```

Afterwards every file of yours is still where it was. What remains
outside is harmless, and `bier knockout` removes that too — after
signing off at the other Macs.

## Layout

```
~/.barrel/
  bier/        the program: a signed release, or a development checkout
  bin/bier     the command
  BierMenu.app the menu bar app
  config       settings (was ~/.config/bier/config)
  peers        paired Macs (was ~/.config/bier/peers)
  allowed_signers, allowed_signers.url   pinned release key
  data/        lists and safe, a git repository shared with peers only
  vault/       plain copies of the files in the safe, no git
  state/       what this Mac and the safe last agreed on, peers, backups
  agent/       the agent, its identity, peer_signers, state
```

Why the vault is not inside `data/` or `bier/`: both are git working
copies. `bier/` is public, `data/` travels to every peer. A plain file
committed by mistake would be published, or spread unencrypted into
every peer's history for good. Side by side in one folder keeps the
order without that risk.

### What has to live outside

| Outside `~/.barrel` | Why | After `rm -rf ~/.barrel` |
| --- | --- | --- |
| `~/Library/LaunchAgents/com.bier.agent.plist` | starts the agent at login | the plist checks for `~/.barrel` first; if it is gone it unloads and deletes itself |
| `PATH` line in `~/.zshrc` | the `bier` command | points at nothing, harmless |
| keychain item `bier-vault` | the only safe place for the passphrase | stays; `bier knockout` removes it |
| BierMenu's login item | "Start at login" | stale, harmless |
| the other Macs | know this Mac's key and address | keep trying to reach it; `bier knockout` signs off |

## Copy mode

The vault used to be links: `~/.zshrc` pointed into the vault. That
breaks for app settings — sandboxed apps may not follow a link out of
their container, apps that save atomically replace the link with a
plain file, and `cfprefsd` caches preference files — and with the barrel
it would make `rm -rf ~/.barrel` take the files with it.

Now every file stays a real file where it belongs. The vault holds a
copy, the safe the encrypted version, and `state/vault-base` what this
Mac and the safe last agreed on (a salted hash of the content, and the
hash of the encrypted file).

What a sync does per file:

| Here since last agreed | In the safe | `bier sync` |
| --- | --- | --- |
| changed | unchanged | copies it into the vault, seals it, hands it on |
| unchanged | changed | backs up the file here, then puts the new version in place |
| changed | changed | keeps this Mac's file, puts the other next to it as `<file>.from-safe` |
| deleted | unchanged | deletes it from the safe; the other Macs move it to the Trash |
| unchanged | deleted | moves the file here to the Trash |
| changed | deleted | keeps the file and reports it |

"The Trash" is `/usr/bin/trash`, so Finder's *Put Back* works; where it
is missing, `~/.Trash`.

### Folders

`bier vault add <folder>` tracks the folder itself: files put in it
later are taken in by the next sync, files deleted from it go to the
Trash on the other Macs — `rsync -a --delete` with a Trash. The folder
is marked in the safe by `Safe/<folder>/.bier-folder.gpg`, one marker
per folder, so two Macs adding different folders never conflict.

Folders are meant for app settings and profiles, not for documents.
Every version of every file stays in the history of `data/` on every
Mac, and encrypted files do not compress against each other. So:

- files larger than `vault_max_file` (default `10M`) are not taken in,
  and `status` says so;
- `.DS_Store`, `*.lock`, `*.log`, and folders named `Cache`, `Caches`,
  `Logs` or `.git` are left out.

### Apps that are running

An app overwrites its settings when it quits. bier therefore does not
write into a path that belongs to a running app — under
`~/Library/Containers/<bundle id>/`, `~/Library/Application Support/<Name>/`
or `~/Library/Preferences/<bundle id>.plist` — and `status` shows
*waiting: <app> is running*. The next sync after quitting applies it.
Preference files are written with `defaults import`, so `cfprefsd`
picks them up.

### Backups

`vault_backup = yes` (the default) copies a file to
`state/backups/<date>/<path>` before bier overwrites it with a version
from another Mac, and before `vault add` takes it in.

### forget and drop

- `bier vault forget <path>` — stop syncing it; the file stays on every
  Mac. Leaves `Safe/<name>.forgotten` so the other Macs stop too.
- `bier vault drop <path>` — gone everywhere: the other Macs move it to
  the Trash.

## Moving an existing installation

`install.sh` and `bier upgrade` move an old layout in once:

| Old | New |
| --- | --- |
| `~/.config/bier/{config,peers,allowed_signers*}` | `~/.barrel/` |
| `~/.local/share/bier/agent` | `~/.barrel/agent` |
| `~/.local/state/bier` | `~/.barrel/state` |
| `~/bierdata` (if the config names it) | `~/.barrel/data` |
| `~/.bierfilevault`, links in `~` | `~/.barrel/vault`, plain files in `~` |
| `~/.local/bin/bier` | `~/.barrel/bin/bier` |
| `/Applications/BierMenu.app` | `~/.barrel/BierMenu.app` |

A data folder or vault set elsewhere in the config stays where it is.
A development checkout stays where it is; `root` in the config keeps
pointing at it.

## Installing

Like Homebrew, one line:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/MatthiasToberer/bierfile/main/bootstrap.sh)"
```

`bootstrap.sh` checks the prerequisites, clones the latest release tag
into `~/.barrel/bier`, verifies its signature against the key published
on a separate host, and runs `install.sh` from there.

## Leaving: `bier knockout`

1. one last sync, so nothing made here is lost;
2. `retire --self`: out of `Brewfiles/`, out of every vault group;
3. sign off at every paired Mac: a signed `POST /v1/peer/leave` makes
   that Mac's agent forget exactly the sender — its key and its
   address; an unreachable Mac is named with what to run there;
4. take bier off this Mac: agent and LaunchAgent, BierMenu, the command,
   the `PATH` line, the passphrase in the keychain;
5. ask whether to delete `~/.barrel` as well, or keep the data and the
   vault.

It needs the word `knockout` typed at a terminal. `install.sh
--uninstall` runs the same.

## Order

1. copy mode, folders, backups, Trash
2. `~/.barrel` layout and moving existing installations
3. `bootstrap.sh`
4. `bier knockout`
