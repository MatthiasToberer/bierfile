[Docs](../README.md) › Concepts

# When two Macs change at once

Lists of packages have no order, and when two Macs change them at the
same time, almost always *both* sides are right. bier therefore sets
`merge=union` for the lists: git merges simultaneous changes itself
instead of leaving a conflict behind.

Should a conflict survive anyway, `bier sync` resolves it by the same
rule — keep both sides, carry on. Duplicate lines do not bother Homebrew
and disappear with the next `bier sync`.

If it really cannot be done, bier aborts and restores the previous state
rather than leaving something half finished. Peer transfers work the same
way: an interrupted exchange is discarded, and the live data is only ever
replaced as a whole. See the
[peer data protocol](../../Sources/bier-agent/PEER-DATA-PROTOCOL.md).

## Why the lists are not encrypted

The vault is encrypted, the lists are not — on purpose. A union merge of
two encrypted files glues two ciphertexts together; git reports success
and the file is silently ruined. And telling a removal from a new package
needs to search the history for the entry, which is impossible in
ciphertext. The lists stay readable and stay private by never leaving
your paired Macs.
