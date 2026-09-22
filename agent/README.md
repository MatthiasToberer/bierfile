# Bier Agent

The Swift `bier-agent` is part of Bierfile. `bier peer install` fetches a
signed Bierfile release on the target Mac, verifies its tag with the ordinary
Bier release key, then builds this source with the Apple Command Line Tools.

The agent has a deliberately narrow HTTP interface. It announces itself on
`_bier-agent._tcp` and currently provides a health endpoint plus signed probe
recipes. The future peer data protocol extends this interface; it must never
become a remote shell service.

Build and test it on macOS:

```sh
./agent/test.sh
```
