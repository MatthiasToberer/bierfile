[Docs](../README.md) › Contributing

# Versions and releases

## Version

    bier version

    bier 0.11.0
      Commit  a1333cd of 2026-09-20
      Code    /Users/yourname/bierfile
      Data    /Users/yourname/bierdata
      Device  mini
      App     0.11.0 (/Users/yourname/.barrel/BierMenu.app)

`BIER_VERSION` appears in exactly one place, in `Sources/bier-core/bier`.
`Sources/bier-trayapp/build.sh` reads it from there into the app bundle, `bier state`
reports it. That is how BierMenu notices that it is older than the script
and offers an upgrade in the menu. **Bump it on behavioural changes** — an
old app quietly running on after an install has happened before.

## Releases

A release is a tag, and the tag is what `bier upgrade` follows:

```sh
git tag -a v0.13.0 -m "what changed"
git push origin v0.13.0
gh release create v0.13.0 --verify-tag --latest --notes "what changed"
```

The tag has to match `BIER_VERSION`, because that is the number the
installed copy compares itself against. GitHub builds the download for
every tag on its own — `archive/refs/tags/v0.13.0.tar.gz` exists without
anyone uploading anything.

The release page is **not** optional: `bier upgrade` follows the tags,
but `bier peer install` and `peer upgrade` ask GitHub for
`releases/latest`, which only knows tags with a release page. A tag
without one leaves remote agents on the previous release.

`check_code` fetches the tags, takes the highest one (`--sort=-v:refname`)
and holds it against `BIER_VERSION`. The comparison runs through
`sort -V`, because a string comparison would call 0.9.1 newer than
0.13.0. If the release is higher, `bier upgrade` checks that tag out
detached — it lands on the release, not on whatever the branch has
drifted to since.

**A server without tags keeps working as before**: `check_code` then
falls back to comparing the branch with its counterpart. That is how the
private server is used during development, where every push is meant to
arrive right away, without cutting a release for it.

`bier state --fetch` fetches the tags as well and prints `NEWCODE <version>`
when one is waiting. BierMenu shows it and offers the upgrade — otherwise
nobody would ever learn that a release is out.

## Signing

Why releases are signed, and how users verify them: [Signed releases](../security/signed-releases.md).

Releasing then needs the key in the agent and git told to use it:

```sh
ssh-add ~/.ssh/bier_signing
git -c gpg.format=ssh -c user.signingkey=~/.ssh/bier_signing.pub \
    tag -s v0.16.0 -m "…"
```

`v0.14.0` carries a GPG signature from a first attempt. Nothing reads
it.
