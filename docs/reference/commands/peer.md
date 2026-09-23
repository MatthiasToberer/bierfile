[Docs](../../README.md) › [Commands](README.md)

# bier peer

```
bier peer <subcommand> [host]
```

Manages the Macs this one exchanges data with.

## Pairing and everyday use

| Command | Effect |
| --- | --- |
| `offer` | open pairing for ten minutes and show a one-time code |
| `pair <host>` | pair with a Mac that shows a code; copies data to it if it is untouched |
| `list` | Macs this one exchanges with |
| `remove <host>` | forget a Mac |
| `hello <host>` | check that the other agent accepts this Mac |
| `compare <host>` | compare verified data with a peer, change nothing |
| `sync <host>` | exchange data and history with one peer |
| `seed <host>` | copy this Mac's data to a peer whose data is empty |
| `discover` | list bier agents announced via Bonjour |
| `trust [url]` | alias for [`bier trust`](trust.md) |

## Remote installation over SSH

For bootstrapping a Mac you can reach by SSH but not sit at:

| Command | Effect |
| --- | --- |
| `discover -ssh` | list Macs with Remote Login via Bonjour |
| `check <host>` | check non-interactive SSH access |
| `add <host>` | remember a Mac without pairing |
| `install <host>` | install a signed bier agent over SSH |
| `upgrade <host>` | replace that agent with the latest signed release |
| `uninstall <host>` | stop and remove it again |

Normal setups do not need these — [pairing](../../security/pairing.md)
works without SSH.
