[Docs](../README.md) › Getting started

# Trial run

Before bier gets your whole inventory, try it with one harmless package
and one harmless file. For the trial you install in **manual** mode, which
keeps the Brewfiles exactly as you write them. Normal use is automatic
mode — the last step switches to it.

## On both Macs

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/MatthiasToberer/bierfile/main/bootstrap.sh)" _ --manual-inventory
```

## On the first Mac

Put a single entry into the shared list:

```sh
echo 'cask "firefox"' > ~/.barrel/data/Brewfiles/main
```

Add a test file to the vault — a made-up one, not your real `.zshrc`:

```sh
echo '# bier test' > ~/.fakezshrc
bier vault add ~/.fakezshrc
bier sync
```

## Pair and compare

On the second Mac:

```sh
bier peer offer
```

Use the same vault passphrase on both Macs when the installer asks.

On the first Mac, with the code the second one shows:

```sh
bier peer pair second-mac.local
```

The second installation is still untouched, so the first Mac's data and
history are copied over, and the two are synced. On the second Mac:

```sh
bier status          # firefox is recorded but not installed here
bier sync            # opens the vault with the shared passphrase
cat ~/.fakezshrc     # the file from the first Mac, a plain file
```

Change `~/.fakezshrc` on one Mac and `bier sync` there; `bier status` on
the other shows it as *newer in the safe*, and its next `bier sync` (or
BierMenu, on its own) puts it in place.

## Going live

When you are happy, switch both Macs to automatic recording:

```sh
bier config inventory automatic
```

The next `bier sync` records everything that is installed. Then, on the
Mac whose software should be the template, run `bier init` once, and
put the Macs into groups — see [Groups](../concepts/groups.md).

To remove the test file again everywhere: `bier vault drop ~/.fakezshrc`
— it goes to the Trash on every Mac.
