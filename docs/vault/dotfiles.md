[Docs](../README.md) › Vault

# Dotfiles and app settings in the vault

Packages are half of what makes a Mac yours. The vault carries the other
half: `.zshrc`, an editor's configuration, an app's settings and
profiles.

```sh
bier vault add ~/.zshrc
bier add handbrake-app          # installs it, and offers its settings
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
`dot_config/nvim/init.lua`. An app's settings sit under `apps/<App>/`
instead, whatever long path they have on the Mac —
`apps/HandBrake/Application Support/` — and `apps/<App>/.bier-map` says
where each belongs. [`bier add`](../reference/commands/add.md) puts them
there, or by hand:

```sh
bier vault add --app HandBrake ~/Library/Containers/fr.handbrake.HandBrake/Data/Library/Application\ Support/HandBrake
```

## Commands

| Command | Effect |
| --- | --- |
| `bier vault` | what is in it, and whether this Mac knows the passphrase |
| `bier vault add <path>…` | take files or folders in |
| `bier vault add --for <group> <path>` | only for some Macs — see [Groups](groups.md) |
| `bier vault add --app <App> <path>` | an app's settings, kept under `apps/<App>/` |
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
- `.DS_Store`, `*.lock`, `*.log`, `*log.txt`, folders whose name
  contains `cache` in any spelling, and folders called `Logs`, `logs` or
  `.git` are left out, and whatever `vault_exclude`
  in the config names — an app's own noise, such as HandBrake's queue:
  `vault_exclude = *.hbqueue`;
- files that may hold keys or passwords — named like tokens, passwords,
  secrets or credentials, `.pem`, `.key`, `.p12`, keychains — stay out
  of a folder; add one by itself if it should travel.

## Apps that are running

A running app may be writing its settings at any moment, and writes
them back when it quits — over whatever bier put there in the meantime.
So bier neither takes nor writes the settings of a running app, under `~/Library/Containers/<app>`,
`~/Library/Application Support/<App>` or
`~/Library/Preferences/<app>.plist`. `bier status` shows

```
  .  vault            ~/Library/Application Support/HandBrake/presets.json waiting: HandBrake is running
```

and the first sync after quitting the app shares or applies it. Quit an
app before syncing its settings. A sandboxed app
that has never run on this Mac has no container yet; bier starts it
once, hidden, so that macOS sets one up, quits it, and then puts the
settings in. Preference files
— in `~/Library/Preferences` or in an app's container — are written
through `defaults import`, so the system's preferences cache picks them
up.

Settings inside `~/Library/Containers` are protected by macOS: a program
needs Full Disk Access to read another app's data — your terminal, and
`~/.barrel/BierMenu.app`, which runs bier on its own.
[`bier access`](../reference/commands/access.md) opens the place to
grant it. Until then `bier status` marks those settings `no access`,
and a sync leaves them alone; they are never taken for deleted.

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
