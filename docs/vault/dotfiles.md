[Docs](../README.md) › Vault

# Dotfiles and app settings in the vault

Packages are half of what makes a Mac yours. The vault carries the other
half: `.zshrc`, an editor's configuration, an app's settings and
profiles.

```sh
bier vault add ~/.zshrc
bier vault add ~/Library/Application\ Support/HandBrake
```

The file stays where it is; the vault keeps a copy. `bier sync` encrypts
it and shares it; the next `bier sync` on another Mac decrypts it and
puts it in place — or BierMenu does, on its own. Change it on any Mac
and sync, and the others get the change.

A walk-through with two Macs:
[Your dotfiles on a new Mac](../tutorials/dotfiles-on-a-new-mac.md).

## How it is stored

| Where | What |
| --- | --- |
| the file's own place | the real file, as always |
| `~/.barrel/vault` | a plain copy, outside every repository |
| `~/.barrel/data/Safe/` | the encrypted copies — the only part that travels |
| the keychain | this Mac's working copy of the passphrase |

Encryption is gpg, symmetric, AES-256, under **one passphrase all your
Macs share**. A new Mac needs nothing but that passphrase. Because the
plain copies live outside the data repository, nothing can commit them
by accident.

Names in the vault mirror the path below your home folder, with `dot_`
for a leading dot: `~/.config/nvim/init.lua` is
`dot_config/nvim/init.lua`.

## Commands

| Command | Effect |
| --- | --- |
| `bier vault` | what is in it, and whether this Mac knows the passphrase |
| `bier vault add <path>…` | take files or folders in |
| `bier vault add --for <group> <path>` | only for some Macs — see [Groups](groups.md) |
| `bier vault forget <path>` | stop syncing it; the file stays **on every Mac** |
| `bier vault drop <path>` | remove it **everywhere**, into the Trash, after asking |
| `bier vault --restore` | put back a file deleted here by mistake, from the vault's copy |
| `bier vault --init` | enter the passphrase on this Mac |
| `bier vault --passphrase` | change the passphrase everywhere |

## Folders

A folder is tracked as a whole: files put in it later come along with
the next sync, and files deleted from it go to the Trash on the other
Macs — Finder's *Put Back* brings them back.

Folders are meant for **settings and profiles**, not for documents. Every
version of every file stays in the history on every Mac, and encrypted
files do not compress against each other. So:

- files larger than `vault_max_file` (10 MB unless set in the
  [config](../reference/configuration.md)) are not taken in, and `bier
  status` names them;
- `.DS_Store`, `*.lock`, `*.log` and folders called `Cache`, `Caches`,
  `Logs` or `.git` are left out.

## Apps that are running

An app writes its settings back when it quits — over whatever bier put
there in the meantime. So bier does not write into the settings of a
running app, under `~/Library/Containers/<app>`,
`~/Library/Application Support/<App>` or
`~/Library/Preferences/<app>.plist`. `bier status` shows

```
  .  vault            ~/Library/Application Support/HandBrake/presets.json waiting: HandBrake is running
```

and the first sync after quitting the app applies it. Preference files
— in `~/Library/Preferences` or in an app's container — are written
through `defaults import`, so the system's preferences cache picks them
up.

Settings inside `~/Library/Containers` are protected by macOS: a program
needs permission to read another app's data. Allow it when macOS asks
for your terminal, or give it — and `~/.barrel/BierMenu.app`, which
applies changes on its own — access under System Settings › Privacy &
Security › Full Disk Access.

## When it changes

Each Mac remembers what it and the safe last agreed on, so a sync knows
which side changed:

| Changed | bier sync does |
| --- | --- |
| only here | encrypts it and hands it to the other Macs |
| only elsewhere | puts the new version in place here, after a backup |
| on both sides | keeps yours and puts the other next to it as `<name>.from-safe` |
| deleted here | takes it out of the safe; the other Macs move it to the Trash |
| deleted elsewhere | moves it to the Trash here — unless it changed here, then it stays |

After a conflict, merge what you need, delete the `.from-safe` copy and
sync again; your version then goes everywhere. `bier status` lists what
is waiting, see [Everyday use](../using/everyday.md#what-differs-here).

## When a file already exists

The first time a file arrives on a Mac that already has one of its own
— every Mac has a `.zshrc` — the shared one wins and the own one is kept
as `<name>.backup`. Letting the new Mac's file win would send its
default to every other Mac. An identical file needs no backup. A link
at that place pointing somewhere else is left alone, and bier says so.

## Backups

Before bier overwrites a file with a version from another Mac, it keeps
a copy under `~/.barrel/state/backups/<date>/`. `vault_backup = no` in
the [config](../reference/configuration.md) turns that off.

## Why copies and not links

bier used to leave a link in place of each file. Sandboxed apps may not
follow a link out of their container, apps that save by writing a new
file replace the link, and removing bier would have taken the files
along. With copies, every file stays a real file — and `rm -rf ~/.barrel`
leaves them all where they are. An installation from the time of links
turns them back into files on its first sync.
