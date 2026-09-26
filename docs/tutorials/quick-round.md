[Docs](../README.md) › Tutorials

# The quick round

The commands and nothing else. For anyone who knows what a terminal is —
everything is explained step by step in
[the seven-minute pilsner](seven-minute-pilsner.md).

**You need** macOS, [Homebrew](https://brew.sh) and the Command Line
Tools (`xcode-select --install`). Details:
[Installation](../start/installation.md).

**Macs not always on the same network?** Set up
[Tailscale](https://tailscale.com) on every Mac first and pair with
Tailscale names — see
[Syncing beyond the local network](../security/pairing.md#syncing-beyond-the-local-network-tailscale).

## The first Mac

The one whose software should serve as the template:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/MatthiasToberer/bierfile/main/bootstrap.sh)"
bier init
```

`command not found`? Open a new terminal or type `exec zsh`.

## Every further Mac

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/MatthiasToberer/bierfile/main/bootstrap.sh)"
bier peer offer               # shows a one-time code
```

Back on the first Mac:

```sh
bier peer pair second-mac.local
```

Enter the code. The Macs now trust each other, and the first Mac's data
is copied to the untouched second installation. Then, on the second Mac:

```sh
bier install
```

## Every day

```sh
bier sync                   # record here, exchange with peers — after every install
bier status                 # what differs here?
bier list                   # All Macs, each group, what is not assigned
bier group laptops mini macbook          # every Mac is in one group
bier place firefox --on laptops --now    # software for a group, right away
bier uninstall htop         # asks: everywhere, off All Macs, or off a group
bier prune                  # remove here what was taken off elsewhere
bier share handbrake-app    # an app's settings, for All Macs or --for a group
bier vault add ~/.zshrc     # a file, not only packages
bier knockout               # sign off and take bier off this Mac
```

That is all. Everything else is detail — see the
[command reference](../reference/commands/README.md).

---

**Next:** [The seven-minute pilsner](seven-minute-pilsner.md)
