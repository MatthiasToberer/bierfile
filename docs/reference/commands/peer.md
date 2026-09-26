[Docs](../../README.md) › [Commands](README.md)

# bier peer

```
bier peer <subcommand> [host]
```

Manages the Macs this one exchanges data with.

## Pairing and everyday use

| Command | Effect |
| --- | --- |
| `offer [--address <own-host>]` | open pairing for ten minutes and show a one-time code |
| `pair <host> [--address <own-host>]` | pair with a Mac that shows a code, then sync; copies data to it if it is untouched |
| `list` | Macs this one exchanges with |
| `remove <host>` | forget a Mac: its address, or its key when given the name it signs with |
| `address <mac> <new-address>` | reach a Mac at a new address — say Tailscale instead of the local network — keeping its key |
| `hello <host>` | check that the other agent accepts this Mac |
| `compare <host>` | compare verified data with a peer, change nothing |
| `sync <host>` | exchange data and history with one peer |
| `seed <host>` | copy this Mac's data to a peer whose data is empty |
| `discover` | list bier agents announced via Bonjour |
| `candidates` | Macs that could join: online Macs on the tailnet and bier agents on the local network, not yet paired — for Bierkasten's Add Mac |
| `trust [url]` | alias for [`bier trust`](trust.md) |

`--address` advertises this Mac's reachable name or IPv4 address — or
`user@host` to be reached over SSH. Use it on both commands for
[Tailscale](../../security/pairing.md#syncing-beyond-the-local-network-tailscale)
or [SSH](../../security/pairing.md#syncing-over-ssh). A peer written as
`user@host` is always reached through an SSH tunnel.

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
