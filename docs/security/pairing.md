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
this step. Pairing then syncs once, so a Mac that already recorded its
own inventory keeps it and shares one history with the other afterwards.

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
as `_bier-agent._tcp`. By default paired Macs find each other by their
`.local` names, which only works while both are on the same local
network. Beyond it: [Tailscale](#syncing-beyond-the-local-network-tailscale)
or [SSH](#syncing-over-ssh).

## Syncing beyond the local network: Tailscale

If your Macs are not always on the same network — a laptop on the road,
a desktop at home — put them on a [Tailscale](https://tailscale.com)
network **before you install bier**. Tailscale connects your devices
directly and privately wherever they are, and it encrypts the traffic
between them, which also covers bier's unencrypted peer connection (see
the [threat model](threat-model.md#transport)).

1. Install Tailscale on every Mac, sign in with the same account and
   turn on MagicDNS, so each Mac is reachable by its name.
2. On the joining Mac, advertise its Tailscale name (example: `macbook`):

   ```sh
   bier peer offer --address macbook
   ```

3. On the already configured Mac (example: `mini`), use the printed
   destination and advertise this Mac's own Tailscale name:

   ```sh
   bier peer pair macbook --address mini
   ```

Enter the one-time code from the joining Mac. Both Macs now remember
Tailscale addresses; no manual replacement of `.local` entries is needed.
`--address` always names the Mac on which you run the command. It does
not change that Mac's Bier identity. Use the names shown in Tailscale;
full MagicDNS names or Tailscale IPv4 addresses also work.

Without `--address`, the existing local-network behavior is preserved.
For Macs paired previously, `bier peer add <tailscale-name>` and
`bier peer remove <old-name>.local` on each Mac can replace the stored
address without pairing again. Re-pairing does not remove old addresses.

Check `bier peer list` on both Macs, then `bier peer hello <other-mac>`
and `bier sync`. Tailscale must allow TCP port 53991 between the Macs.

## Syncing over SSH

Where SSH reaches a Mac — through a router, a jump host, or just because
you prefer it — bier can use that instead of a direct connection. A peer
written as **`user@host`** is always reached through an SSH tunnel to
its agent: nothing but SSH has to be reachable there, port 53991 stays
closed, and the traffic is encrypted by SSH.

1. On every Mac: System Settings › General › Sharing › **Remote Login**
   on, and key-based login in **both** directions — each Mac syncs with
   the other:

   ```sh
   ssh-copy-id you@macbook.example.org     # from mini
   ssh-copy-id you@mini.example.org        # from macbook
   ```

   `ssh you@macbook.example.org true` must work without a password
   prompt. Hosts from `~/.ssh/config` work too, written as `user@alias`
   — the `@` is what tells bier to go through SSH.

2. On the joining Mac, advertise how the other one reaches it:

   ```sh
   bier peer offer --address you@macbook.example.org
   ```

3. On the configured Mac, pair through SSH and advertise its own SSH
   address:

   ```sh
   bier peer pair you@macbook.example.org --address you@mini.example.org
   ```

From then on `bier sync`, `peer compare`, `knockout` and the rest open a
tunnel for each such peer, use it, and close it again. SSH and direct
peers can be mixed: one Mac over Tailscale, another over SSH.

What the agent does and does not accept:
[Threat model](threat-model.md).
