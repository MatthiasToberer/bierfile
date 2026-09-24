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
bier main
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
bier list                   # what do the others have on top?
bier take                   # adopt some of it
bier uninstall htop         # asks: everywhere, only out of main, or only here
bier prune                  # remove here what was deleted elsewhere
bier vault add ~/.zshrc     # a file, not only packages
bier knockout               # sign off and take bier off this Mac
```

That is all. Everything else is detail — see the
[command reference](../reference/commands/README.md).

---

**Next:** [The seven-minute pilsner](seven-minute-pilsner.md)
