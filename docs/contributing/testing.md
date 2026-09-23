[Docs](../README.md) › Contributing

# Tests

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

## Adding a case

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

## Before pushing

`.githooks/pre-push` requires green tests before code reaches the server
— the other Mac picks that state up on its next `bier upgrade` and builds
it. If a case is red, the push is aborted.

    pre-push: code changed, running tests …
    pre-push: 17 cases, all passed.

`install.sh` installs the hook (`core.hooksPath`). Bypass in an
emergency: `git push --no-verify`.

## The Swift tests

```sh
swift test                          # BierCore
./Tests/BierAgentTests/test.sh      # the agent
```
