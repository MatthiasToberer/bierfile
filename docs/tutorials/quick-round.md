[Docs](../README.md) › Tutorials

# The quick round

The commands and nothing else. For anyone who knows what a terminal is —
everything is explained step by step in
[the seven-minute pilsner](seven-minute-pilsner.md).

**You need** macOS, [Homebrew](https://brew.sh) and the Command Line
Tools (`xcode-select --install`). Details:
[Installation](../start/installation.md).

## The first Mac

The one whose software should serve as the template:

```sh
git clone https://github.com/MatthiasToberer/bierfile.git ~/bierfile
~/bierfile/install.sh
bier main
```

`command not found`? Open a new terminal or type `exec zsh`.

## Every further Mac

```sh
git clone https://github.com/MatthiasToberer/bierfile.git ~/bierfile
~/bierfile/install.sh
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
bier uninstall htop         # get rid of it everywhere
bier prune                  # remove here what was deleted elsewhere
bier vault add ~/.zshrc     # a file, not only packages
```

That is all. Everything else is detail — see the
[command reference](../reference/commands/README.md).

---

**Next:** [The seven-minute pilsner](seven-minute-pilsner.md)
