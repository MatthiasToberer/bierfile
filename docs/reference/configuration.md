[Docs](../README.md) › Reference

# Configuration and paths

## The config file

`~/.barrel/config`, written by `install.sh`:

```
root = /Users/yourname/.barrel/bier  # the program
data = /Users/yourname/.barrel/data  # your lists
host = mini                          # what this Mac is called
inventory = automatic                # or manual
```

| Key | Meaning | Default |
| --- | --- | --- |
| `root` | the program repository | where `bier` itself lives |
| `data` | the private data repository | set by `install.sh`, `~/.barrel/data` |
| `host` | this Mac's name in `Brewfiles/` | `hostname -s` |
| `inventory` | `automatic` or `manual` — see below | `automatic` |
| `vault` | the folder with the plain vault copies | `~/.barrel/vault` |
| `vault_backup` | keep a copy before overwriting a vault file with another Mac's version | `yes` |
| `vault_max_file` | largest file the vault takes in, e.g. `500K`, `10M` | `10M` |
| `vault_exclude` | more file names a tracked folder leaves out, e.g. `*.hbqueue Recent*` | — |

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
| `BIER_BARREL` | the barrel itself, default `~/.barrel` |

## Where things live

Everything bier keeps lives in `~/.barrel`:

| Path | What |
| --- | --- |
| `~/.barrel/bier/` | the program (a signed release, or your working copy) |
| `~/.barrel/bin/bier` | the command |
| `~/.barrel/BierMenu.app` | the menu bar app |
| `~/.barrel/config` | the config |
| `~/.barrel/peers` | the addresses of paired Macs |
| `~/.barrel/allowed_signers` | the pinned release key, and where it came from (`.url`) |
| `~/.barrel/data/Brewfiles/` | `main` and one list per Mac |
| `~/.barrel/data/Safe/` | the encrypted vault, plus `README-recovery.txt` |
| `~/.barrel/vault/` | plain copies of the vault files, outside every repository |
| `~/.barrel/state/` | what this Mac and the safe last agreed on, what each peer had, backups |
| `~/.barrel/agent/` | the agent binary, this Mac's peer identity, the public keys of paired Macs (`peer_signers`) and the agent's state |

Outside it, only:

| Path | What |
| --- | --- |
| `~/Library/LaunchAgents/com.bier.agent.plist` | starts the agent; removes itself if `~/.barrel` is gone |
| a `PATH` line in `~/.zshrc` | marked `# added by bier` |
| keychain item `bier-vault` | this Mac's copy of the vault passphrase |

The data repository is deliberately separate from the program. The lists
reveal which software runs on your Macs, so they never go into the public
repository — and bier refuses to fall back to it if `data` is missing.
