[Docs](../../README.md)

# Commands

`bier help` prints the same overview in the terminal.

## Every day

| Command | What it does |
| --- | --- |
| [`bier sync [--record] [message]`](sync.md) | record, exchange with peers, merge — the everyday command |
| [`bier status`](status.md) | what differs on this Mac? |
| [`bier list`](list.md) | All Macs, each group, and what is not assigned |

## Groups and software

| Command | What it does |
| --- | --- |
| [`bier group …`](group.md) | groups of Macs; move a Mac; a group's rules |
| [`bier place <pkg> --all \| --on <group> [--now]`](place.md) | where a package belongs, now or later |
| [`bier search <name>`](search.md) | what Homebrew and the App Store have by that name |
| [`bier install`](install.md) | install what All Macs and this Mac's group have |
| [`bier apply`](apply.md) | install and remove what the lists say for here |
| [`bier undo <commit>`](undo.md) | take back one change, on every Mac |
| [`bier add <pkg>…`](add.md) | install, give it to All Macs or a group, offer its settings |
| [`bier share [--for <group>] <app>`](share.md) | share an app's settings and profiles |
| [`bier uninstall <pkg>…`](uninstall.md) | uninstall; asks which lists lose it |
| [`bier prune [--yes]`](prune.md) | remove what was taken off a list this Mac follows |

## Setting up

| Command | What it does |
| --- | --- |
| [`bier init`](init.md) | make this Mac's software what All Macs have — once, on the first Mac |

## Files, peers and the fleet

| Command | What it does |
| --- | --- |
| [`bier vault …`](vault.md) | encrypted dotfiles |
| [`bier peer …`](peer.md) | pairing and peer exchange |
| [`bier retire <name>`](retire.md) | take a Mac out of the fleet |
| [`bier knockout`](knockout.md) | take bier off this Mac, signing off at the others |
| [`bier access`](access.md) | let bier read app settings in their sandbox (Full Disk Access) |
| [`bier brewmaster`](brewmaster.md) | check this Mac, its peers and the vault, like `brew doctor` |
| `bier fleet` | every paired Mac's own state, asked over the network and kept |
| `bier admin offer \| list \| remove` | let Bierkasten connect to this Mac |
| `bier report` | everything this Mac knows, in lines |
| [`bier view <page> --json`](view.md) | a page of Bierkasten, worked out, as JSON |

## The program

| Command | What it does |
| --- | --- |
| [`bier upgrade [--force]`](upgrade.md) | install a newer release of bier |
| [`bier trust [url]`](trust.md) | verify releases against a pinned key |
| [`bier config`](config.md) | settings in effect |
| [`bier version`](version.md) | version, commit and paths |
| [`bier state`](state.md) | machine-readable state for BierMenu |

## Out of sight

Not in `bier help`, because another command does their job. They still
work and say what to use instead.

| Command | Instead |
| --- | --- |
| [`bier dump`](dump.md) | `bier sync` records what is installed |
| [`bier push`](push.md) | `bier sync` commits and passes on |
| [`bier diff`](diff.md) | `bier list`, or Bierkasten |
| [`bier take`](take.md) | `bier place` |
