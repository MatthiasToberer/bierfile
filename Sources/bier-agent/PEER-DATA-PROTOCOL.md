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
by pairing or `bier peer install`. The signed canonical bytes are:

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

## Pairing

`bier peer offer` creates a random 128-bit one-time code on the receiving Mac.
It expires after ten minutes and locks after five wrong attempts. The other
Mac proves knowledge of that code with HMAC-SHA256; the code itself never
crosses the network. The receiver authenticates its response with the same
code, so neither side can be replaced by a machine between them.

On success both Ed25519 public keys and both `.local` addresses are remembered.
The offer is deleted immediately. If the receiving data repository is still
empty or contains only the installer scaffolding, the initiating Mac then
copies its snapshot and complete Git history. Existing user data is never
overwritten by this first-use step. Pairing ends with a sync, so a peer that
already had data of its own shares one history with this Mac afterwards.

## Signing off

`POST /v1/peer/leave`, signed like every peer request, takes the sender
out: the agent removes the sender's line from `peer_signers` and every
address in its peers file that belongs to the sender — the one it gave
when pairing (kept in the state directory as `paired-addresses`), its
name and `<name>.local`, and, for pairings from before those were kept,
any that resolves to the address the request came from. Only the signer
itself can be removed this way; afterwards every request from it is
refused. `bier knockout` sends it to every paired Mac.

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
A peer whose history is only the installer scaffolding (`.gitattributes` and
an empty `Brewfiles/main`) takes the incoming history whole, provided its
files are unchanged or exactly match that history. Any other peer accepts
only history containing its current commit and refuses while it has
uncommitted changes. Exporting history does not require a clean working tree.

The initiating Mac fetches the peer history, rebases its local commits and
then sends the resulting common history back. When the two histories share
no commit and this Mac's root commit is only scaffolding, that commit is
dropped and the rest is replayed onto the peer history; a peer holding only
scaffolding is left to take this Mac's history. Other unrelated histories
are refused. A conflict aborts and restores the previous working state.
Refusals name their reason (for example uncommitted changes); Git's own
output stays on the refusing Mac. The peer transport never accepts arbitrary Git or
shell commands and never contacts a central Git server.
