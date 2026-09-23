[Docs](../README.md) › Peers & security

# Pairing

Paired Macs exchange your lists and their history directly — no SSH
login, no data server, no account. Pairing is how two Macs learn to trust
each other.

## Pair two Macs

On the Mac that joins:

```sh
bier peer offer
```

```
Pairing is open for 10 minutes.
On the other Mac run:  bier peer pair macbook.local
One-time code: 3f9a-c21e-…
```

On a Mac that is already set up, run the printed command and enter the
code:

```sh
bier peer pair macbook.local
```

Both Macs now know each other's public key and address. If the joining
Mac's data repository is still untouched, the other Mac copies its lists,
vault and complete history over. Existing data is never overwritten by
this step.

From then on, `bier sync` exchanges with every paired Mac.

## What protects the pairing

- The code is random (128 bits), valid for **ten minutes** and locks
  after **five** wrong attempts.
- The code itself never crosses the network. The pairing Mac proves it
  knows the code with HMAC-SHA256, and the offering Mac authenticates its
  answer the same way — so neither side can be replaced by a machine in
  between while the keys are exchanged.
- Each Mac has its own Ed25519 identity, created by the installer. It is
  used only by bier and is not an SSH key.
- The offer is deleted as soon as it has been used.

## Managing peers

| Command | Effect |
| --- | --- |
| `bier peer list` | Macs this one exchanges with |
| `bier peer remove <host>` | forget a Mac |
| `bier peer hello <host>` | check that the other agent accepts this Mac |
| `bier peer compare <host>` | compare data with a peer, change nothing |
| `bier peer sync <host>` | exchange with one peer only |
| `bier peer discover` | list bier agents announced on the local network |

The full list, including remote installation over SSH:
[`bier peer`](../reference/commands/peer.md).

## Network

The agent listens on **TCP port 53991** and announces itself via Bonjour
as `_bier-agent._tcp`. Paired Macs find each other by their `.local`
names, so they need to be on the same network — or on a network that
resolves those names, such as a VPN you set up yourself.

What the agent does and does not accept:
[Threat model](threat-model.md).
