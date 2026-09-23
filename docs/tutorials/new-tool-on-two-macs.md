[Docs](../README.md) › Tutorials

# Two Macs: installing something new

The everyday case. Two Macs, `mini` and `macbook`, already set up and
paired. You install a tool on one and decide it belongs on both.

## On mini

```sh
brew install ripgrep
```

The glass in the menu bar empties. A click shows why:

```
1 installed but not recorded
    ripgrep  (formula)
Pour a round: record and push
```

Click **Pour a round** — or type:

```sh
bier sync
```

bier records ripgrep in `Brewfiles/mini`, commits and exchanges the
history with macbook. The glass is full again.

## On macbook

mini's sync has already delivered the entry here, but macbook's glass
stays full: ripgrep is something *mini* has on top, and nothing macbook
is supposed to have. `bier list` shows it:

```
On top of main, and where:
  brew "ripgrep"                               mini
```

To have it everywhere, move it into the shared list:

```sh
bier take
```

```
What other devices have on top of main:

   1  brew "ripgrep"                               mini

Numbers (e.g. 1 3-5), empty = cancel: 1
Where to?  [m] into main, for all devices   [h] only macbook   [c] cancel: m

Plan:
  brew "ripgrep"
    + Brewfiles/main
    - Brewfiles/mini

Apply and push? [y/N] y
…
Install now? [y/N] y
```

Both Macs now have ripgrep. A `bier sync` passes the move on, and every
Mac you pair later gets ripgrep with `bier install`.

## What happened

- A new package always lands in the list of the Mac it was installed on.
  bier never promotes an entry to every Mac on its own — that decision is
  yours, and `bier take` is where you make it.
- Answering `h` instead of `m` would have put ripgrep on macbook's own
  list only; mini would keep its entry, and a third Mac would not get it.
- The rule behind this: [main and device lists](../concepts/lists.md).

---

**Next:** [Three Macs: one with special equipment](special-equipment.md)
