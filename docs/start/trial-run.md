[Docs](../README.md) › Getting started

# Trial run

Before bier gets your whole inventory, try it with one harmless package
and one harmless file. For the trial you install in **manual** mode, which
keeps the Brewfiles exactly as you write them. Normal use is automatic
mode — the last step switches to it.

## On both Macs

```sh
git clone https://github.com/MatthiasToberer/bierfile.git ~/bierfile
~/bierfile/install.sh --manual-inventory
```

## On the first Mac

Put a single entry into the shared list:

```sh
echo 'cask "firefox"' > ~/bierdata/Brewfiles/main
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
history are copied over. On the second Mac:

```sh
bier status          # firefox is recorded but not installed here
bier sync            # opens the vault with the shared passphrase
ls -l ~/.fakezshrc   # a link into ~/.bierfilevault
```

## Going live

When you are happy, switch both Macs to automatic recording:

```sh
bier config inventory automatic
```

The next `bier sync` records everything that is installed. Then, on the
Mac whose software should be the template, run `bier main` once — see
[main and device lists](../concepts/lists.md).

To remove the test file again everywhere: `bier vault drop ~/.fakezshrc`.
