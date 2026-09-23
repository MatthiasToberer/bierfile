# Peer Data Protocol

This is the contract for server-free Bier data replication. It is implemented
by `bier-agent`; it is not an SSH shell protocol and it never accepts a
command to execute.

## Scope

Only these repository paths may cross the connection:

```text
.gitattributes
Brewfiles/
Safe/
```

`Safe/` is already encrypted by Bier before it reaches the protocol. Nothing
outside these paths, including configuration, SSH keys and source code, is
transferable. Git history travels separately as a verified Git bundle; the
protocol never exposes the `.git` directory itself.

## Authentication

Every non-public request is signed with the Ed25519 peer identity registered
by `bier peer install`. The signed canonical bytes are:

```text
METHOD
PATH
PEER
TIME
NONCE
SHA256(BODY)
```

The agent permits a five-minute clock window and stores every accepted nonce.
A repeated request is rejected. `GET /v1/peer/hello` is the first completed
use of this rule.

## Snapshot lifecycle

A data sync uses a fresh snapshot identifier and four constrained operations:

1. `manifest` returns the allowed paths, sizes and SHA-256 digests.
2. `begin` creates an empty staging directory for that one snapshot.
3. `put` writes one validated path into staging, in bounded chunks.
4. `commit` checks the complete manifest, then atomically replaces the
   receiving data snapshot.

The agent rejects path traversal, symlinks, duplicate chunks, oversized
requests, stale snapshots and files not named by the manifest. It never
partially changes the live data directory: an interrupted transfer is only
staging data and is discarded.

## Repository history

Repository bundles use separate `export`, `export/read`, `import/begin`,
`import/put` and `import/commit` operations. Bundle bytes have a declared size
and SHA-256 digest and are transferred in bounded chunks. A fresh peer adopts
history only when the checked-out bundle data exactly matches its snapshot.
An existing peer accepts only history containing its current commit.

The initiating Mac fetches the peer history, rebases its local commits and
then sends the resulting common history back. A conflict aborts and restores
the previous working state. The peer transport never accepts arbitrary Git or
shell commands and never contacts a central Git server.
