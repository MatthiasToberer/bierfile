[Docs](../../README.md) › [Commands](README.md)

# bier view

```
bier view overview --json
bier view groups --json
bier view all --json
bier view group <group> --json
bier view mac <mac> --json
bier view package <name-or-entry> --json
```

One page of Bierkasten, worked out and ready to show. bier counts,
compares and words the findings; the app only shows them. The same
types are in `Sources/bier-core/swift/FleetView.swift`, and Bierkasten
decodes them from there.

A page is built from what this Mac knows (`bier report`) and what the
other Macs said when they were last asked (`bier fleet`, which keeps it
per Mac in `~/.barrel/state/fleet`). `bier view` itself asks no other
Mac, so it is quick; run `bier fleet` first for fresh news.

## Every page

| Field | |
| --- | --- |
| `page` | the page asked for |
| `generated` | when, in seconds since 1970 |
| `this` | the Mac it runs on |
| `macs` | every Mac, see below |
| `groups` | every group: `name`, `macs`, the rules `apply` (automatic \| ask) and `inventory` (automatic \| manual), and `software`, how many packages it gives |

A **Mac** has one name, `id` — its `hostname -s`. The rest:

| Field | |
| --- | --- |
| `address` | how this Mac reaches it; for this Mac, how the others reach it |
| `group` | its group; missing while it is new |
| `reach` | `this`, `online`, `offline`, `reachable` (answers, but bier there is too old to say how it is) or `unpaired` |
| `checked`, `heard` | when it was last asked, and when it last said how it is |
| `version`, `macos`, `model`, `disk` | as it said; `diskFree` and `diskSize` are the parts of `disk` |
| `trusts` | the Macs it trusts; empty when its bier is too old to say |
| `waiting` | introduced, waiting to be accepted here |
| `pending` | the Macs waiting to be accepted on it |
| `missing`, `extra`, `notAssigned` | how many packages stand so there |
| `inSync` | nothing missing, nothing extra, nothing arrived; missing when it has not said |

## Per page

| Page | Adds |
| --- | --- |
| `overview` | `counts` (`macs` — the paired ones —, `inSync`, `missing`, `extra`, `offline`), `needsYou`, `links`, `activity` |
| `groups` | `new`: the Macs in no group |
| `all` | `software` on every Mac, `files`, `appSettings` |
| `group` | `group`; `software`, `files` and `appSettings` for its Macs |
| `mac` | `mac`; its `software`, its `needsYou`, its `activity` |
| `package` | `package`, and its `appSettings` |

A **package** is `entry` (`cask "firefox"`), `name`, `kind`, `givenTo`
(`["all"]`, the groups, or empty), `states` per Mac, and how many Macs
are in each state. A state is `installed` (should be there, is),
`missing` (should be there, is not), `extra` (is there, was taken off
elsewhere), `notAssigned` (is there, nothing gives it) or `unknown` (the
Mac has not said). A Mac the package does not concern is left out.

A **finding** in `needsYou` has a `kind` — `pending` (waits here), `waits`
(waits on another Mac, accepted with `--on`), `new`, `missing`,
`extra`, `conflict`, `arrived`, `offline`, `old`, `release` — the Macs it
is about, an English `text` and `detail`, `subject` (who introduced a
waiting Mac, the file of a conflict, the files that arrived, the new
version), `count` (packages missing or extra), and `actions`: each a
button `title` and the bier command `args` it runs. An app in another
language words it from `kind`, `macs`, `subject` and `count`.

A **link** joins two Macs: `paired` when each trusts the other, `waiting`
when one waits to be accepted or only one side trusts the other. Two
Macs with no link do not know each other.

`activity` is the latest changes, newest first: `time`, `subject` and
the `commit` that [`bier undo`](undo.md) takes.
