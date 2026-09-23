[Docs](../../README.md)

# Commands

`bier help` prints the same overview in the terminal.

## Every day

| Command | What it does |
| --- | --- |
| [`bier sync [message]`](sync.md) | record, exchange with peers, merge — the everyday command |
| [`bier status`](status.md) | what differs on this Mac? |
| [`bier list`](list.md) | overview of all Macs |
| [`bier diff [host…]`](diff.md) | compare this Mac's lists with other Macs |

## Changing the inventory

| Command | What it does |
| --- | --- |
| [`bier install`](install.md) | install `main` and this Mac's own list |
| [`bier take [--from-main]`](take.md) | move entries between `main` and device lists |
| [`bier uninstall <pkg>…`](uninstall.md) | uninstall and remove from every list |
| [`bier prune`](prune.md) | remove what was deleted on another Mac |
| [`bier dump [--adopt]`](dump.md) | record this Mac's extras |
| [`bier push [message]`](push.md) | commit the lists without recording |
| [`bier main`](main.md) | create `main` from this Mac — once |

## Files, peers and the fleet

| Command | What it does |
| --- | --- |
| [`bier vault …`](vault.md) | encrypted dotfiles |
| [`bier peer …`](peer.md) | pairing and peer exchange |
| [`bier retire <name>`](retire.md) | take a Mac out of the fleet |

## The program

| Command | What it does |
| --- | --- |
| [`bier upgrade [--force]`](upgrade.md) | install a newer release of bier |
| [`bier trust [url]`](trust.md) | verify releases against a pinned key |
| [`bier config`](config.md) | settings in effect |
| [`bier version`](version.md) | version, commit and paths |
| [`bier state`](state.md) | machine-readable state for BierMenu |
