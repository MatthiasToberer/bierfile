[Docs](../README.md) › Reference

# Configuration and paths

## The config file

`~/.config/bier/config`, written by `install.sh`:

```
root = /Users/yourname/bierfile      # the program
data = /Users/yourname/bierdata      # your lists
host = mini                          # what this Mac is called
inventory = automatic                # or manual
```

| Key | Meaning | Default |
| --- | --- | --- |
| `root` | the program repository | where `bier` itself lives |
| `data` | the private data repository | set by `install.sh`, `~/bierdata` |
| `host` | this Mac's name in `Brewfiles/` | `hostname -s` |
| `inventory` | `automatic` or `manual` — see below | `automatic` |
| `vault` | the folder with the plain vault files | `~/.bierfilevault` |

`bier config` shows the values in effect.

### Inventory mode

- **automatic** (default, recommended) — `bier sync` records everything
  installed that is not in `main` yet into this Mac's own list. `main`
  stays the main inventory and changes only through `bier main` and
  `bier take`.
- **manual** — `bier sync` records nothing; `main` and the device lists
  stay exactly as you write them. Useful for a
  [trial run](../start/trial-run.md) or for curating by hand.

See [Automatic and manual](../concepts/lists.md#automatic-and-manual).

Switch with `bier config inventory manual|automatic`, or install with
`install.sh --manual-inventory`.

## Environment

These override the matching config values for one invocation:

| Variable | Overrides |
| --- | --- |
| `BIER_CONFIG` | the config file itself |
| `BIER_ROOT`, `BIER_DATA`, `BIER_HOST`, `BIER_VAULT`, `BIER_INVENTORY` | the config keys |
| `BIER_PEER_PORT` | the agent port, default `53991` |

## Where things live

| Path | What |
| --- | --- |
| `~/bierfile` | the program (public repository) |
| `~/bierdata/Brewfiles/` | `main` and one list per Mac |
| `~/bierdata/Safe/` | the encrypted vault, plus `README-recovery.txt` |
| `~/.bierfilevault/` | the plain vault files, outside every repository |
| `~/.config/bier/` | config and pinned release keys (`allowed_signers`) |
| `~/.local/bin/bier` | link to the command |
| `~/.local/share/bier/agent/` | the peer agent, its identity and known peers |
| `~/Library/LaunchAgents/com.bier.agent.plist` | starts the agent |
| `/Applications/BierMenu.app` | the menu bar app |
| keychain item `bier-vault` | this Mac's copy of the vault passphrase |

The data repository is deliberately separate from the program. The lists
reveal which software runs on your Macs, so they never go into the public
repository — and bier refuses to fall back to it if `data` is missing.
