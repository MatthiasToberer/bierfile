[Docs](../README.md) › Peers & security

# Signed releases

`bier upgrade` checks out a release tag and runs `install.sh` straight
afterwards. Without further checks, whoever can push a tag to the
program repository runs code on every Mac that upgrades.

`bier trust` narrows that, for whoever wants it:

```sh
bier trust https://bier.uber.space/bier/allowed_signers
```

bier fetches the file once, prints the fingerprints and remembers them in
`~/.config/bier/`. From then on `bier upgrade` installs a release only if
its tag is signed with one of those keys, and refuses one signed by
somebody else — or by nobody.

## Where the key comes from

The key is published on a host that is **not** the one serving the code.
Taking over the GitHub repository therefore does not hand anyone the
key — and the takeover would have had to happen before you ever fetched
it.

Fetching alone proves nothing. **Compare the fingerprint** bier prints
with one you obtained some other way — not from this repository, which is
exactly what the key is meant to protect against.

## Commands

| Command | Effect |
| --- | --- |
| `bier trust` | show the pinned keys and where they came from |
| `bier trust <url>` | fetch and pin a key file |
| `bier trust --forget` | stop verifying |

`bier peer trust` is an alias for the same command.

## Default

Nothing is pinned by default, and then nothing is verified — `bier
upgrade` says so each time. An earlier version insisted on a key and
stranded every installation that had never fetched one; verification is
therefore opt-in.

Signatures are SSH signatures (`git tag -s` with `gpg.format=ssh`), so
verifying needs no keyring — only the one-line `allowed_signers` file.
How releases are signed: [Versions and releases](../contributing/releasing.md).
