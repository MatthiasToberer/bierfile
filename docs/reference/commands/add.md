[Docs](../../README.md) › [Commands](README.md)

# bier add

```
bier add [--main | --here] [--settings | --no-settings] <package>…
```

Installs each package if it is not here yet — a cask, a formula, or an
App Store app by its store name (`bier add Pages`, installed with `mas`
and listed with its store id) —, puts it on a list and commits:

- `m` / `--main` — into `main`, for every Mac;
- `h` / `--here` — only onto this Mac's list.

For an app, bier then looks where it keeps its settings: in the places
Homebrew's *zap* list names for the cask — everything the app leaves
outside `/Applications`, kept by hand for thousands of apps —, in its
sandbox container, `~/Library/Application Support` and
`~/Library/Preferences`; for a command-line tool in `~/.config/<name>`.
For an App Store app bier finds the app by its store id and looks into
its sandbox container. Caches, logs, web data, window state and
recent-file lists are left out. It offers what exists on this Mac, with
its size:

```
HandBrake keeps its settings here:
   1  Library/Containers/fr.handbrake.HandBrake/Data/Library/Application Support/HandBrake   12K
   2  Library/Containers/fr.handbrake.HandBrake/Data/Library/Preferences/fr.handbrake.HandBrake.plist   4.0K
      settings; also window positions and recent files
Share them with your other Macs?  numbers, a = all, empty = none:
```

What you pick goes into the vault under `apps/<App>/`, and `bier sync`
shares it.

**Never offered on its own:** anything that may hold keys, passwords or
accounts — `~/.ssh`, `~/.gnupg`, keychains, files named like tokens,
passwords, secrets or credentials, `.pem`/`.key`/`.p12` — and the
settings of VPN clients and password managers (Tailscale, WireGuard,
Tunnelblick, Bitwarden, 1Password, KeePassXC, …). Such files also stay
out of a shared folder. To share one anyway, add it by hand with
`bier vault add`. Settings of something added only here are shared with this
Mac only. What is shared already is not offered again.

On a Mac that receives the settings of a sandboxed app it has never
started, bier starts the app once, hidden, so that macOS sets up its
container, quits it, and puts the settings in. Where the app is not
installed yet, the settings wait until it is.

Without a terminal to ask at, `--main`/`--here` and
`--settings`/`--no-settings` say it up front. Settings that live
elsewhere — iCloud, group containers — are not found; add them with
`bier vault add --app <App> <path>`.

**See also:** [`uninstall`](uninstall.md), [Vault](../../vault/dotfiles.md)
