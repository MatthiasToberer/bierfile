[Docs](../README.md) › Contributing

# Architecture

How bier is built. For how bier, the agent and Bierkasten work together
at runtime, start with the [system overview](system-overview.md). For
using bier, see the [documentation](../README.md).

## Layout

    Sources/bier-core/       the command and shared Swift code
    Sources/bier-agent/      the peer agent
    Sources/bier-peer/       the native peer client
    Sources/bier-trayapp/    BierMenu, the menu bar app
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

## The Swift parts

`Package.swift` builds a shared library and three executables:

| Target | Role |
| --- | --- |
| `BierCore` (`Sources/bier-core/swift/`) | peer client, pairing, snapshots, git bundles, manifests |
| `bier-agent` | the local agent; listens on TCP 53991, answers signed peer requests |
| `bier-peer` | the native client `bier` calls for pairing and exchange |
| BierMenu (`Sources/bier-trayapp/`) | the menu bar app, built by its own `build.sh` |

The command itself, `Sources/bier-core/bier`, is a bash script. It hands
pairing and peer exchange to `bier-peer`, and BierMenu only calls
`bier state` — the inventory logic lives in one place.

The agent's wire contract is
[PEER-DATA-PROTOCOL.md](../../Sources/bier-agent/PEER-DATA-PROTOCOL.md).

## Looking at the icon

`Sources/bier-trayapp/preview-icon.swift` writes both resting states, six frames of the
animation, a strip with all of them side by side, and `pixel.png`:

```sh
swiftc -o /tmp/preview Sources/bier-trayapp/Glass.swift Sources/bier-trayapp/preview-icon.swift -framework AppKit
/tmp/preview /tmp/glass
open /tmp/glass/pixel.png
```

`pixel.png` shows the states at true menu bar size (30×34 pixels), scaled
up without smoothing. That is the view an icon has to be designed
against — rendered large, every draft looks good.
