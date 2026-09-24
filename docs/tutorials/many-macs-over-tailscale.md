[Docs](../README.md) › Tutorials

# One Mac, then any number, over Tailscale

Macs that are not always on the same network: at home, at work, on the
road. Tailscale connects them; bier needs no server of its own. Each new
Mac is paired with **one** Mac, and meets the others through it.

The names below are examples: `studio` is the first Mac, `laptop` and
`mini` come later, and the tailnet is `example.ts.net`.

## 1. Tailscale on every Mac

Install [Tailscale](https://tailscale.com), sign in with the same account
on every Mac, and leave MagicDNS on (the default).

bier needs each Mac's **full** name, not the short one Tailscale shows
in its menu: `laptop.example.ts.net`, not `laptop`. The admin console
lists them under *Machines*; the tailnet name is under *DNS*.

Tailscale has to be running on both Macs whenever they talk: pairing
and every sync.

## 2. The first Mac

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/MatthiasToberer/bierfile/main/bootstrap.sh)"
bier main                  # this Mac's software is the template for all
bier vault add ~/.zshrc    # optional: files and settings, not only packages
bier sync
```

## 3. The second Mac

On the new Mac (`laptop`):

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/MatthiasToberer/bierfile/main/bootstrap.sh)"
bier peer offer --address laptop.example.ts.net    # shows a one-time code
```

On the first Mac:

```sh
bier peer pair laptop.example.ts.net --address studio.example.ts.net
```

Enter the code. The two trust each other now, and `laptop` has the data.
Back on `laptop`:

```sh
bier vault --init          # the vault passphrase, if you share files
bier install               # what is on the lists and not here yet
```

## 4. Every further Mac

The same as for the second, with the first Mac or any other paired one:

```sh
# on mini
bier peer offer --address mini.example.ts.net
# on studio
bier peer pair mini.example.ts.net --address studio.example.ts.net
# on mini
bier vault --init
bier install
```

`mini` knows `studio` now, but not `laptop`. The next `bier sync` on
`studio` introduces them to each other:

```sh
# on studio
bier sync
```

```
Introduced mini to laptop; accept it there with: bier peer accept mini
Introduced laptop to mini; accept it there with: bier peer accept laptop
```

Nobody trusts an introduced Mac yet. Accept it **once**, on either side,
for example on `mini`:

```sh
bier peer pending          # who waits, who introduced it, key fingerprint
bier peer accept all       # or: bier peer accept laptop
bier sync
```

```
Accepted laptop (laptop.example.ts.net), introduced by studio; it trusts mini now as well.
```

Done: every Mac talks to every other one. With a fifth Mac it is the
same: pair with one, `bier sync` there, `bier peer accept all` on the
new one.

The menu bar and `bier brewmaster` point out a Mac that waits. Not
wanted? `bier peer reject laptop`.

## When something does not connect

- `hostname not found`, `Internet connection appears to be offline`:
  Tailscale is not running on one of the two Macs, or the short name was
  used instead of the full one.
- `bier brewmaster` checks every peer and says what to do.
- Why this is safe: [Pairing](../security/pairing.md#a-third-mac-introduce-then-accept).
