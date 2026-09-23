# Security policy

bier installs and removes software and moves encrypted files between
Macs, so security reports are taken seriously.

## Reporting a vulnerability

Please report privately through GitHub:
**[Report a vulnerability](https://github.com/MatthiasToberer/bierfile/security/advisories/new)**.
Do not open a public issue for security problems.

Include the bier version (`bier version`), what you did, and what
happened. You will get an answer as soon as possible; this is a
one-person hobby project, so please allow a few days.

## Supported versions

Only the latest release receives fixes. Upgrade with `bier upgrade`.

## Scope

What bier protects, what a paired Mac can do, and what is out of scope
is written down in the [threat model](docs/security/threat-model.md).
Known limits documented there — for example that peer traffic is not
encrypted — are not new findings, but ideas for fixing them are welcome.

## Verifying releases

Releases are signed. How to pin the signing key and have `bier upgrade`
verify every release: [Signed releases](docs/security/signed-releases.md).
