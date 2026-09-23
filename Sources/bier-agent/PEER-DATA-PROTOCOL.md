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
outside these paths, including `.git`, configuration, SSH keys and source
code, is transferable.

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

## Merge

After a complete snapshot arrives, Bier performs its normal local merge for
`Brewfiles/`. `Safe/` remains encrypted and is copied as an opaque payload.
The peer transport does not run Git commands or contact a Git server.
