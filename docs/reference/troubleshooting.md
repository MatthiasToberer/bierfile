[Docs](../README.md) › Reference

# Troubleshooting

First, three commands:

```sh
bier version     # which build is running, and where
bier config      # which program, which lists, which Mac name
bier status      # what differs
```

## Before you start: what can go wrong

bier installs and **uninstalls** software on your Macs. Removing a
program can take its settings and data with it, and a wrong entry in
`main` reaches every Mac. bier asks before it uninstalls anything — but
have a working backup (Time Machine or equivalent) and check that it
restores. This is a hobby project provided without warranty.

## Symptoms

**`bier: command not found` right after installing**
The installer put `bier` on the `PATH`, but this shell does not know yet.
Open a new terminal or type `exec zsh`. If it persists, add the line
`install.sh` printed to `~/.zshrc`.

**`bier: command not found` after moving the program folder**
The config and the command in `~/.barrel/bin` still point at the old
place. Run `install.sh` again from the new location.

**`xcode-select --install` says the software is not available**
Download the Command Line Tools from
[developer.apple.com/download/all](https://developer.apple.com/download/all).

**`bier sync` fails with "could not synchronise Bier data with …"**
A paired Mac could not be reached — asleep, off, or on another network.
Wake it and try again. For Macs that are often apart, use
[Tailscale](../security/pairing.md#syncing-beyond-the-local-network-tailscale). A Mac that is gone for good:
[`bier retire`](../using/retiring-a-mac.md) and `bier peer remove`.

**Pairing fails**
The code is valid for ten minutes and locks after five wrong attempts.
Run `bier peer offer` again for a fresh one. Both Macs must reach each
other's `.local` name on TCP port 53991.

**The menu says "This app is X, bier is Y"**
BierMenu is older than the command. Click *Upgrade* or run
`bier upgrade --force`.

**A program keeps coming back after `brew uninstall`**
It is still on a list. Use `bier uninstall <name>` — see
[Removing software](../using/removing.md).

**A program shows up as "removed elsewhere" although you want it**
Keep it deliberately: `bier dump --adopt`.

**A removed entry is back after a sync**
When one Mac removes an entry while another adds something next to it,
git's line merge can bring the line back. `bier status` reports it and
`bier prune` clears it.

**`bier install` refuses: "lines that are not entries"**
A Brewfile contains something other than package entries — code that
`brew` would run. bier refuses on purpose. `bier status` shows the lines;
remove them from the file. See the
[threat model](../security/threat-model.md#a-paired-mac-is-trusted).

**A vault file was deleted by mistake**
`bier status` shows `^ vault … deleted here`. Before the next sync,
`bier vault --restore` puts it back; after it, look in the Trash of the
other Macs or in `~/.barrel/state/backups/`.

**A vault file stays `waiting: … is running`**
bier does not write into the settings of a running app. Quit the app,
then `bier sync` — or let BierMenu do it.

**The vault passphrase is not accepted**
Every Mac needs the same passphrase. If it was changed elsewhere, enter
the new one with `bier vault --init`. If it is lost, the vault cannot be
opened — see [Passphrase and recovery](../vault/recovery.md).

**`bier upgrade` refuses: "not signed with the key this Mac trusts"**
Someone may have published a release that the key holder did not sign.
Do not work around it; report it. To stop verifying on purpose:
`bier trust --forget`.

**`bier update` says it was split**
It was, in 0.12.0: `bier sync` for your Macs, `bier upgrade` for the
program.

## Still stuck

Open an [issue](https://github.com/MatthiasToberer/bierfile/issues) with
the output of `bier version` and the failing command. Leave out your
package lists if you do not want them public. Security problems:
[SECURITY.md](../../SECURITY.md).
